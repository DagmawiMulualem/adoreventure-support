#!/bin/bash

echo "🚀 AdoreVenture Backend Deployment Script"
echo "=========================================="

# Check if we're in the right directory
if [ ! -d "backend" ]; then
    echo "❌ Error: backend directory not found. Please run this script from the project root."
    exit 1
fi

echo "📁 Setting up backend for deployment..."

cd backend

# Initialize git if not already done
if [ ! -d ".git" ]; then
    echo "🔧 Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit for deployment"
fi

echo "✅ Backend is ready for deployment!"
echo ""
echo "📋 Next steps:"
echo "1. Create a GitHub repository at: https://github.com/new"
echo "   - Name: adoreventure-backend"
echo "   - Make it public"
echo "   - Don't initialize with README"
echo ""
echo "2. Run these commands (replace YOUR_USERNAME with your GitHub username):"
echo "   git remote add origin https://github.com/YOUR_USERNAME/adoreventure-backend.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Deploy to Render.com:"
echo "   - Go to https://render.com"
echo "   - Sign up/Login with GitHub"
echo "   - Click 'New +' → 'Web Service'"
echo "   - Connect your GitHub repository"
echo "   - Configure:"
echo "     * Name: adoreventure-backend"
echo "     * Environment: Python"
echo "     * Build Command: pip install -r requirements.txt"
echo "     * Start Command: gunicorn app:app"
echo "     * Plan: Free"
echo ""
echo "4. Add environment variables in Render:"
echo "   - OPENAI_API_KEY: (set in Render dashboard — do not commit real keys)"
echo "   - FLASK_ENV: production"
echo ""
echo "5. Once deployed, update Firebase Functions:"
echo "   npx firebase-tools functions:config:set python_backend.url='https://your-render-app.onrender.com'"
echo "   npx firebase-tools deploy --only functions"
echo ""
echo "🎉 Your backend will be ready!"
