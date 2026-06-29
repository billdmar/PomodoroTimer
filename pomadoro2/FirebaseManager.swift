//
//  FirebaseManager.swift
//  pomadoro2
//
//  Firebase integration for Pomodoro Timer
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Network

/// The backend operations the app needs, abstracted so consumers (and tests)
/// can depend on a protocol rather than the concrete Firebase client.
protocol StatsBackend: AnyObject {
    func saveUserStats(focusMinutes: Int, totalMinutes: Int, streak: Int) async
    func loadUserStats() async -> StatsState?
    func leaderboard(limit: Int) async -> [LeaderboardEntry]
    func logFocusSession(duration: Int, completedAt: Date) async
}

class FirebaseManager: ObservableObject, StatsBackend {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOnline = true

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        setupNetworkMonitoring()
        checkAuthStatus()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    Log.debug("Network connection restored")
                } else {
                    Log.debug("Network connection lost")
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - Authentication

    func checkAuthStatus() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                if user != nil {
                    Log.debug("User authenticated: \(user?.uid ?? "unknown")")
                }
            }
        }
    }

    /// Signs in anonymously.
    /// - Parameter userInitiated: When `true` (a tap on "Join"), failures are
    ///   surfaced to `errorMessage`. The silent auto-sign-in at launch passes
    ///   `false` so a benign failure never dumps an error into the UI.
    func signInAnonymously(userInitiated: Bool = false) {
        guard isOnline else {
            if userInitiated {
                errorMessage = "No internet connection. Please check your network and try again."
            }
            return
        }

        isLoading = true
        errorMessage = nil

        auth.signInAnonymously { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    if userInitiated {
                        self?.errorMessage = self?.friendlyErrorMessage(for: error)
                    }
                    Log.debug("Anonymous sign-in error: \(error)")
                } else {
                    Log.debug("Anonymous sign-in successful")
                    self?.errorMessage = nil
                }
            }
        }
    }

    func signOut() {
        do {
            try auth.signOut()
            errorMessage = nil
        } catch {
            errorMessage = friendlyErrorMessage(for: error)
        }
    }

    // MARK: - User Stats

    func saveUserStats(focusMinutes: Int, totalMinutes: Int, streak: Int) async {
        guard let userId = currentUser?.uid else {
            Log.debug("No authenticated user")
            return
        }
        guard isOnline else {
            Log.debug("Offline - stats will sync when connection is restored")
            return
        }

        let data: [String: Any] = [
            "userId": userId,
            "todayFocusMinutes": focusMinutes,
            "totalFocusMinutes": totalMinutes,
            "currentStreak": streak,
            "lastUpdated": FieldValue.serverTimestamp(),
            "lastCompletionDate": Date()
        ]

        do {
            try await db.collection("userStats").document(userId).setData(data, merge: true)
            Log.debug("User stats saved successfully")
        } catch {
            Log.debug("Error saving user stats: \(error)")
        }
    }

    /// Loads this user's stats, or nil when unauthenticated / offline / absent.
    func loadUserStats() async -> StatsState? {
        guard let userId = currentUser?.uid else {
            Log.debug("No authenticated user")
            return nil
        }
        guard isOnline else {
            Log.debug("Offline - using local stats")
            return nil
        }

        do {
            let document = try await db.collection("userStats").document(userId).getDocument()
            guard document.exists, let data = document.data() else {
                Log.debug("No user stats found")
                return nil
            }
            return StatsState(
                todayFocusMinutes: data["todayFocusMinutes"] as? Int ?? 0,
                totalFocusMinutes: data["totalFocusMinutes"] as? Int ?? 0,
                currentStreak: data["currentStreak"] as? Int ?? 0,
                lastCompletionDate: (data["lastCompletionDate"] as? Timestamp)?.dateValue()
            )
        } catch {
            Log.debug("Error loading user stats: \(error)")
            return nil
        }
    }

    // MARK: - Leaderboard

    func leaderboard(limit: Int = 10) async -> [LeaderboardEntry] {
        guard isOnline else {
            Log.debug("Offline - cannot load leaderboard")
            return []
        }

        do {
            let snapshot = try await db.collection("userStats")
                .order(by: "totalFocusMinutes", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.map { document in
                let data = document.data()
                return LeaderboardEntry(
                    userId: document.documentID,
                    totalMinutes: data["totalFocusMinutes"] as? Int ?? 0,
                    streak: data["currentStreak"] as? Int ?? 0,
                    lastActive: (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        } catch {
            Log.debug("Error fetching leaderboard: \(error)")
            return []
        }
    }

    // MARK: - Focus Sessions

    func logFocusSession(duration: Int, completedAt: Date = Date()) async {
        guard let userId = currentUser?.uid else {
            Log.debug("No authenticated user")
            return
        }
        guard isOnline else {
            Log.debug("Offline - session will be logged when connection is restored")
            return
        }

        let sessionData: [String: Any] = [
            "userId": userId,
            "duration": duration,
            "completedAt": completedAt,
            "timestamp": FieldValue.serverTimestamp()
        ]

        do {
            _ = try await db.collection("focusSessions").addDocument(data: sessionData)
            Log.debug("Focus session logged successfully")
        } catch {
            Log.debug("Error logging focus session: \(error)")
        }
    }

    // MARK: - Error Handling

    private func friendlyErrorMessage(for error: Error) -> String {
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .networkError:
                return "Network connection problem. Please check your internet and try again."
            case .tooManyRequests:
                return "Too many attempts. Please wait a moment and try again."
            case .userDisabled:
                return "This account has been disabled."
            default:
                return "Authentication failed. Please try again."
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut:
                return "Network connection problem. Please check your internet and try again."
            default:
                break
            }
        }

        return error.localizedDescription
    }

    deinit {
        networkMonitor.cancel()
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
}

// MARK: - Data Models

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let userId: String
    let totalMinutes: Int
    let streak: Int
    let lastActive: Date

    var displayName: String {
        // For anonymous users, show a fun name
        return "Pomodoro Master \(userId.prefix(6))"
    }

    var formattedMinutes: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
