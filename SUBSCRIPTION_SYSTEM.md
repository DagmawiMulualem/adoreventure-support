# Subscription System Implementation

## Overview
The AdoreVenture app now includes a subscription system that limits free users to 2 searches per day, with unlimited searches available through a premium subscription.

## Features

### Free Tier
- **2 free searches per day**
- Search count resets at midnight
- Access to basic AI-generated adventure ideas
- Bookmark functionality

### Premium Tier
- **Unlimited searches**
- Enhanced AI suggestions
- Priority support
- All free features included

## Implementation Details

### Core Components

1. **SubscriptionManager.swift**
   - Manages subscription status and search limits
   - Tracks daily search usage in Firestore
   - Handles subscription status updates
   - Provides helper methods for UI

2. **SubscriptionPromptView.swift**
   - Beautiful subscription upgrade prompt
   - Shows when users reach their daily limit
   - Displays premium features and pricing
   - Includes purchase flow (placeholder for StoreKit)

3. **Integration Points**
   - `AIIdeasService.swift`: Checks limits before API calls
   - `IdeasListView.swift`: Shows subscription prompt on limit reached
   - `RootView.swift`: Displays subscription status
   - `FirebaseManager.swift`: Includes subscription manager

### Database Schema

Users collection in Firestore includes:
```json
{
  "users": {
    "userId": {
      "isSubscribed": boolean,
      "subscriptionDate": timestamp,
      "dailySearchesUsed": number,
      "lastSearchDate": timestamp
    }
  }
}
```

### Search Flow

1. User initiates search
2. `AIIdeasService.fetchIdeas()` checks `subscriptionManager.canPerformSearch()`
3. If limit reached, throws error with code -3
4. `IdeasListView` catches error and shows subscription prompt
5. If search allowed, records search with `subscriptionManager.recordSearch()`

### UI Indicators

- **Main Screen**: Shows search count remaining
- **User Menu**: Displays subscription status
- **Ideas List**: Shows search limit message
- **Subscription Prompt**: Appears when limit reached

## Testing

### Test Button
A temporary test button is available in the user menu to toggle subscription status for testing purposes. This should be removed before production.

### Manual Testing
1. Perform 2 searches as a free user
3. Verify subscription prompt appears on 3rd search
4. Use test button to enable premium
5. Verify unlimited searches work
6. Test daily reset functionality

## Future Enhancements

### StoreKit Integration
- Implement actual in-app purchases
- Add product loading and purchase flow
- Handle receipt validation
- Add restore purchases functionality

### Analytics
- Track subscription conversion rates
- Monitor search usage patterns
- A/B test pricing and messaging

### Advanced Features
- Family sharing support
- Promotional offers
- Referral system
- Premium content exclusives

## Configuration

### Daily Search Limit
Change `dailySearchesLimit` in `SubscriptionManager.swift`:
```swift
@Published var dailySearchesLimit = 2  // Adjust as needed
```

### Pricing
Update pricing in `SubscriptionPromptView.swift`:
```swift
PricingCard(title: "Monthly", price: "$4.99", period: "per month")
PricingCard(title: "Annual", price: "$39.99", period: "per year", savings: "Save 33%")
```

## Security Considerations

- Search limits are enforced server-side in Firebase Functions
- Subscription status is verified on each search
- User data is protected with Firebase Auth
- No sensitive payment data stored locally

## Deployment Notes

1. Ensure Firestore rules allow user document updates
2. Test subscription flow in sandbox environment
3. Verify daily reset works across time zones
4. Monitor Firebase usage for cost optimization
