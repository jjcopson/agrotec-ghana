# Agrotech Ghana — Setup Guide

## Prerequisites

Install these tools before starting:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or later)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Node.js](https://nodejs.org) (for Supabase edge functions)
- [Deno](https://deno.land) (for edge functions runtime)
- [Android Studio](https://developer.android.com/studio) (for Android)
- [Xcode](https://developer.apple.com/xcode/) (for iOS/macOS — Mac only)

---

## Step 1 — Flutter setup

```bash
# In the project root
flutter pub get
```

Download the Poppins font files and place them in `assets/fonts/`:
- Poppins-Regular.ttf
- Poppins-Medium.ttf
- Poppins-SemiBold.ttf
- Poppins-Bold.ttf

Get them free from: https://fonts.google.com/specimen/Poppins

---

## Step 2 — Supabase project

1. Go to https://supabase.com and create a new project
2. Name it **Agrotech Ghana**, region: **EU West** (closest to Ghana)
3. Once created, go to **Settings → API** and copy:
   - Project URL
   - anon/public key
   - service_role key (keep secret — only for edge functions)

4. Open `lib/core/constants/app_constants.dart` and replace:
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

---

## Step 3 — Run database migrations

In the Supabase dashboard → **SQL Editor**, run these files in order:

1. `supabase/migrations/001_core_schema.sql`
2. `supabase/migrations/002_marketplace_schema.sql`
3. `supabase/migrations/003_consultation_transport_schema.sql`
4. `supabase/migrations/004_knowledge_schema.sql`
5. `supabase/migrations/005_rpc_functions.sql`

**OR** using Supabase CLI:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

---

## Step 4 — Storage buckets

In Supabase dashboard → **Storage**, create these buckets (all public):

| Bucket name          | Public |
|----------------------|--------|
| avatars              | ✅     |
| listing-images       | ✅     |
| verification-docs    | ❌     |
| course-media         | ✅     |
| knowledge-media      | ✅     |
| chat-media           | ✅     |

---

## Step 5 — Paystack

1. Sign up at https://paystack.com
2. Go to **Settings → API Keys & Webhooks**
3. Copy your **Public Key** and **Secret Key**
4. In `lib/core/constants/app_constants.dart`:
```dart
static const String paystackPublicKey = 'pk_live_...';
```
5. Add secret key to Supabase edge function secrets (see Step 7)

---

## Step 6 — Firebase (Push Notifications)

1. Go to https://console.firebase.google.com
2. Create a new project: **Agrotech Ghana**
3. Add Android app → package name: `com.agrotech.ghana`
4. Add iOS app → bundle ID: `com.agrotech.ghana`
5. Download `google-services.json` → place in `android/app/`
6. Download `GoogleService-Info.plist` → place in `ios/Runner/`

---

## Step 7 — Supabase Edge Functions

Deploy all edge functions:

```bash
supabase functions deploy verify-payment
supabase functions deploy release-escrow
supabase functions deploy process-consultation-payment
supabase functions deploy process-withdrawal
```

Set secrets:
```bash
supabase secrets set PAYSTACK_SECRET_KEY=sk_live_YOUR_KEY
supabase secrets set ARKESEL_API_KEY=YOUR_ARKESEL_KEY
```

---

## Step 8 — Arkesel SMS

1. Sign up at https://arkesel.com
2. Get your API key
3. In `lib/core/constants/app_constants.dart`:
```dart
static const String arkeselApiKey = 'YOUR_ARKESEL_KEY';
static const String arkeselSenderId = 'AgroGhana';
```
Note: Sender ID must be registered with Arkesel (takes 24-48h approval).

---

## Step 9 — Android configuration

In `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        applicationId "com.agrotech.ghana"
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

In `android/app/src/main/AndroidManifest.xml`, add:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

---

## Step 10 — iOS configuration

In `ios/Runner/Info.plist` add:
```xml
<key>NSCameraUsageDescription</key>
<string>Agrotech Ghana needs camera access for photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Agrotech Ghana needs photo library access</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Agrotech Ghana needs location for delivery</string>
```

---

## Step 11 — Run the app

```bash
# Android
flutter run -d android

# iOS (Mac only)
flutter run -d ios

# Web
flutter run -d chrome

# macOS (Mac only)
flutter run -d macos

# Windows
flutter run -d windows
```

---

## App Architecture Summary

```
lib/
├── core/
│   ├── constants/    → AppConstants (URLs, keys, routes)
│   ├── theme/        → AppColors, AppTextStyles, AppTheme
│   ├── router/       → GoRouter config
│   └── services/     → Supabase, Payments, Notifications
├── features/
│   ├── auth/         → Login, Register, Role Select, Verification
│   ├── home/         → Dashboard + bottom nav shell
│   ├── marketplace/  → Listings, Orders, Escrow
│   ├── consultation/ → Expert list, Profile, Chat room
│   ├── transport/    → Jobs, Bidding, Driver tracking
│   ├── knowledge/    → Articles, Forum, Courses
│   ├── wallet/       → Balance, Top-up, Withdraw, History
│   ├── profile/      → Edit profile, Settings, Logout
│   └── notifications/→ In-app notification list
└── shared/
    ├── models/       → All data models
    └── widgets/      → AppButton, AppTextField, AppAvatar, RoleBadge
```

---

## Key Features Built

| Feature | Status |
|---------|--------|
| Multi-role signup (8 roles) | ✅ |
| Supabase auth + user profiles | ✅ |
| Role-specific profile tables | ✅ |
| Marketplace with escrow | ✅ |
| 3-day auto-release + buyer confirm | ✅ |
| Expert consultations | ✅ |
| Free 10min/10msg threshold | ✅ |
| Per-session billing (5% cut) | ✅ |
| Transport job + bidding | ✅ |
| Knowledge hub (articles/forum/courses) | ✅ |
| Wallet (top-up + withdraw MoMo) | ✅ |
| Paystack integration | ✅ |
| Firebase push notifications | ✅ |
| Arkesel SMS | ✅ |
| In-app notifications | ✅ |
| Expert/business verification | ✅ |
| iOS, Android, Web, macOS, Windows | ✅ |
| Teal/Green brand theme | ✅ |
| Agrotech Ghana logo (SVG) | ✅ |

---

## Support

For issues with setup, check:
- Flutter: https://docs.flutter.dev
- Supabase: https://supabase.com/docs
- Paystack Ghana: https://paystack.com/gh/developers
- Arkesel: https://developers.arkesel.com
