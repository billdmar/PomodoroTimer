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

class FirebaseManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    init() {
        checkAuthStatus()
    }
    
    // MARK: - Authentication
    
    func checkAuthStatus() {
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    func signInAnonymously() {
        isLoading = true
        errorMessage = nil
        
        auth.signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Anonymous sign-in error: \(error)")
                } else {
                    print("Anonymous sign-in successful")
                }
            }
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - User Stats
    
    func saveUserStats(focusMinutes: Int, totalMinutes: Int, streak: Int) {
        guard let userId = currentUser?.uid else {
            print("No authenticated user")
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
        
        db.collection("userStats").document(userId).setData(data, merge: true) { error in
            if let error = error {
                print("Error saving user stats: \(error)")
            } else {
                print("User stats saved successfully")
            }
        }
    }
    
    func loadUserStats(completion: @escaping (Int, Int, Int) -> Void) {
        guard let userId = currentUser?.uid else {
            print("No authenticated user")
            completion(0, 0, 0)
            return
        }
        
        db.collection("userStats").document(userId).getDocument { document, error in
            if let error = error {
                print("Error loading user stats: \(error)")
                completion(0, 0, 0)
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data() else {
                print("No user stats found")
                completion(0, 0, 0)
                return
            }
            
            let todayMinutes = data["todayFocusMinutes"] as? Int ?? 0
            let totalMinutes = data["totalFocusMinutes"] as? Int ?? 0
            let streak = data["currentStreak"] as? Int ?? 0
            
            DispatchQueue.main.async {
                completion(todayMinutes, totalMinutes, streak)
            }
        }
    }
    
    // MARK: - Leaderboard
    
    func getLeaderboard(limit: Int = 10, completion: @escaping ([LeaderboardEntry]) -> Void) {
        db.collection("userStats")
            .order(by: "totalFocusMinutes", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching leaderboard: \(error)")
                    completion([])
                    return
                }
                
                let entries = snapshot?.documents.compactMap { document -> LeaderboardEntry? in
                    let data = document.data()
                    return LeaderboardEntry(
                        userId: document.documentID,
                        totalMinutes: data["totalFocusMinutes"] as? Int ?? 0,
                        streak: data["currentStreak"] as? Int ?? 0,
                        lastActive: (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
                
                DispatchQueue.main.async {
                    completion(entries)
                }
            }
    }
    
    // MARK: - Focus Sessions
    
    func logFocusSession(duration: Int, completedAt: Date = Date()) {
        guard let userId = currentUser?.uid else {
            print("No authenticated user")
            return
        }
        
        let sessionData: [String: Any] = [
            "userId": userId,
            "duration": duration,
            "completedAt": completedAt,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("focusSessions").addDocument(data: sessionData) { error in
            if let error = error {
                print("Error logging focus session: \(error)")
            } else {
                print("Focus session logged successfully")
            }
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
