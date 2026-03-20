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
