//
//  PomodoroWidgetBundle.swift
//  PomodoroWidget
//
//  Entry point for the widget extension. This @main lives ONLY in the widget
//  target — never add this file to the app target (two @main would break the
//  app build).
//

import WidgetKit
import SwiftUI

@main
struct PomodoroWidgetBundle: WidgetBundle {
    var body: some Widget {
        PomodoroWidget()
        PomodoroLiveActivity()
        if #available(iOS 18.0, *) {
            PomodoroControl()
        }
    }
}
