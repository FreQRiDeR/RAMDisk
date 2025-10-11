//
//  RAM_Disk_App.swift
//  RAM_Disk!
//
//  Created by terraMODA on 10/10/25.
//

import SwiftUI

@main
struct RAM_Disk_App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
