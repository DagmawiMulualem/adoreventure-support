# Firebase Setup Guide for AdoreVenture

This guide will help you set up Firebase Authentication for your AdoreVenture iOS app.

## Prerequisites

- Xcode 16.1 or later
- iOS 18.1 or later
- A Firebase account

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter a project name (e.g., "AdoreVenture")
4. Choose whether to enable Google Analytics (optional)
5. Click "Create project"

## Step 2: Add iOS App to Firebase

1. In your Firebase project console, click the iOS icon (+ Add app)
2. Enter your app's bundle ID: `com.DagmawiMulualem.AdoreVenture`
3. Enter app nickname: "AdoreVenture"
4. Click "Register app"
5. Download the `GoogleService-Info.plist` file

## Step 3: Replace Configuration File

1. Replace the placeholder `GoogleService-Info.plist` file in your Xcode project with the downloaded one
2. Make sure the file is added to your app target

## Step 4: Add Firebase Dependencies

1. In Xcode, go to your project settings
2. Select your app target
3. Go to "Package Dependencies" tab
4. Click the "+" button to add a package
5. Enter the Firebase iOS SDK URL: `https://github.com/firebase/firebase-ios-sdk`
6. Select the following packages:
   - `FirebaseAuth`
   - `FirebaseCore`

## Step 5: Enable Authentication Methods

1. In Firebase Console, go to "Authentication" > "Sign-in method"
2. Enable "Email/Password" authentication
3. Optionally enable other methods like Google, Apple, etc.

## Step 6: Test the Integration

1. Build and run your app
2. Try creating a new account
3. Try signing in with existing credentials
4. Test the "Forgot Password" functionality

## Features Included

✅ **Email/Password Authentication**
- User registration
- User login
- Password reset via email
- Automatic session management

✅ **UI Features**
- Loading states during authentication
- Error handling and user feedback
- Consistent design with app theme
- Form validation

✅ **Security**
- Firebase handles all security aspects
- Password requirements enforced by Firebase
- Secure token management

## Troubleshooting

### Common Issues:

1. **"Firebase not configured" error**
   - Make sure `GoogleService-Info.plist` is properly added to your project
   - Verify the bundle ID matches your Firebase project

2. **Authentication fails**
   - Check that Email/Password authentication is enabled in Firebase Console
   - Verify your internet connection

3. **Password reset emails not received**
   - Check spam folder
   - Verify email address is correct
   - Check Firebase Console for any delivery issues

### Build Errors:

If you encounter build errors related to Firebase, make sure:
- All Firebase packages are properly added
- `GoogleService-Info.plist` is included in your app bundle
- You're using compatible versions of Firebase SDK

## Next Steps

Once Firebase is set up, you can:

1. **Add more authentication methods** (Google, Apple, Facebook, etc.)
2. **Implement user profiles** with Firestore
3. **Add data persistence** for user preferences
4. **Implement push notifications** with Firebase Cloud Messaging

## Support

For Firebase-specific issues, refer to:
- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Firebase Authentication Guide](https://firebase.google.com/docs/auth/ios/start)
- [Firebase Console](https://console.firebase.google.com/)

For app-specific issues, check the Xcode console for detailed error messages.
