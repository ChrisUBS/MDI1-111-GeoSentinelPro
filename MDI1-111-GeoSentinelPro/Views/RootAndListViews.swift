// RootAndListViews.swift
import SwiftUI
import MapKit

struct RootView: View {
    @EnvironmentObject var vm: GeoVM

    var body: some View {
        Group {
            if vm.needsWelcomeScreen {
                WelcomeView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            Task {
                await vm.bootstrap()
            }
        }
        .overlay(alignment: .top) {
            if let msg = vm.bannerMessage {
                BannerView(message: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { vm.bannerMessage = nil }
                        }
                    }
                    .padding(.top, 20)
            }
        }
        .animation(.easeInOut, value: vm.bannerMessage)
    }
}

struct RegionListView: View {
    @EnvironmentObject var vm: GeoVM
    @State private var editing: GeoRegion? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.regions) { r in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.name)
                                .font(.headline)

                            Text("\(r.latitude, specifier: "%.5f"), \(r.longitude, specifier: "%.5f") • \(Int(r.radius)) m")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let runtime = vm.presence[r.id] {
                                HStack {
                                    let p = runtime.presence
                                    
                                    Text(p.rawValue.capitalized)
                                        .font(.caption2)
                                        .foregroundColor(
                                            p == .inside ? .green :
                                            p == .outside ? .red : .gray
                                        )
                                    
                                    // Snoozed?
                                    if let until = runtime.snoozedUntil, until > Date() {
                                        Text("(Snoozed)")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }

                        Spacer()

                        Toggle(isOn: Binding(
                            get: { r.enabled },
                            set: { _ in vm.toggleEnabled(r.id) }
                        )) {
                            EmptyView()
                        }
                        .labelsHidden()

                        Button {
                            editing = r
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete { idxSet in
                    for idx in idxSet {
                        let region = vm.regions[idx]
                        vm.deleteRegion(region.id)
                    }
                }
            }
            .navigationTitle("GeoSentinel Pro")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = GeoRegion(
                            name: "New Fence",
                            latitude: 32.5149,
                            longitude: -117.0382,
                            radius: 200
                        )
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { region in
                RegionEditorSheet(region: region) { updated in
                    if vm.regions.contains(where: { $0.id == updated.id }) {
                        vm.updateRegion(updated)
                    } else {
                        vm.addRegion(updated)
                    }
                }
            }
        }
        .onAppear {
            vm.requestInitialStates()
        }
    }
}

struct RegionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var region: GeoRegion
    var onSave: (GeoRegion) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $region.name)
                Stepper("Radius: \(Int(region.radius)) m", value: $region.radius, in: 50...2000, step: 25)
                Toggle("Notify on Entry", isOn: $region.notifyOnEntry)
                Toggle("Notify on Exit", isOn: $region.notifyOnExit)
                HStack {
                    Text("Lat"); TextField("Lat", value: $region.latitude, format: .number).keyboardType(.decimalPad)
                    Text("Lon"); TextField("Lon", value: $region.longitude, format: .number).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Region")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(region); dismiss() } }
            }
        }
    }
}
