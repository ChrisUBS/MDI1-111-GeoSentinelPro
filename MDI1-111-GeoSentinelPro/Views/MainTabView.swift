//
//  MainTabView.swift
//  GeoSentinelPro
//
//  Created by Christian Bonilla on 21/11/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var vm: GeoVM

    var body: some View {
        TabView {
            RegionListView()
                .tabItem {
                    Label("Regions", systemImage: "mappin.and.ellipse")
                }

            MapEditorView()
                .tabItem {
                    Label("Map", systemImage: "map.circle")
                }

            DebugConsoleView()
                .tabItem {
                    Label("Debug", systemImage: "terminal")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
