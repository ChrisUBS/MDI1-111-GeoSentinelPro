//
//  WelcomeView.swift
//  GeoSentinelPro
//
//  Created by Christian Bonilla on 21/11/25.
//

import SwiftUI
import UserNotifications
import CoreLocation

struct WelcomeView: View {
    @EnvironmentObject var vm: GeoVM
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 26) {
            
            Text("Welcome to GeoSentinel Pro")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            Text("To monitor regions reliably, please enable the following permissions.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            // ---- LOCATION PERMISSIONS CARD ----
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location Access")
                            .font(.headline)
                        Text(vm.authStatusDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                Button {
                    vm.requestAuthIfNeeded()
                } label: {
                    Text("Allow “While Using the App”")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.authStatus == .authorizedWhenInUse || vm.authStatus == .authorizedAlways)
                
                Button {
                    vm.upgradeToAlways()
                } label: {
                    Text("Allow “Always”")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.authStatus == .authorizedAlways)
            }
            .padding()
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            
            // ---- NOTIFICATIONS CARD ----
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .font(.headline)
                        Text(vm.notificationsAuthorized ? "Allowed" : "Not allowed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                Button {
                    vm.requestNotificationAuth()
                } label: {
                    Text("Enable Notifications")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.notificationsAuthorized)
                
            }
            .padding()
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            
            Spacer()
            
            // ---- CONTINUE BUTTON ----
//            Button {
//                dismiss()
//            } label: {
//                Text("Continue")
//                    .font(.headline)
//                    .frame(maxWidth: .infinity)
//            }
//            .buttonStyle(.borderedProminent)
//            .disabled(vm.needsWelcomeScreen)
//            .padding(.horizontal)
//            .padding(.bottom, 40)
        }
    }
    
    // ---- Helpers ----
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                vm.notificationsAuthorized = granted
            }
        }
    }
}
