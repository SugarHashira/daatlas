<p align="center">
  <img src="https://raw.githubusercontent.com/SugarHashira/daatlas/master/docs/icon.png" width="120" alt="daatlas app icon" />
</p>

# daatlas

**Carry your diabetes data, everywhere.**

A privacy-first diabetes data bridge for iOS. Syncs glucose, insulin, carbs, and wearable data from Nightscout, Dexcom, and Oura Ring into Apple Health — entirely on-device, no backend, no account required.

> iOS 16+ · SwiftUI · HealthKit · Swift Concurrency

---

## What it does

```
Nightscout  ──┐
Dexcom      ──┼──►  daatlas  ──►  Apple Health  ──►  Any app in the ecosystem
Oura Ring   ──┤                  (unified timeline)
Tandem pump ──┘
```

All your diabetes data lands in one place. daatlas is the bridge — you own the data.

---

## Integrations

| Source | Method | Data |
|--------|--------|------|
| **Nightscout** | REST API (API_SECRET) | Glucose, insulin (bolus + basal), carbs |
| **Dexcom** | Share API (username/password) | CGM readings |
| **Oura Ring** | OAuth token or CSV export | Sleep, HRV, readiness, activity, SpO2, HR, temperature, respiratory rate |
| **Tandem t:slim X2** | Via Nightscout (tconnectsync) | Pump events |
| **Apple HealthKit** | Framework | Primary data sink |

---

## Features

- **Multi-source glucose sync** — Nightscout SGVs or Dexcom Share in mg/dL or mmol/L
- **Insulin tracking** — Bolus and basal deliveries mapped to HealthKit insulin types
- **Carb logging** — Dietary carb entries from Nightscout
- **Oura sync** — Sleep, HRV, readiness, activity, SpO2, heart rate, temperature (no subscription required)
- **Deduplication** — Two-tier system: Nightscout `_id` in HealthKit metadata + timestamp fallback
- **Background sync** — Configurable intervals (5 min – 2 hours) via `BGAppRefreshTask` and `BGProcessingTask`
- **Sync logs** — Complete audit trail of what synced and when
- **Selective sync** — Enable or disable individual data types
- **Dashboard** — Correlates glucose, insulin, sleep, and activity in one view
- **Trends** — Historical data visualisation with Apple Charts
- **Live Activities** — Glucose on Dynamic Island and Lock Screen
- **Widgets** — Home screen glucose widget via WidgetKit
- **Claude export** — Export a date-range data dump for AI analysis

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Health data | HealthKit |
| Concurrency | Swift async/await · `actor` types throughout |
| Background | BGAppRefreshTask · BGProcessingTask |
| Charts | Swift Charts (Apple) |
| Widgets | WidgetKit |
| Live Activities | ActivityKit |
| Auth | SHA1 via CryptoKit (Nightscout) |
| Networking | URLSession (no Alamofire) |
| Build | XcodeGen (`project.yml`) |
| Dependencies | ZIPFoundation 0.9.19+ |
| Min target | iOS 16.0 |

---

## Architecture

```
SwiftUI Views (@EnvironmentObject SyncViewModel)
        │
        ▼
SyncViewModel (@MainActor, 50+ @Published properties)
        │
        ├── NightscoutService (actor)   ─► glucose, insulin, carbs
        ├── DexcomService     (actor)   ─► CGM readings
        ├── OuraService       (actor)   ─► sleep, HRV, vitals
        └── HealthKitService  (actor)   ─► Apple Health read/write

UserSettings (actor) ─► UserDefaults wrapper (25+ keys)
```

All services are `actor` types — compile-time thread safety, no manual locking, no data races. `HealthKitService` is the single write path to Apple Health.

**Deduplication** is two-tier: primary key is the Nightscout `_id` stored in HealthKit sample metadata; fallback is minute-rounded timestamp comparison for legacy entries.

---

## Build

Requires Xcode 15+ and a device or simulator running iOS 16+.

```bash
git clone https://github.com/SugarHashira/daatlas.git
cd daatlas

# (Optional) regenerate Xcode project from project.yml
brew install xcodegen
xcodegen generate

open daatlas.xcodeproj
# Cmd+B to build · Cmd+R to run
```

---

## Setup

### Nightscout

Ensure your Nightscout instance has REST API enabled:

```
API_SECRET=your_secret_here
ENABLE=api
```

In daatlas → Settings → enter your **Nightscout URL** and **API Secret** → tap **Test Connection** → **Request HealthKit Authorization** → enable the data types you want synced.

### Nightscout hosting options

