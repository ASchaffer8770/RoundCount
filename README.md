# RoundCount 🎯

**RoundCount** is an iOS app for tracking firearms, range sessions, ammo usage, and gear setups — built with a strong focus on **real-world shooting**, **data ownership**, and a clean, modern UX.

The app is designed with a **Free tier** for casual shooters and a **Pro tier** for competitors, instructors, and serious enthusiasts who want deeper insights into their training.

---

## ✨ Core Features

### Free
- Track firearms (brand, model, caliber, class)
- Log range sessions (round count, date, notes)
- Track total rounds per firearm
- Review session history per firearm

### Pro (In Progress / Shipping)
- Session photos (stored locally, on-device)
- Malfunction tracking (categorized + totals)
- Total range time per session
- Firearm setups (optic / light / gear configurations)
- Session → Setup linkage (review what setup was used)
- Branded UI with subtle neon glow cards
- Future analytics, maintenance, and exports

> **Privacy-first:** All data is stored locally on-device. No cloud, no accounts, no tracking.

---

## 🧱 Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **Architecture:** Local-first, model-driven
- **Platform:** iOS
- **Monetization:** Feature-gated Pro tier (StoreKit planned)

---

## 📌 Project Status

**Current version:** Internal MVP  
**Target public v1.0:** ~March 15, 2026


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

### 🔜 Phase 3 — Gear & Battery Lifecycle (In Progress)
- [ ] Setup CRUD UI (add / edit / delete)
- [ ] Gear items (optic, light, etc.)
- [ ] Battery tracking (install date, life)
- [ ] Mark battery changes
- [ ] Derived stats (days / rounds since change)

---

### 🔜 Phase 4 — Analytics & Maintenance
- [ ] Advanced analytics (malfunctions per 1k rounds, trends)
- [ ] Maintenance reminders (round-based + time-based)
- [ ] CSV / PDF export
- [ ] Ammo inventory integration

---

### 🔮 Phase 5 — Target Analysis (Future / R&D)
- [ ] Target photo capture
- [ ] Grouping pattern detection
- [ ] Technique suggestions (conservative, non-prescriptive)

---

## 🧠 Design Philosophy

- **Local-first**: Your data stays on your device
- **Fast logging**: Minimal friction at the range
- **Reviewable history**: Sessions are only useful if you can review them
- **No fluff**: Features exist because shooters actually use them

---

## 🚧 Disclaimer

RoundCount is intended for **training and logging purposes only**.  
It does **not** provide firearms advice, safety instruction, or tactical guidance.

---

## 📄 License

MIT License — see `LICENSE` for details.

