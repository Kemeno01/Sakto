# Sakto

A budgeting, expense list, and bill-splitting app built with Flutter (Philippine Peso `₱`).

---

## Download (Android)

Download the latest `Sakto.apk` directly from [**GitHub Releases**](https://github.com/Kemeno01/Sakto/releases).

**How to install on your phone:**
1. Download `Sakto.apk` from the latest Release on GitHub.
2. Open the downloaded `Sakto.apk` file on your Android device.
3. If prompted, enable **Allow from this source / Install from unknown sources**, then tap **Install**.

---

## What It Does

- **Home:** Set your cash on hand, track how much you've spent, save multiple lists per day, and edit or backdate expenses on the calendar.
- **Lists:** Group items into tags, set per-tag budgets, search/sort/bulk-check items, and reuse tag templates.
- **Split:** Split equally or per item with saved friends, apply ₱/% discounts, 20% SC/PWD VAT-exempt discounts, or service charges, track Cash/GCash payments and change, and copy formatted summaries with your GCash/Maya details.
- **Scan Receipt (`+` button):** Snap or pick a receipt photo to extract items, discounts, and fees automatically.
- **Analytics:** View Expenses and categorized Income over time with bar and donut charts.
- **Offline or Google Sign-In:** Start offline, upgrade to Google with automatic data migration, export CSV, or back up/restore JSON.

---

## Developer Setup

### 1. Run Locally

```bash
git clone https://github.com/Kemeno01/Sakto.git
cd Sakto
flutter pub get
```

For local receipt scanning without deploying the Edge Function, create a `secrets.json` in the project root (ignored by git):

```json
{
  "GEMINI_API_KEY": "your-api-key-here"
}
```

Then run:

```bash
flutter run --dart-define-from-file=secrets.json
```

### 2. Supabase Database & Edge Functions (Recommended for Production)

1. Run [`supabase/schema.sql`](supabase/schema.sql) in your Supabase **SQL Editor** to create `profiles`, `user_data`, and Row-Level Security (RLS) policies.
2. Deploy the server-side receipt scanner Edge Function so your `GEMINI_API_KEY` is never bundled into the APK:
   ```bash
   supabase secrets set GEMINI_API_KEY="your-gemini-key"
   supabase functions deploy scan-receipt
   ```
3. Deploy the in-app account deletion Edge Function (for Play Store / App Store compliance):
   ```bash
   supabase functions deploy delete-account
   ```

### 3. Signed Release Builds (Android)

1. Generate an upload keystore (keep it private; ignored by git):
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy [`android/key.properties.example`](android/key.properties.example) to `android/key.properties` and fill in your keystore credentials.
3. Build a signed release APK or App Bundle using the server-side Edge scanner (no API key embedded in the binary):
   ```bash
   flutter build apk --release --dart-define=USE_EDGE_SCANNER=true
   flutter build appbundle --release --dart-define=USE_EDGE_SCANNER=true
   ```
4. Upload the generated APK from `build/app/outputs/flutter-apk/app-release.apk` to **GitHub Releases**.
