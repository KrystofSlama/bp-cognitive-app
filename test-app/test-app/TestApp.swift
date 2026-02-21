//
//  KackaApp.swift
//  Kacka
//
//  Created by Kryštof Sláma on 20.11.2025.
//

import SwiftData
import SwiftUI

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ParticipantResult.self)
    }
}
