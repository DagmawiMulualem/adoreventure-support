# Firestore Setup for Bookmarks

To enable the bookmark system, you need to set up Firestore in your Firebase project.

## Steps:

1. **Go to Firebase Console**
   - Visit [console.firebase.google.com](https://console.firebase.google.com)
   - Select your AdoreVenture project

2. **Enable Firestore Database**
   - In the left sidebar, click "Firestore Database"
   - Click "Create database"
   - Choose "Start in test mode" (for development)
   - Select a location (choose the closest to your users)
   - Click "Done"

3. **Security Rules (Optional but Recommended)**
   - In Firestore Database, go to "Rules" tab
   - Replace the default rules with:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Users can only access their own bookmarks
       match /users/{userId}/bookmarks/{bookmarkId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```
   - Click "Publish"

4. **Test the Bookmark System**
   - Run your app
   - Sign in with your account
   - Try bookmarking some activities
   - Check the "My Bookmarks" section

## How it Works:

- Each user has their own collection of bookmarks
- Bookmarks are stored in: `users/{userId}/bookmarks/{bookmarkId}`
- The system automatically syncs bookmarks across devices
- Bookmarks persist even after app restarts

## Data Structure:

Each bookmark document contains:
- `title`: Activity title
- `blurb`: Description
- `rating`: Star rating
- `place`: Location/venue
- `duration`: Time duration
- `priceRange`: Cost information
- `tags`: Activity tags
- `address`, `phone`, `website`, `bookingURL`, `bestTime`, `hours`: Additional details
- `bookmarkedAt`: Timestamp when bookmarked

The bookmark system is now ready to use! 🎉
