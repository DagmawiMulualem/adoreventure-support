# AdoreVenture Deployment Guide

## 🚀 Python Backend Deployment (Render.com)

### Step 1: Create GitHub Repository
1. Go to https://github.com/new
2. Create a new repository named `adoreventure-backend`
3. Make it public
4. Don't initialize with README

### Step 2: Push Backend Code to GitHub
```bash
cd backend
git remote add origin https://github.com/YOUR_USERNAME/adoreventure-backend.git
git branch -M main
git push -u origin main
```

### Step 3: Deploy to Render.com
1. Go to https://render.com
2. Sign up/Login with GitHub
3. Click "New +" → "Web Service"
4. Connect your GitHub repository
5. Configure:
   - **Name**: adoreventure-backend
   - **Environment**: Python
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app`
   - **Plan**: Free

### Step 4: Add Environment Variables
In Render dashboard, add these environment variables:
- `OPENAI_API_KEY`: YOUR_OPENAI_API_KEY
- `FLASK_ENV`: production

### Step 5: Update Firebase Functions
Once deployed, update the Firebase Functions with the backend URL:

```bash
npx firebase-tools functions:config:set python_backend.url="https://your-render-app.onrender.com"
npx firebase-tools deploy --only functions
```

## ✅ What's Already Done:
- ✅ Firebase Authentication (login, signup, password reset)
- ✅ Firebase Functions deployed
- ✅ iOS app updated to use Firebase Functions
- ✅ Python backend code ready

## 🔄 Next Steps:
1. Deploy Python backend to Render.com
2. Update Firebase Functions with backend URL
3. Test the complete integration
4. Add FirebaseFunctions dependency to iOS project

## 📱 iOS App Dependencies:
Make sure to add `FirebaseFunctions` to your Swift Package Manager dependencies in Xcode.
