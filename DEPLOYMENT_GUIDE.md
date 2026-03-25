# AdoreVenture Deployment Guide

## Repositories (read this first)

See **`BACKEND_REPOS.md`** for what belongs in **support** vs **`adoreventure-backend-clean`**.

- **Render (Python API)** → **`https://github.com/DagmawiMulualem/adoreventure-backend-clean`**
- **Firebase Functions + static support site** → **`adoreventure-support`** (this repo)

---

## Python backend (Render)

### Source of truth

All Flask code lives in **`backend/`** in this repo (`app.py`, `Dockerfile`, `requirements.txt`).

### Deploy / push to Render’s GitHub

From the **project root**:

```bash
./push_backend_render.sh
```

This splits the `backend/` folder and pushes to **`adoreventure-backend-clean`** `main`, which triggers Render.

Prerequisites (one-time):

```bash
git remote add backend-clean https://github.com/DagmawiMulualem/adoreventure-backend-clean.git
```

### Environment variables (Render dashboard)

- `OPENAI_API_KEY` — do not commit
- `FLASK_ENV`: `production`

### Point Firebase Functions at Render

After the service URL is live:

```bash
npx firebase-tools functions:config:set python_backend.url="https://adoreventure-backend-clean.onrender.com"
npx firebase-tools deploy --only functions
```

### Idea callables (Gen2 + min instances)

`getIdeas` and `getSingleIdea` are deployed as **Cloud Functions 2nd gen** with **`minInstances: 1`** each so Firebase keeps one warm instance per function (reduces cold starts; **Blaze** billing applies).

- **Deploy:** `npx firebase-tools deploy --only functions --force` (`--force` is required when `minInstances` increases minimum billing).
- **Region** is set in `functions/index.js` as `IDEA_CALL_GEN2.region` (default `us-central1`).
- **1st gen → 2nd gen (same name):** delete old functions first, e.g.  
  `npx firebase-tools functions:delete getIdeas getSingleIdea --region us-central1 --force`
- **Gen2 runtime config:** v2 cannot call `functions.config()` at startup; the code uses `getRuntimeConfig()` (reads `CLOUD_RUNTIME_CONFIG` from legacy `functions:config:set`). Plan migration to `.env` / secrets before March 2026 per Firebase’s deprecation notice.
- **Gen2 callable IAM:** idea callables set `invoker: 'public'` so Cloud Run accepts HTTP traffic; Firebase Auth is still enforced via `request.auth` in the handler. Without this, the iOS client often gets `UNAUTHENTICATED` (Functions error 16).
- **`.firebaserc`** must list a real default project id (e.g. `"default": "adoreventure"`), not a mistaken string key.

---

## Static support site (optional)

`render.yaml` in this repo can deploy a **static** service (`support.html`) named `adoreventure-support`. That is **separate** from the Python API.

---

## What’s already in place

- Firebase Authentication, Functions (`functions/index.js`)
- iOS app uses Firebase callable functions → Python backend URL
- Backend code under **`backend/`** only

---

## iOS

Ensure **`FirebaseFunctions`** is included in Swift Package Manager in Xcode.
