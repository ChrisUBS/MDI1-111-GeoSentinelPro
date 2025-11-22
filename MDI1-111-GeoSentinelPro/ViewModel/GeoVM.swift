// GeoVM.swift
import Foundation
import CoreLocation
import Combine
import UserNotifications
import UIKit

@MainActor
final class GeoVM: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var regions: [GeoRegion] = []
    @Published var settings = GeoSettings()
    @Published var logs: [LogEntry] = []
    @Published var presence: [UUID: RegionRuntimeState] = [:]
    @Published var showPermissionAlert = false
    @Published var permissionAlertMessage = ""
    @Published var bannerMessage: String? = nil
    @Published var lastLocation: CLLocation?

    // Permission state
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var authStatusDescription: String = "Unknown"
    @Published var preciseEnabled: Bool = true
    @Published var notificationsAuthorized: Bool = false

    var needsWelcomeScreen: Bool {
        (authStatus != .authorizedAlways && authStatus != .authorizedWhenInUse) ||
        !notificationsAuthorized
    }

    // MARK: - Internals
    private let location = LocationService.shared
    private var timers: [UUID: Task<Void, Never>] = [:]
    private var exitTimers: [UUID: Task<Void, Never>] = [:]
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Init
    override init() {
        super.init()
        location.delegate = self

        // Snooze
        NotificationCenter.default.addObserver(forName: .gsSnooze15, object: nil, queue: .main) { [weak self] n in
            guard let idStr = n.object as? String,
                  let uuid = UUID(uuidString: idStr) else { return }
            Task { @MainActor [self] in
                self?.snooze(regionID: uuid, minutes: 15)
            }
        }

        // Done button
        NotificationCenter.default.addObserver(forName: .gsDone, object: nil, queue: .main) { [weak self] n in
            guard let idStr = n.object as? String,
                  let uuid = UUID(uuidString: idStr) else { return }
            Task { @MainActor [self] in
                self?.log("DONE tapped for region \(uuid).")
            }
        }
    }
    
    func snooze(regionID: UUID, minutes: Int) {
        var s = presence[regionID] ?? RegionRuntimeState()
        s.snoozedUntil = Date().addingTimeInterval(Double(minutes) * 60)
        presence[regionID] = s
        save()
        log("Region \(regionID) snoozed for \(minutes) minutes.")
    }

    // MARK: - Permissions
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.authStatus = status
            self.authStatusDescription = GeoVM.describe(status)

            log("Auth changed: \(authStatusDescription). Precise=\(preciseEnabled)")
        }
    }

    func requestNotificationAuth() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                if settings.authorizationStatus == .denied {
                    self.openAppSettings()
                    return
                }

                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    Task { @MainActor in
                        self.notificationsAuthorized = granted
                        self.updateNotificationStatus()
                    }
                }
            }
        }
    }

    private static func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedWhenInUse: return "When In Use"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }

    func updateNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsAuthorized =
                    settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional
            }
        }
    }
    
    func isQuietHours(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)

        if settings.quietStart < settings.quietEnd {
            // e.g., 22 -> 07 (normal range)
            return hour >= settings.quietStart && hour < settings.quietEnd
        } else {
            // range crosses midnight, e.g. 22 -> 7
            return hour >= settings.quietStart || hour < settings.quietEnd
        }
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // Request flow
    func requestAuthIfNeeded() {
        if authStatus == .denied {
            openAppSettings()
            return
        }

        location.requestWhenInUse()
    }

    func upgradeToAlways() {
        if authStatus == .denied {
            openAppSettings()
            return
        }

        location.requestAlways()
    }

    // MARK: - Bootstrap
    func bootstrap() async {
        regions = Persistence.load([GeoRegion].self, key: StoreKeys.regions, default: [])
        settings = Persistence.load(GeoSettings.self, key: StoreKeys.settings, default: GeoSettings())
        presence = Persistence.load([UUID: RegionRuntimeState].self, key: StoreKeys.runtime, default: [:])

        updateNotificationStatus()
        await updateMonitoringMode()
        requestInitialStates()

        log("Bootstrap complete. Regions: \(regions.count). Mode: \(settings.batteryMode.title).")

//        requestAuthIfNeeded()
    }
    
    // MARK: - Timers
    func requestInitialStates() {
        for region in regions where region.enabled {
            let clRegion = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude),
                radius: clampRadius(region.radius),
                identifier: region.id.uuidString
            )
            location.requestState(for: clRegion)
        }
    }

    func cancelTimers(for id: UUID) {
        timers[id]?.cancel()
        timers[id] = nil

        exitTimers[id]?.cancel()
        exitTimers[id] = nil
    }
    
    func startDwellTimer(for id: UUID) {
        cancelTimers(for: id)

        let dwell = settings.dwellSeconds
        log("RAW ENTER for \(id). Waiting \(dwell)s to confirm…")

        timers[id] = Task {
            do {
                try await Task.sleep(for: .seconds(dwell))
            } catch { return } // cancelled

            await MainActor.run {

                // CANCEL if state changed during dwell
                if presence[id]?.presence != .inside {
                    log("ENTER cancelled for \(id) — state changed during dwell.")
                    return
                }

                guard let state = presence[id] else { return }

                // CANCEL if device actually left during dwell
                if state.presence == .outside {
                    log("ENTER cancelled for \(id) (device left before dwell).")
                    return
                }

                // CANCEL if snoozed
                if let until = state.snoozedUntil, until > Date() {
                    log("ENTER for \(id) ignored due to snooze.")
                    return
                }

                // CONFIRM ENTER
                presence[id]?.lastConfirmedEnter = Date()
                presence[id]?.presence = .inside
                log("ENTERED confirmed for \(id).")
                Task { await updateMonitoringMode() }
                self.bannerMessage = "Entered region: \(id)"
                
                if self.isQuietHours() {
                    self.log("ENTERED confirmed for \(id) but silenced due to Quiet Hours.")
                    self.save()
                    return
                }

                NotificationService.shared.postGeofence(
                    title: "Entered Region",
                    body: "You entered \(id)",
                    userInfo: ["regionID": id.uuidString]
                )

                save()
            }
        }
    }
    
    func startExitDebounce(for id: UUID) {
        cancelTimers(for: id)

        let debounce = settings.exitDebounceSeconds
        log("RAW EXIT for \(id). Debouncing \(debounce)s…")

        exitTimers[id] = Task {
            do {
                try await Task.sleep(for: .seconds(debounce))
            } catch { return }

            await MainActor.run {

                guard let state = presence[id] else { return }

                // CANCEL if device re-entered during debounce
                if state.presence == .inside {
                    log("EXIT cancelled for \(id) (device re-entered).")
                    return
                }

                // CANCEL if snoozed
                if let until = state.snoozedUntil, until > Date() {
                    log("EXIT for \(id) ignored due to snooze.")
                    return
                }

                // CONFIRM EXIT
                presence[id]?.lastConfirmedExit = Date()
                presence[id]?.presence = .outside
                log("EXITED confirmed for \(id).")
                Task { await updateMonitoringMode() }
                self.bannerMessage = "Exited region: \(id)"
                
                if self.isQuietHours() {
                    self.log("EXITED confirmed for \(id) but silenced due to Quiet Hours.")
                    self.save()
                    return
                }

                NotificationService.shared.postGeofence(
                    title: "Exited Region",
                    body: "You left \(id)",
                    userInfo: ["regionID": id.uuidString]
                )

                save()
            }
        }
    }
    
    func canStartDwell(for id: UUID) -> Bool {
        guard let presence = presence[id]?.presence else { return true }

        if presence == .inside {
            log("Dwell not started for \(id): already INSIDE.")
            return false
        }
        return true
    }

    func canStartExit(for id: UUID) -> Bool {
        guard let presence = presence[id]?.presence else { return true }

        if presence == .outside {
            log("Exit debounce not started for \(id): already OUTSIDE.")
            return false
        }
        return true
    }

    // MARK: - Logging
    func log(_ message: String) {
        let entry = LogEntry(message: message)
        logs.append(entry)
        Persistence.save(logs, key: StoreKeys.logs)
    }

    // MARK: - Region CRUD
    func save() {
        Persistence.save(regions, key: StoreKeys.regions)
        Persistence.save(settings, key: StoreKeys.settings)
        Persistence.save(presence, key: StoreKeys.runtime)
    }

    func addRegion(_ r: GeoRegion) {
        regions.append(r)
        presence[r.id] = RegionRuntimeState()
        save()
        Task { await updateMonitoringMode() }
        log("Added region: \(r.name) (\(Int(r.radius)) m).")
    }

    func updateRegion(_ r: GeoRegion) {
        guard let idx = regions.firstIndex(where: { $0.id == r.id }) else { return }
        regions[idx] = r
        save()
        Task { await updateMonitoringMode() }
        log("Updated region: \(r.name).")
    }

    func deleteRegion(_ id: UUID) {
        if let idx = regions.firstIndex(where: { $0.id == id }) {
            let r = regions.remove(at: idx)
            presence[id] = nil
            save()
            Task { await updateMonitoringMode() }
            log("Deleted region: \(r.name).")
        }
    }

    func toggleEnabled(_ id: UUID) {
        guard let idx = regions.firstIndex(where: { $0.id == id }) else { return }
        regions[idx].enabled.toggle()
        save()
        Task { await updateMonitoringMode() }
        log("Toggled \(regions[idx].name) to \(regions[idx].enabled ? "enabled" : "disabled").")
    }

    func toggleBatteryMode() {
        settings.batteryMode =
            settings.batteryMode == .saver ? .highFidelity : .saver
        save()
        Task { await updateMonitoringMode() }
        log("Battery mode: \(settings.batteryMode.title).")
    }

    // MARK: - Monitoring
    func updateMonitoringMode() async {

        // Cleanup
        for r in location.monitoredRegions() {
            if let c = r as? CLCircularRegion { location.stopMonitoring(region: c) }
        }
        location.stopSignificant()
        location.stopVisits()

        // Cap at 20 (system hard limit)
        var enabled = regions.filter { $0.enabled }

        if let loc = lastLocation {
            enabled.sort {
                distance(from: loc, to: $0) < distance(from: loc, to: $1)
            }
        }

        let capped = Array(enabled.prefix(20))

        for r in capped {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude),
                radius: clampRadius(r.radius),
                identifier: r.id.uuidString
            )
            region.notifyOnEntry = r.notifyOnEntry
            region.notifyOnExit = r.notifyOnExit

            location.startMonitoring(region: region)
        }
        
        log("Priority scheduler: monitoring \(capped.count) / \(enabled.count) regions.")

        if let loc = lastLocation {
            for r in capped.prefix(5) {
                let d = Int(distance(from: loc, to: r))
                log(" • \(r.name) at \(d)m")
            }
        }

        switch settings.batteryMode {
        case .saver:
            location.startSignificant()
            location.startVisits()
        case .highFidelity:
            break
        }
    }
    
    func distance(from location: CLLocation, to region: GeoRegion) -> CLLocationDistance {
        let coord = CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude)
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return location.distance(from: target)
    }

    private func clampRadius(_ rad: Double) -> Double {
        if rad < 50 {
            log("Warning: radius \(Int(rad))m is small—clamped to 50 m.")
            return 50
        }
        if rad > 2000 {
            log("Warning: radius \(Int(rad))m is large—clamped to 2000 m.")
            return 2000
        }
        return rad
    }
}

