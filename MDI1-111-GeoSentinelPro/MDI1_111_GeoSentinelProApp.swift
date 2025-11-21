//
//  MDI1_111_GeoSentinelProApp.swift
//  MDI1-111-GeoSentinelPro
//
//  Created by Christian Bonilla on 20/11/25.
//

import SwiftUI

@main
struct MDI1_111_GeoSentinelProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vm = GeoVM()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .onAppear {
                    Task { await vm.bootstrap() }
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { try? await NotificationService.shared.register() }
        return true
    }

    // Foreground notification presentation
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationService.shared.handleAction(response: response)
        completionHandler()
    }
}
