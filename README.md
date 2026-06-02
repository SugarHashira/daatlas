# daatlas

**Carry your diabetes data, everywhere.**

daatlas unifies data from your Oura Ring, Nightscout instance, and Tandem pump into Apple Health — one timeline for everything.

- **Oura Ring** — sleep, HRV, readiness, activity, SpO2, heart rate (no Oura subscription required, powered by [Cracked-Oura](https://github.com/EIrno/Cracked-Oura))
- **Nightscout** — glucose readings, insulin deliveries, carb entries
- **Tandem t:slim X2** — pump data via Nightscout

---

## What it does

```
Oura Ring   ──┐
Nightscout  ──┼──►  daatlas  ──►  Apple Health
Tandem pump ──┘                  (unified timeline)
```

Once synced, all your data lives in Apple Health — one place, available to every app in the ecosystem. daatlas is just the bridge. You choose what to do with the data.


## Features

- **Glucose sync** — Blood glucose readings in mg/dL or mmol/L
- **Insulin sync** — Bolus and basal deliveries mapped to HealthKit types
- **Carb sync** — Dietary carbohydrate entries
- **Oura sync** — Sleep, HRV, readiness, activity, SpO2, HR, temperature (no subscription needed)
- **Deduplication** — Never writes the same record twice
- **Background sync** — Runs automatically at intervals you choose (5 min – 2 hours)
- **Sync logs** — Full history of what was synced and when
- **Selective sync** — Enable only the data types you want

## Requirements

- iOS 16+
- A running [Nightscout](https://nightscout.github.io/) instance with REST API enabled
- Nightscout `API_SECRET` configured

## Setup

### 1. Nightscout

Ensure your Nightscout instance has:

```
API_SECRET=your_secret_here
ENABLE=api
```

### 2. Install

```bash
git clone https://github.com/SugarHashira/daatlas.git
open daatlas.xcodeproj
# Build and run on your device
```

### 3. Configure

1. Open daatlas
2. Tap the gear icon → **Settings**
3. Enter your **Nightscout URL** (e.g. `https://your-nightscout.fly.dev`)
4. Enter your **API Secret**
5. Tap **Test Connection**
6. Tap **Request HealthKit Authorization**
7. Enable the data types you want synced

### 4. Sync

Tap **Sync Now** for a manual sync, or enable **Auto-sync** for background operation.

## Data mapping

| Source | Data | Apple Health |
|---|---|---|
| Nightscout | SGV entries | Blood Glucose |
| Nightscout | Bolus treatments | Insulin Delivery (Bolus) |
| Nightscout | Temp basal treatments | Insulin Delivery (Basal) |
| Nightscout | Carb treatments | Dietary Carbohydrates |
| Oura Ring | Sleep stages | Sleep Analysis |
| Oura Ring | HRV | Heart Rate Variability |
| Oura Ring | Heart rate | Heart Rate |
| Oura Ring | SpO2 | Blood Oxygen |
| Oura Ring | Temperature deviation | Body Temperature |
| Oura Ring | Respiratory rate | Respiratory Rate |
| Oura Ring | Activity | Active Energy / Steps |

## Nightscout hosting options

- **[Fly.io](https://fly.io)** — Docker-based, fast, free tier available → [setup guide](https://nightscout.github.io/nightscout/fly/)
- **[Railway](https://railway.app)** — Simple deploy from GitHub
- **[Heroku](https://heroku.com)** — Classic option (paid plans only now)
- **Self-hosted** — Raspberry Pi or any server with Docker

## CGM / pump support

daatlas reads from Nightscout's API, so it works with any CGM or pump that uploads to Nightscout:

- Dexcom (via xDrip+, Spike, or Dexcom Share)
- Libre (via xDrip+, Diabox, or Juggluco)
- Medtronic (via openaps / Loop)
- Tandem (via t:connect integration)
- DIY closed-loop systems (Loop, AndroidAPS, OpenAPS)

## Troubleshooting

**Connection failed** — Check your Nightscout URL and API secret. Verify the instance is online.

**HealthKit authorization denied** — Go to iOS Settings → Privacy & Security → Health → daatlas → enable write access for each data type.

**Data not appearing** — Confirm sync completed in Sync Logs. Check that write permissions were granted for that specific data type.

## Tech stack

- **SwiftUI** — Declarative UI
- **HealthKit** — Apple Health integration
- **Swift Concurrency** — async/await throughout
- **iOS 16+** — Minimum deployment target

## Credits

- **[Cracked-Oura](https://github.com/EIrno/Cracked-Oura)** — reverse-engineered Oura API access without a subscription. daatlas's Oura integration is built on top of this work.
- **[tconnectsync-heroku](https://github.com/jwoglom/tconnectsync-heroku)** — syncs Tandem t:slim X2 pump data from t:connect to Nightscout. The bridge that brings Tandem data into the pipeline.
- **[Nightscout](https://github.com/nightscout/cgm-remote-monitor)** — open-source diabetes data platform that makes all of this possible.

## Roadmap

- **Better notifications** — Glucose alerts, sync failure warnings, daily health summary push notifications
- **Live Activity improvements** — Real-time glucose on Dynamic Island and Lock Screen with trend arrows and time-in-range
- **Food logging** — AI-assisted carb estimation from photos, barcode scanning, meal history
- **Apple Watch app** — Quick sync status, glucose glance, complication support
- **Shortcuts & automation** — Siri Shortcuts integration, automations triggered by glucose levels
- **VO2 Max sync** — Write Oura VO2 Max estimates to HealthKit
- **Widget** — Home screen widget showing current glucose + last night's sleep score + HRV
- **CSV / PDF export** — Export synced data for clinic visits
- **iCloud sync** — Settings and sync history backed up across devices

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.

## Disclaimer

daatlas is not a medical device. It is a data utility for personal use. Always consult your healthcare provider for diabetes management decisions.