// MARK: - Delegate
extension GeoVM: LocationServiceDelegate {

    func didChangeAuth(status: CLAuthorizationStatus, precise: Bool) {
        Task { @MainActor in
            self.authStatus = status
            self.preciseEnabled = precise

            switch status {
            case .authorizedAlways: authStatusDescription = "Always"
            case .authorizedWhenInUse: authStatusDescription = "When In Use"
            case .denied: authStatusDescription = "Denied"
            case .restricted: authStatusDescription = "Restricted"
            default: authStatusDescription = "Not determined"
            }
        }
    }

    func didEnter(region: CLRegion) {
        guard let uuid = UUID(uuidString: region.identifier) else { return }
        log("RAW ENTER for \(uuid)")

        presence[uuid] = presence[uuid] ?? RegionRuntimeState()
        presence[uuid]?.lastEnterRaw = Date()

        // Machine rule:
        guard canStartDwell(for: uuid) else { return }

        presence[uuid]?.presence = .inside
        save()

        startDwellTimer(for: uuid)
    }

    func didExit(region: CLRegion) {
        guard let uuid = UUID(uuidString: region.identifier) else { return }
        log("RAW EXIT for \(uuid)")

        presence[uuid] = presence[uuid] ?? RegionRuntimeState()
        presence[uuid]?.lastExitRaw = Date()

        // Machine rule:
        guard canStartExit(for: uuid) else { return }

        presence[uuid]?.presence = .outside
        save()

        startExitDebounce(for: uuid)
    }

    func didVisit(_ visit: CLVisit) {
        log("Visit event received.")
    }

    func didUpdateSignificant(_ location: CLLocation) {
        lastLocation = location
        log("Updated user location for priority scheduler.")
        Task { await updateMonitoringMode() }
    }

    func didFail(_ error: Error) {
        log("Location error: \(error.localizedDescription)")
    }

    func didDetermineState(_ state: CLRegionState, for region: CLRegion) {
        guard let uuid = UUID(uuidString: region.identifier) else { return }

        presence[uuid] = presence[uuid] ?? RegionRuntimeState()

        switch state {
        case .inside:
            presence[uuid]?.presence = .inside
            log("Initial state: INSIDE region \(uuid)")

        case .outside:
            presence[uuid]?.presence = .outside
            log("Initial state: OUTSIDE region \(uuid)")

        case .unknown:
            presence[uuid]?.presence = .unknown
            log("Initial state: UNKNOWN for region \(uuid)")

        @unknown default:
            break
        }

        save()
    }
}
