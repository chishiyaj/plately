# FIREBASE APP DISTRIBUTION — Plately Setup Guide

> Zero-cost APK distribution for testers and early users.
> No Play Store. No developer fee. Just a link.

---

## Prerequisites

- Node.js installed (`node -v` to check)
- Firebase project already created (you have `google-services.json` ✅)
- Release APK built at `build/app/outputs/flutter-apk/app-release.apk`

---

## Step 1 — Install Firebase CLI

```bash
npm install -g firebase-tools
```

Verify: `firebase --version`

---

## Step 2 — Log in

```bash
firebase login
```

Opens a browser. Sign in with the Google account that owns your Firebase project.

---

## Step 3 — Get your Firebase App ID

Open `frontend/android/app/google-services.json` and look for:

```json
{
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:XXXXXXXXXXXX:android:YYYYYYYYYYYYYYYY"
      }
    }
  ]
}
```

The `mobilesdk_app_id` value is your **Firebase App ID**. Copy it.

---

## Step 4 — Add tester emails

**Firebase Console (easiest):**
1. Firebase Console → your project → App Distribution → Testers & Groups
2. Click **"Add testers"** → paste emails (one per line)
3. Create a group called `testers`

**Or via CLI:**
```bash
firebase appdistribution:testers:add \
  --app 1:XXXXXXXXXXXX:android:YYYYYYYYYYYYYYYY \
  teammate@example.com
```

---

## Step 5 — Distribute the APK

Build first:
```bash
flutter build apk --release \
  --dart-define=PLATELY_API_URL=https://plately-r1xp.onrender.com
```

Then distribute:
```bash
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:XXXXXXXXXXXX:android:YYYYYYYYYYYYYYYY \
  --groups "testers" \
  --release-notes "Session 30 build — 100 recipes, offline mode, streak share cards, peso pricing"
```

Testers get an email with a direct install link. No Play Store needed.

---

## Step 6 — GitHub Action (auto-distribute on every push to main)

The workflow file is already at `.github/workflows/distribute.yml` ✅

### Add these secrets to GitHub

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret name | Value |
|-------------|-------|
| `FIREBASE_APP_ID` | Your `mobilesdk_app_id` from google-services.json |
| `FIREBASE_TOKEN` | Run `firebase login:ci` locally → copy the token |
| `PLATELY_API_URL` | `https://plately-r1xp.onrender.com` |
| `KEYSTORE_BASE64` | Run: `base64 -w 0 frontend/android/upload-keystore.jks` → paste output |
| `KEY_ALIAS` | `plately` |
| `KEY_PASSWORD` | your keystore password |
| `STORE_PASSWORD` | your keystore password |

> Never commit `key.properties` or `upload-keystore.jks` to git.

---

## Step 7 — Landing Page (GitHub Pages)

The landing page is at `plately-landing/index.html` ✅

To deploy free on GitHub Pages:
1. GitHub repo → **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: `main`, folder: `/plately-landing`
4. Save → your page is live at `https://chishiyaj.github.io/plately/`

All `YOUR_ORG` placeholders have already been replaced with `chishiyaj` in all files.

---

## Tester experience

1. Tester receives email: *"[Name] has invited you to test Plately"*
2. They install the **Firebase App Distribution** companion app (one-time, ~2MB)
3. Download and install Plately APK directly
4. Every new build auto-notifies them

---

## Update Checker

`update_service.dart` reads `version.json` from your GitHub raw URL.

`version.json` is at repo root and already configured for `chishiyaj/plately`.
Update it with each release:
```json
{
  "latest_version": "1.2.0",
  "download_url": "https://github.com/chishiyaj/plately/releases/latest/download/app-release.apk",
  "message": "New recipes dropped. Update now fr."
}
```

`UpdateService.currentVersion` is already set to `1.2.0` in `update_service.dart`.
`UpdateService._versionUrl` already points to `https://raw.githubusercontent.com/chishiyaj/plately/main/version.json`.

---

## Quick reference

```bash
# Build
flutter build apk --release --dart-define=PLATELY_API_URL=https://plately-r1xp.onrender.com

# Distribute
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_FIREBASE_APP_ID \
  --groups "testers" \
  --release-notes "describe what changed"

# Tag the release
git tag v1.2.0 && git push --tags
```

---

*Last updated: Session 30 — chishiyaj/plately*