- **[Fly.io](https://fly.io)** — Docker-based, free tier available → [setup guide](https://nightscout.github.io/nightscout/fly/)
- **[Railway](https://railway.app)** — Simple deploy from GitHub
- **[Heroku](https://heroku.com)** — Classic option (paid plans only now)
- **Self-hosted** — Raspberry Pi or any server with Docker

### Dexcom

In daatlas → Settings → Dexcom → enter your Dexcom Share **username** and **password**.

### Oura Ring

**With membership:** In daatlas → Settings → Oura → enter your **API token** for seamless background sync.

**Without membership:** Use the [Cracked-Oura](https://github.com/EIrno/Cracked-Oura) export workflow — trigger a data report from the Oura web portal, download the export, and import via daatlas → Settings → Oura → Import Export.

---

## Data mapping

| Source | Data | Apple Health |
|--------|------|-------------|
| Nightscout | SGV entries | Blood Glucose |
| Nightscout | Bolus treatments | Insulin Delivery (Bolus) |
| Nightscout | Temp basal treatments | Insulin Delivery (Basal) |
| Nightscout | Carb treatments | Dietary Carbohydrates |
| Dexcom | CGM readings | Blood Glucose |
| Oura | Sleep stages | Sleep Analysis |
| Oura | HRV | Heart Rate Variability |
| Oura | Heart rate | Heart Rate |
| Oura | SpO2 | Blood Oxygen |
| Oura | Temperature deviation | Body Temperature |
| Oura | Respiratory rate | Respiratory Rate |
| Oura | Activity | Active Energy / Steps |

---

## CGM / pump support

daatlas reads from Nightscout's API, so it works with any CGM or pump that uploads to Nightscout:

- Dexcom (via xDrip+, Spike, or Dexcom Share)
- Libre (via xDrip+, Diabox, or Juggluco)
- Medtronic (via openaps / Loop)
- Tandem (via t:connect integration)
- DIY closed-loop systems (Loop, AndroidAPS, OpenAPS)

---

## Project structure

```
daatlas/Sources/
├── App/
│   ├── HealthSyncApp.swift          # @main entry, dependency injection
│   └── AppDelegate.swift            # Background task registration & scheduling
├── Models/
│   ├── GlucoseEntry.swift           # SGV with mg/dL ↔ mmol/L conversion
│   ├── NightscoutTreatment.swift    # Insulin (bolus/basal), carbs
│   ├── OuraModels.swift             # Sleep, HRV, activity, vitals
│   ├── DexcomModels.swift           # Dexcom reading structures
│   ├── UserSettings.swift           # Actor-wrapped UserDefaults (25+ keys)
│   └── SyncLog.swift                # Sync operation audit trail
├── Services/
│   ├── SyncService.swift            # Actor: orchestrates all syncs
│   ├── NightscoutService.swift      # Actor: Nightscout REST client
│   ├── OuraService.swift            # Actor: Oura Ring API client
│   ├── DexcomService.swift          # Actor: Dexcom Share API client
│   └── HealthKitService.swift       # Actor: HealthKit read/write
├── ViewModels/
│   └── SyncViewModel.swift          # @MainActor: all published state
└── Views/
    ├── RootView.swift               # Tab navigation
    ├── VitalsTabView.swift          # Current glucose, HR, SpO2
    ├── TrendsTabView.swift          # Historical charts
    ├── DashboardView.swift          # Correlation view
    ├── SettingsTabView.swift        # Settings hub
    └── ClaudeExportView.swift       # AI data export
GlucoseWidget/                       # WidgetKit target
```

---

## Known limitations

- **Oura without membership requires manual export** — no real-time background sync; re-export needed for new data
- **No offline sync** — all syncs require network connectivity
- **No token auto-refresh for Oura** — manual re-auth when tokens expire
- **Food carb estimation is manual** — no AI-assisted entry yet

---

## Roadmap

- **Live Activity improvements** — real-time glucose on Dynamic Island with trend arrows and time-in-range
- **Food logging** — AI-assisted carb estimation from photos, barcode scanning, meal history
- **Apple Watch app** — quick sync status, glucose glance, complication support
- **Shortcuts & automation** — Siri Shortcuts, glucose-triggered automations
- **VO2 Max sync** — Oura VO2 Max to HealthKit
- **Widget** — home screen glucose + sleep score + HRV
- **CSV / PDF export** — data dump for clinic visits
- **iCloud sync** — settings and sync history across devices

---

## Great apps in the diabetes space

- **[Gluroo](https://gluroo.com)** — a beautifully designed diabetes management app. If you want a polished all-in-one experience, check it out.
- **[Stash Diabetes](https://www.stashdiabetes.com)** — great app for managing and tracking diabetes supplies.
- **[xDrip4iOS](https://xdrip4ios.readthedocs.io)** — open-source CGM reader for iOS. Supports a wide range of sensors and is the go-to for DIY CGM setups.

---

## Acknowledgements

- **[Cracked-Oura](https://github.com/EIrno/Cracked-Oura)** — reverse-engineered Oura API access without a subscription. daatlas's Oura integration is built on top of this work.
- **[tconnectsync-heroku](https://github.com/jwoglom/tconnectsync-heroku)** — syncs Tandem t:slim X2 pump data from t:connect to Nightscout.
- **[Nightscout](https://github.com/nightscout/cgm-remote-monitor)** — open-source diabetes data platform that makes all of this possible.

---

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.

---

## Disclaimer

daatlas is not a medical device. It is a data utility for personal use. Always consult your healthcare provider for diabetes management decisions.
