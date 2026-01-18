# RoundCount 🎯

**RoundCount** is a local-first iOS app for tracking firearms, range sessions, ammo usage, and gear setups — built for **real-world shooters** who want clean data, fast logging, and meaningful insights without cloud lock-in.

The app offers a **Free tier** for casual shooters and a **Pro tier** for competitors, instructors, and serious enthusiasts who want deeper analytics and long-term training insight.

---

## ✨ Core Features

### Free
- Track firearms (brand, model, caliber, class)
- Log range sessions (round count, date, notes)
- Track total rounds per firearm
- Review session history per firearm

### Pro
- Session photos (stored locally, on-device)
- Malfunction tracking (categorized + totals)
- Total range time per session
- Firearm setups (optic / light / gear configurations)
- Session → Setup linkage
- Analytics dashboards (global + per-firearm)
- Branded UI with subtle neon card styling

> **Privacy-first:** All data is stored locally on-device.  
> No accounts. No cloud. No tracking.

---

## 📊 Analytics (Pro)

RoundCount Pro includes **local, on-device analytics** designed to answer practical questions shooters actually care about:

### Dashboard Analytics
- Total rounds fired
- Total range time
- Malfunctions per 1k rounds
- Rounds over time (range-selectable)
- Top setups by usage
- Top ammo by rounds fired

### Per-Firearm Analytics
- Firearm-specific round totals
- Daily & weekly round trends
- Setup usage breakdown
- Malfunction rates per firearm
- Time-range filtering (7D / 30D / 90D / 1Y / All)

Analytics are computed from **immutable snapshots** to ensure performance and avoid UI render loops.

---

## 🧱 Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Charts:** Swift Charts + custom lightweight charts
- **Persistence:** SwiftData
- **Architecture:** Local-first, model-driven
- **Platform:** iOS
- **Monetization:** Feature-gated Pro tier (StoreKit planned)

---

## 📌 Project Status

- **Current version:** `0.9.0 (1)`
- **Status:** Internal TestFlight (Phase 1)
- **Target public v1.0:** ~March 15, 2026

This build is feature-complete for core logging, setups, and analytics.  
Ongoing work is focused on polish, battery lifecycle tracking, and maintenance features.

---

## 🗺 Roadmap

### ✅ Phase 1 — MVP (Complete)
- [x] Firearm model + CRUD
- [x] Session logging
- [x] Ammo selection
- [x] Session review per firearm
- [x] Free / Pro entitlement system
- [x] Paywall UI

---

### ✅ Phase 2 — Sessions v2 (Pro MVP) (Complete)
- [x] Session photos
- [x] Malfunction tracking
- [x] Total range time
- [x] Session detail view
- [x] Pro feature gating + locked UI
- [x] Branded neon card styling

---

### ✅ Phase 2.5 — Sessions ↔ Gear Linkage (Complete)
- [x] Firearm setups (per firearm)
- [x] Select setup when logging a session
- [x] Review setup used in session detail
- [x] Pro-only gating + paywall entry points

---

### 🟡 Phase 3 — Analytics & Battery Foundations (In Progress)
- [x] Dashboard analytics (global)
- [x] Per-firearm analytics
- [x] Time-range filtering
- [x] Snapshot-based analytics engine
- [ ] Gear battery lifecycle tracking
- [ ] Days / rounds since battery change

---

### 🔜 Phase 4 — Maintenance & Export
- [ ] Maintenance reminders (round-based + time-based)
- [ ] CSV / PDF export
- [ ] Ammo inventory integration

---

### 🔮 Phase 5 — Target Analysis (Future / R&D)
- [ ] Target photo capture
- [ ] Grouping pattern detection
- [ ] Conservative technique insights (non-prescriptive)

---

## 🧠 Design Philosophy

- **Local-first** — your data stays on your device
- **Fast logging** — minimal friction at the range
- **Reviewable history** — sessions only matter if you can review them
- **No fluff** — features exist because shooters actually use them

---

## 🚧 Disclaimer

RoundCount is intended for **training and logging purposes only**.  
It does **not** provide firearms advice, safety instruction, or tactical guidance.

---

## 📄 License

MIT License — see `LICENSE` for details.
