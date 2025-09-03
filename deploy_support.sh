#!/bin/bash

echo "🚀 Deploying AdoreVenture Support Page to Render..."

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "📁 Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit: AdoreVenture Support Page"
fi

# Check if remote exists
if ! git remote get-url origin > /dev/null 2>&1; then
    echo "🔗 Please add your Render git remote:"
    echo "git remote add origin https://git.render.com/your-repo-url.git"
    echo ""
    echo "Then run: git push -u origin main"
else
    echo "📤 Pushing to Render..."
    git add .
    git commit -m "Update support page"
    git push
fi

echo ""
echo "✅ Deployment complete!"
echo "🌐 Your support page will be available at:"
echo "   https://adoreventure-support.onrender.com"
echo ""
echo "📝 Use this URL in App Store Connect as your Support URL"
