# PLATELY V2 — DEPLOY GUIDE
> One-time setup. After this, the backend runs 24/7 with zero maintenance.

---

## ARCHITECTURE (after deploy)
```
Users' phones → Flutter APK → Railway backend (always on) → PostgreSQL DB
                                     ↕
                              OpenRouter AI (free)
                              Firebase Auth (free)
```
You NEVER need to open your laptop for users to use the app.

---

## STEP 1 — Deploy backend to Railway

1. Go to https://railway.app → sign up (free)
2. Click "New Project" → "Deploy from GitHub repo"
3. Select `plately-v2` repo → set **Root Directory** to `backend`
4. Railway auto-detects `railway.json` — no config needed

### Set these environment variables in Railway dashboard:
| Variable | Value |
|----------|-------|
| `OPENROUTER_API_KEY` | your OpenRouter key from .env |
| `SECRET_KEY` | any long random string (e.g. run: `python -c "import secrets; print(secrets.token_hex(32))"`) |
| `FLASK_ENV` | `production` |
| `PORT` | `5000` |
| `ALLOWED_ORIGINS` | `*` for now, lock down later |

5. Click "Add Database" → "PostgreSQL" — Railway auto-sets `DATABASE_URL`
6. Deploy. Wait ~2 min. Click your service URL.
7. Visit `https://your-url.railway.app/api/health` — should return:
   ```json
   {"status": "ok", "service": "Plately API v2", "recipes": 34}
   ```

---

## STEP 2 — Build Flutter APK with production URL

Replace `YOUR_RAILWAY_URL` with your actual Railway URL:

```bash
cd plately-v2/frontend

# Debug build (for testing):
flutter run --dart-define=PLATELY_API_URL=https://YOUR_RAILWAY_URL.railway.app

# Release APK (for sharing):
flutter build apk --release --dart-define=PLATELY_API_URL=https://YOUR_RAILWAY_URL.railway.app

# APK location after build:
# build/app/outputs/flutter-apk/app-release.apk
```

Share `app-release.apk` with anyone — they install it and it works.

---

## STEP 3 — Keep-alive (already coded)

The app already pings `/api/health` every 9 minutes via `KeepAliveService`.
Railway free tier sleeps after 15 min — the 9-min ping prevents that.

**No UptimeRobot needed.** The app itself keeps the backend awake.

If you ALSO want UptimeRobot as a backup (when no one has the app open):
1. Go to https://uptimerobot.com → free account
2. Add monitor: HTTP(s) → URL: `https://YOUR_RAILWAY_URL.railway.app/api/health`
3. Interval: every 10 minutes
4. Done.

---

## STEP 4 — Signing the APK (for Play Store or reliable sharing)

```bash
# Generate keystore (one time only — save this file safely):
keytool -genkey -v -keystore plately-release.jks -keyalias plately -keyalg RSA -keysize 2048 -validity 10000

# Add to frontend/android/key.properties:
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=plately
storeFile=../plately-release.jks

# Build signed release APK:
flutter build apk --release --dart-define=PLATELY_API_URL=https://YOUR_RAILWAY_URL.railway.app
```

Add to `frontend/android/app/build.gradle` under `android {`:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

---

## WHAT EACH PERSON NEEDS TO DO

| Person | Action |
|--------|--------|
| Marco | Do Steps 1 (Railway deploy + set env vars) |
| Marc | Do Step 2 (build APK with Railway URL) + Step 4 (signing) |
| Adrian | Install APK, run full QA checklist, write BUGS.md |
| Landon | Verify AI endpoints work against live Railway URL |

---

## TROUBLESHOOTING

| Problem | Fix |
|---------|-----|
| `/api/health` returns 500 | Check Railway logs — probably missing env var |
| DB has 0 recipes | DATABASE_URL not set — Railway Postgres not linked |
| App can't connect | APK built without `--dart-define` — baseUrl is still localhost |
| Cold start slow (10-15s) | Normal on first request after sleep — KeepAliveService prevents this |
| Rate limit errors | User hitting >15 chat msgs/min — expected, not a bug |
