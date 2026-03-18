# RoundCount 🎯

**RoundCount** is a local-first iOS app for tracking firearms, live range sessions, ammo usage, and gear setups — built for **real-world shooters** who want fast logging, trustworthy data, and meaningful insights without cloud lock-in.

The app offers a **Free tier** for casual shooters and a **Pro tier** for competitors, instructors, and serious enthusiasts who want deeper analytics and long-term training insight.

---

## ✨ Core Features

### Free
- Track firearms (brand, model, caliber, class)
- Log live range sessions with time tracking
- Track total rounds per firearm
- Review session history per firearm
- Local-only storage (no accounts, no sync)

### Pro
- Live timed sessions with run-by-run logging
- Malfunction tracking (categorized + totals)
- Total range time per session
- Firearm setups (optic / light / gear configurations)
- Session → setup linkage
- Reliability & usage analytics
- Ammo inventory tracking with auto-decrement and replenishment prompts
- UPC barcode scanning to auto-fill ammo details
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

## 📦 Ammo Inventory (Pro)

Track how many rounds you have on hand for any ammo in your library.

- **Opt-in per product** — enable inventory tracking individually; non-tracked ammo is unaffected
- **Auto-decrement** — rounds are automatically deducted when you end a live session
- **Replenishment prompts** — if a session would put an ammo below zero, RoundCount asks if you picked up more at the range before finalizing
- **Adjust stock anytime** — add or remove rounds manually from the ammo detail view
- **Inventory summary** — the Ammo tab header shows total rounds on hand across all tracked products (Pro)

---

## 📷 Barcode Scanning (Pro)

Scan any factory ammo box UPC to auto-fill product details when adding ammo to your library.

- Looks up caliber, grain weight, bullet type, brand, quantity per box, and case material
- Results are cached on-device for instant re-scans
- Falls back to manual entry if a barcode isn't recognized

---

## 🧭 App Walkthrough

First-time users are guided through the app with **coach mark overlays** — contextual tooltips that highlight key UI elements and explain the workflow for each section.

- Covers: Dashboard, Live Session (3 steps), Ammo, and Firearms tabs
- Progress is saved per-sequence; each sequence only plays once
- Can be replayed anytime from **Settings → Replay App Walkthrough**

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

- **Current version:** `1.2`
- **Status:** Active development / TestFlight
- **Public release:** Live on App Store

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

### ✅ Phase 3 — Analytics & Reliability (Complete)
- [x] Dashboard analytics
- [x] Per-firearm analytics
- [x] Time-range filtering
- [x] Snapshot-based analytics engine
- [x] Reliability polish & validation

---

### ✅ Phase 4 — Inventory & UX (Complete)
- [x] Ammo inventory tracking (opt-in, per-product)
- [x] Auto-decrement on session end
- [x] Replenishment prompt when stock runs out
- [x] UPC barcode scanning with on-device caching
- [x] Coach mark onboarding walkthrough
- [x] Walkthrough replay in Settings

---

### 🔜 Phase 5 — Maintenance & Export
- [ ] Maintenance tracking (round-based + time-based)
- [ ] Gear battery lifecycle tracking
- [ ] CSV / PDF export

---

### 🔮 Phase 6 — Target Analysis (Future / R&D)
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
