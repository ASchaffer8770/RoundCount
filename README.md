# RoundCount 🎯

**RoundCount** is a local-first iOS app for tracking firearms, live range sessions, ammo usage, and gear setups — built for **real-world shooters** who want fast logging, trustworthy data, and meaningful insights without cloud lock-in.

The app offers a **Free tier** for casual shooters and a **Pro tier** for competitors, instructors, and serious enthusiasts who want deeper analytics and long-term training insight.

---

## ✨ Core Features

### Free
- Track firearms (brand, model, caliber, class)
- Log live or manual range sessions
- Track total rounds per firearm
- Review session history per firearm
- Local-only storage (no accounts, no sync)

### Pro
- Live timed sessions (Session v2)
- Session photos (targets / malfunctions)
- Malfunction tracking (categorized + totals)
- Total range time per session
- Firearm setups (optic / light / gear configurations)
- Session → Setup linkage
- Reliability & usage analytics
- Branded UI with subtle neon accent cards

> **Privacy-first:** All data is stored locally on-device.  
> No accounts. No cloud. No tracking. Ever.

---

## 📊 Analytics (Pro)

RoundCount Pro includes **on-device analytics** designed to answer practical questions shooters actually care about — without exporting data or relying on the cloud.

### Dashboard Analytics
- Total rounds fired
- Total range time
- Malfunctions per 1k rounds
- Rounds over time (range-selectable)
- Top firearms & setups by usage
- Ammo usage by caliber / product

### Per-Firearm Analytics
- Firearm-specific round totals
- Reliability metrics
- Setup usage breakdown
- Time-range filtering (7D / 30D / 90D / 1Y / All)

Analytics are computed from **session snapshots** to ensure performance, accuracy, and UI stability.

---

## 🧱 Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Charts:** Swift Charts + custom lightweight charts
- **Persistence:** SwiftData
- **Architecture:** Local-first, model-driven
- **Platform:** iOS
- **Monetization:** Feature-gated Pro tier (StoreKit)

---

## 📌 Project Status

- **Current version:** `0.9.0 (Build 1)`
- **Status:** Internal TestFlight
- **Target public v1.0:** ~March 15, 2026

The core V1 feature set is implemented.  
Current work is focused on **UX polish, reliability fixes, analytics trust, and TestFlight feedback** ahead of public launch.

---

## 🗺 Roadmap

### ✅ Phase 1 — Core MVP (Complete)
- [x] Firearm model + CRUD
- [x] Manual session logging
- [x] Ammo library
- [x] Session history per firearm
- [x] Free / Pro entitlement system
- [x] Paywall UI

---

### ✅ Phase 2 — Sessions v2 (Live Sessions) (Complete)
- [x] Live, timed shooting sessions
- [x] Firearm runs within a session
- [x] Total range time
- [x] Session notes & summaries
- [x] Pro feature gating
- [x] Branded card system

---

### ✅ Phase 2.5 — Sessions ↔ Gear (Complete)
- [x] Firearm setups (per firearm)
- [x] Select setup during session
- [x] Setup shown in session detail
- [x] Pro-only gating + paywall entry points

---

### 🟡 Phase 3 — Analytics & Reliability (In Progress)
- [x] Dashboard analytics
- [x] Per-firearm analytics
- [x] Time-range filtering
- [x] Snapshot-based analytics engine
- [x] Reliability polish & validation
- [ ] Performance tuning

---

### 🔜 Phase 4 — Maintenance & Inventory
- [ ] Maintenance tracking (round-based + time-based)
- [ ] Gear battery lifecycle tracking
- [ ] Ammo inventory integration
- [ ] CSV / PDF export

---

### 🔮 Phase 5 — Target Analysis (Future / R&D)
- [ ] Target photo analysis
- [ ] Grouping pattern detection
- [ ] Conservative, non-prescriptive technique insights

---

## 🧠 Design Philosophy

- **Local-first** — your data stays on your device
- **Shooter-native** — built around real range habits
- **Low-friction logging** — fast sessions matter
- **Trust over fluff** — analytics you can rely on

---

## 🚧 Disclaimer

RoundCount is intended for **training and logging purposes only**.  
It does **not** provide firearms instruction, safety guidance, or tactical advice.

---

## 📄 License

MIT License — see `LICENSE` for details.
