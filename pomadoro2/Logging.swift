//
//  Logging.swift
//  pomadoro2
//
//  Lightweight debug logging that compiles out of Release builds.
//

import Foundation

/// A tiny logging shim. In DEBUG builds `Log.debug` forwards to `print`;
/// in Release builds the calls compile down to nothing, so diagnostic
/// output never reaches a shipped app's console.
enum Log {
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }
}
