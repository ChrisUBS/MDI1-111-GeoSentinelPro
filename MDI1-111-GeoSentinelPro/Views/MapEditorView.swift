// MapEditorView.swift
import SwiftUI
import MapKit

struct MapEditorView: View {
    @EnvironmentObject var vm: GeoVM
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        VStack {

            // MARK: - Map with MapReader
            MapReader { proxy in
                Map(position: $mapPosition) {

                    // Render active regions
                    ForEach(vm.regions.filter { $0.enabled }) { r in
                        let coord = CLLocationCoordinate2D(
                            latitude: r.latitude,
                            longitude: r.longitude
                        )
                        
                        let isInside = vm.presence[r.id]?.presence == .inside

                        Annotation(r.name, coordinate: coord) {
                            Circle()
                                .fill(
                                    vm.presence[r.id]?.presence == .inside
                                        ? .green.opacity(0.3)
                                        : .blue.opacity(0.2)
                                )
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            vm.presence[r.id]?.presence == .inside ? .green : .blue,
                                            lineWidth: 2
                                        )
                                )
                        }

                        MapCircle(center: coord, radius: r.radius)
                            .stroke(isInside ? .green : .blue, lineWidth: 2)
                            .foregroundStyle(isInside ? .green.opacity(0.15) : .blue.opacity(0.10))
                    }

                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapPitchToggle()
                    MapCompass()
                    MapScaleView()
                }

                // Tap to create region
                .onTapGesture { screenPoint in
                    if let coord = proxy.convert(screenPoint, from: .local) {
                        let new = GeoRegion(
                            name: "Pin",
                            latitude: coord.latitude,
                            longitude: coord.longitude,
                            radius: 200
                        )
                        vm.addRegion(new)
                    }
                }
            }

            // MARK: - Auth / Precision Overlay
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auth: \(vm.authStatusDescription)")
                    Text("Precise: \(vm.preciseEnabled.description)")
                    if let focus = vm.regions.first(where: { $0.enabled }) {
                        if let pres = vm.presence[focus.id]?.presence {
                            Text("State: \(pres.rawValue.capitalized)")
                        }
                    }
                }
                .font(.caption)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()
            }

            // MARK: - Bottom Buttons
            HStack {
                Button {
                    vm.toggleBatteryMode()
                } label: {
                    Label(
                        vm.settings.batteryMode.title,
                        systemImage: vm.settings.batteryMode == .saver ? "leaf" : "target"
                    )
                }

                Spacer()

                Button("Upgrade to Always") {
                    vm.upgradeToAlways()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
