# FitQuest — Neumorphic Weight-Loss App

A cross-platform (iOS + Android) **Flutter** app rebuilt from the v2 _Neumorphic_ web
prototype, backed by a **Node.js + PostgreSQL** API with **Razorpay** payments and
**Claude vision** AI meal analysis.

```
ObsesityApp/
├── app/        Flutter app (iOS + Android)
├── backend/    Express + PostgreSQL REST API
└── README.md
```

## Screens (17)
Splash · Welcome/Promise · Login/OTP · Health Quiz · Meet Coach · Plan/Payment ·
Home Dashboard · Today's Plan · Daily Check-in · Log Meal Photo · Badge Unlock ·
Chat/Coach AI · My Group/Leaderboard · Posts Feed · Profile/Progress · Learning Hub ·
Settings — tied together by a 5-tab bottom-nav shell (Home · Today · Group · Chat · Profile).

The neumorphic design system (colors, soft dual-shadows, Plus Jakarta Sans, Material
Symbols Rounded) lives in `app/lib/core/theme/` and `app/lib/core/widgets/`.

---

## 1. Run the app (Android emulator / device)

> Requires Flutter SDK (already at `C:\flutter`). The app runs standalone in **demo mode**
> (seeded data, dev OTP, mock payment/AI) even without the backend.

```powershell
cd app
flutter pub get
flutter run                 # pick your emulator/device
```

**Demo login:** enter any 10-digit phone → OTP code **`123456`**.

Point the app at a running backend with `--dart-define` (the Android emulator reaches your
host machine at `10.0.2.2`):

```powershell
flutter run --dart-define=API_BASE=http://10.0.2.2:4000 --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx
```

### iOS
The Dart/iOS code is configured (Info.plist camera + photo permissions set). Building an iOS
**device** binary requires macOS + Xcode + an Apple Developer account. On macOS:
```bash
cd app && flutter run        # iOS simulator
```

---

## 2. Run the backend

```powershell
cd backend
npm install
copy .env.example .env        # then edit values
npm run migrate               # creates tables + seeds coach/lessons/badges
npm run dev                   # http://localhost:4000  (GET /health)
```

### Environment (`backend/.env`)
| Var | Purpose | If unset |
|-----|---------|----------|
| `DATABASE_URL` | PostgreSQL connection | **required** |
| `JWT_SECRET` | token signing | falls back to dev secret |
| `MSG91_AUTH_KEY` | OTP SMS (India) | dev fixed OTP `123456` accepted |
| `RAZORPAY_KEY_ID` / `_SECRET` | payments | `/payments/order` returns 503 → app uses demo checkout |
| `ANTHROPIC_API_KEY` | Claude meal vision | `/meals/analyze` returns a mock result |

### Key endpoints
- `POST /auth/otp/request`, `POST /auth/otp/verify` → JWT
- `GET /profile`, `POST /profile/quiz`, `GET /coach`
- `GET /dashboard`, `GET /today`, `POST /today/task/:id/complete`
- `POST /checkins`, `GET /checkins`
- `POST /meals/analyze` (Claude vision), `POST /meals`
- `POST /payments/order`, `POST /payments/verify` (Razorpay HMAC)
- `GET /group/leaderboard`, `GET /posts`, `POST /posts/:id/like`
- `GET /lessons`, `GET /chat`, `POST /chat`

---

## How the integrations are wired
- **OTP auth** — `app/lib/core/state/session.dart` ↔ `backend/src/routes/auth.js`.
- **Razorpay** — `app/lib/features/payment/plan_payment_screen.dart` creates an order via
  the backend, opens the Razorpay sheet, and verifies the signature server-side.
- **Claude vision** — the meal photo is base64-encoded and sent to `POST /meals/analyze`,
  which calls Anthropic and returns `{items, calories, confidence, carbs, protein, fat}`.

All three degrade gracefully to demo behavior when their keys/backend are absent, so every
screen is usable end-to-end out of the box.

## Notes
- App package id: `com.fitquest.fitquest`. Razorpay test mode recommended until go-live.
- For production OTP, configure an MSG91 template and remove `DEV_FIXED_OTP`.
