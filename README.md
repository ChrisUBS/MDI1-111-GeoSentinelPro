# GeoSentinel Pro — Advanced Geofencing for iOS (SwiftUI, iOS 16+)

**GeoSentinel Pro** is a production-grade geofencing demo app built for  
**MDI1 111 — Assignment 2**.  
It showcases robust region monitoring, dwell/debounce filtering, background delivery, and battery-aware geolocation strategies using **SwiftUI + Core Location**.  
The project mimics real-world geofencing techniques used in fitness, automation, and enterprise apps.

---

## 🎥 Demo Preview

Below is a short animated demonstration of the core features:

![Demo](demo.gif)

---

## ✨ Features

### 🛰️ Geofencing Core
- Create, edit, enable/disable, and delete geofences.
- Up to **20 monitored CLCircularRegions** (system hard limit).
- **Dwell detection** → confirm ENTER only after N seconds inside.
- **Exit debounce** → confirm EXIT only after N seconds outside.
- Automatic radius clamping with warnings (min **50 m**, max **2000 m**).
- State machine per region (Unknown → Inside/Outside).

### 🔋 Battery-Aware Modes
- **High Fidelity**
  - Direct region monitoring
  - Precise state reconciliation
- **Battery Saver**
  - Significant-Change service
  - Visits monitoring
  - Opportunistic region rebuilding
  - Minimal GPS usage

### 🔔 Notifications
- Actionable notifications:
  - **SNOOZE 15m**
  - **MARK DONE**
- Delivered in foreground & background.
- Optional **Quiet Hours** (notifications suppressed but logs preserved).

### 💾 Persistence
- Regions, settings, runtime state, and log history stored via `UserDefaults`.
- State restored using `requestState(for:)` after launch.

### 🗺️ UI (SwiftUI)
- Region list with live state (Inside / Outside / Unknown).
- Map editor with tap-to-create and adjustable radius.
- Debug Console: scrollable logs with timestamps + event reasons.
- Settings screen:
  - dwell/debounce controls  
  - battery mode  
  - region limit  
  - quiet hours  
- Onboarding Welcome screen guiding permissions.

---

## 📱 Requirements

- **iOS 16+**
- **Xcode 15+**
- Physical device recommended (Simulator limits region monitoring).

---

## 🚀 Installation Instructions

1. Create a new project:  
   **Xcode → File → New → Project… → iOS App (SwiftUI)**  
   Name it: `GeoSentinelPro`.

2. Close Xcode.

3. Replace the auto-generated project folder with the contents of this repo.

4. Reopen Xcode and configure:

### **Signing & Capabilities**
- Background Modes → **Location updates**
- Background Modes → *Remote notifications* (optional)
- Push Notifications capability (optional)

### **Info.plist Keys**
Add:

- `NSLocationWhenInUseUsageDescription`  
  "GeoSentinel Pro needs your location to monitor geofences while using the app."

- `NSLocationAlwaysAndWhenInUseUsageDescription`  
  "Always access allows GeoSentinel Pro to confirm enter/exit events in the background."

- `NSLocationTemporaryUsageDescriptionDictionary` *(optional for precise upgrades)*

---

## 📚 File Overview

- `GeoSentinelProApp.swift` — App entry point + notification delegate.
- `Models/`  
  Region, settings, runtime state, log entries.
- `Services/LocationService.swift`  
  Core Location manager + delegate bridging.
- `Services/NotificationService.swift`  
  Notification categories, actions, and posting.
- `Utilities/Persistence.swift`  
  Simple JSON encode/decode in `UserDefaults`.
- `ViewModel/GeoVM.swift`  
  Dwell/debounce logic, state machine, scheduling, logging.
- `Views/`  
  Region list, Map editor, Debug console, Settings, Welcome flow.

---

GeoSentinel Pro — *A production-style geofencing system built for academia, designed like a real-world app.*

