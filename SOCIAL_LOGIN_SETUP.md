# Social Login Setup Guide

## Overview
This guide will help you set up Google and Apple Sign-In for your AdoreVenture app.

## Prerequisites

### 1. Firebase Configuration
- Ensure you have `GoogleService-Info.plist` in your Xcode project
- Enable Google and Apple Sign-In in Firebase Console

### 2. Xcode Dependencies
Add these packages to your Xcode project:

#### Google Sign-In
1. In Xcode, go to **File > Add Package Dependencies**
2. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
3. Select version: `7.0.0` or latest
4. Add to your main app target

#### Apple Sign-In
- Apple Sign-In is built into iOS, no additional packages needed

## Firebase Console Setup

### 1. Enable Authentication Methods

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (`adoreventure`)
3. Go to **Authentication > Sign-in method**
4. Enable the following providers:

#### Google Sign-In
1. Click on **Google** provider
2. Enable it
3. Add your support email
4. Save

#### Apple Sign-In
1. Click on **Apple** provider
2. Enable it
3. Add your Apple Developer Team ID
4. Add your Apple Service ID
5. Save

### 2. Configure OAuth Consent Screen (Google)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Go to **APIs & Services > OAuth consent screen**
4. Configure the consent screen:
   - App name: `AdoreVenture`
   - User support email: Your email
   - Developer contact information: Your email
5. Add scopes:
   - `email`
   - `profile`
   - `openid`

## Xcode Project Configuration

### 1. Info.plist Configuration

Add these entries to your `Info.plist`:

```xml
<!-- Google Sign-In -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>

<!-- Apple Sign-In -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>appleid</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_APPLE_SERVICE_ID</string>
        </array>
    </dict>
</array>
```

### 2. Replace Placeholder Values

- `YOUR_REVERSED_CLIENT_ID`: Found in `GoogleService-Info.plist` under `REVERSED_CLIENT_ID`
- `YOUR_APPLE_SERVICE_ID`: Your Apple Service ID (e.g., `com.yourcompany.adoreventure.signin`)

### 3. Capabilities

Enable these capabilities in Xcode:

1. Select your project in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add:
   - **Sign in with Apple**
   - **Keychain Sharing** (if not already present)

## Apple Developer Console Setup

### 1. Create Apple Service ID

1. Go to [Apple Developer Console](https://developer.apple.com)
2. Go to **Certificates, Identifiers & Profiles**
3. Click **Identifiers**
4. Click **+** to create new identifier
5. Select **Services IDs**
6. Configure:
   - Description: `AdoreVenture Sign-In`
   - Identifier: `com.yourcompany.adoreventure.signin`
   - Enable **Sign In with Apple**
7. Save

### 2. Configure App ID

1. Go to your App ID (e.g., `com.yourcompany.adoreventure`)
2. Enable **Sign In with Apple**
3. Save

## Testing

### 1. Test Google Sign-In
1. Build and run the app
2. Tap "Continue with Google"
3. Should open Google Sign-In sheet
4. Complete sign-in process

### 2. Test Apple Sign-In
1. Build and run the app
2. Tap "Continue with Apple"
3. Should open Apple Sign-In sheet
4. Complete sign-in process

## Troubleshooting

### Common Issues

1. **"Unable to present sign-in view"**
   - Check that `GoogleService-Info.plist` is in your project
   - Verify `REVERSED_CLIENT_ID` in Info.plist

2. **"Failed to get ID token from Google"**
   - Check Firebase Console Google provider is enabled
   - Verify OAuth consent screen is configured

3. **"Failed to get Apple ID token"**
   - Check Apple Developer Console configuration
   - Verify Sign in with Apple capability is enabled

4. **Build Errors**
   - Ensure Google Sign-In package is properly added
   - Check that all imports are correct

### Debug Steps

1. Check console logs for detailed error messages
2. Verify all configuration files are in place
3. Test on a physical device (simulator may have limitations)
4. Ensure you're signed into iCloud on the test device

## Security Notes

- Never commit `GoogleService-Info.plist` to public repositories
- Use environment variables for sensitive configuration
- Implement proper error handling for production
- Consider implementing nonce validation for Apple Sign-In

## Next Steps

After setup is complete:

1. Test both sign-in methods thoroughly
2. Implement proper error handling
3. Add loading states and user feedback
4. Consider implementing sign-out functionality
5. Add user profile management
