# Subscription System Test Guide

## 🧪 **Testing Premium Subscription System**

The subscription system includes test functionality to simulate premium upgrades without actual StoreKit integration.

## 🎯 **Test Features Available:**

### **1. Test Upgrade Button (SubscriptionPromptView)**
- **Location**: Upgrade prompt that appears when search limit is reached
- **Button**: "Upgrade Now (Test)" - Green button
- **Function**: Simulates successful premium purchase

### **2. Toggle Test Button (User Menu)**
- **Location**: User menu (profile button) → "Toggle Subscription (Test)"
- **Function**: Toggles between free and premium status

## 🧪 **How to Test:**

### **Step 1: Test Search Limits**
1. **Start with Free Account** (default)
2. **Search for ideas** 2 times
3. **Expected**: Search limit should be reached
4. **Expected Console**: `💳 Subscription: Search recorded - 2/2`

### **Step 2: Test Upgrade Prompt**
1. **Try to search again** after reaching limit
2. **Expected**: Upgrade prompt should appear
3. **Click "Upgrade Now (Test)"**
4. **Expected Console**:
   ```
   💳 Subscription: 🧪 Simulating successful purchase for testing
   💳 Subscription: ✅ Test purchase completed successfully
   💳 Subscription: User now has unlimited searches
   ```

### **Step 3: Verify Premium Status**
1. **Check user menu** - should show "Premium Member ✨"
2. **Search limit message** should change to "Unlimited searches with your subscription! ✨"
3. **Try searching** - should work without limits

### **Step 4: Test Toggle Function**
1. **Go to user menu** → "Toggle Subscription (Test)"
2. **Expected**: Status should toggle between free/premium
3. **Check search limit message** - should update accordingly

## 🔍 **Expected Console Output:**

### **Free User (First 2 Searches):**
```
💳 Subscription: Search recorded - 1/2
💳 Subscription: Search recorded - 2/2
```

### **Search Limit Reached:**
```
💳 Subscription: Search limit reached. Please upgrade to Premium for unlimited searches.
```

### **Test Upgrade:**
```
💳 Subscription: 🧪 Simulating successful purchase for testing
💳 Subscription: ✅ Status updated - true
💳 Subscription: ✅ Test purchase completed successfully
💳 Subscription: User now has unlimited searches
```

### **Premium User Searches:**
```
💳 Subscription: Search recorded - 3/2 (unlimited)
💳 Subscription: Search recorded - 4/2 (unlimited)
```

## 📱 **UI Indicators:**

### **Free User:**
- **User Menu**: Shows search limit message
- **Search Limit**: "2 of 2 free searches remaining today"
- **Upgrade Button**: Available in user menu

### **Premium User:**
- **User Menu**: Shows "Premium Member ✨"
- **Search Limit**: "Unlimited searches with your subscription! ✨"
- **No Limits**: Can search unlimited times

## 🚨 **Troubleshooting:**

### **If Upgrade Not Working:**
1. **Check Console**: Look for error messages
2. **Verify User Auth**: Ensure user is logged in
3. **Check Firestore**: Verify user document is created
4. **Restart App**: Sometimes needed for UI updates

### **If Search Limits Not Working:**
1. **Check Local Storage**: UserDefaults might be cached
2. **Verify Date**: Daily limits reset at midnight
3. **Check Console**: Look for subscription errors

### **If UI Not Updating:**
1. **Force Refresh**: Close and reopen app
2. **Check MainActor**: Ensure UI updates on main thread
3. **Verify Environment**: Check SubscriptionManager is properly injected

## 🎯 **Test Scenarios:**

### **Scenario 1: Complete Flow**
1. Start free → Use 2 searches → Hit limit → Upgrade → Unlimited searches

### **Scenario 2: Toggle Testing**
1. Free → Toggle to Premium → Toggle back to Free → Verify limits

### **Scenario 3: Persistence**
1. Upgrade to Premium → Close app → Reopen → Should still be Premium

### **Scenario 4: Daily Reset**
1. Use 1 search → Wait for next day → Should reset to 2/2

## ✅ **Success Criteria:**

### **✅ Upgrade Working:**
- [ ] "Upgrade Now (Test)" button works
- [ ] User status changes to Premium
- [ ] Unlimited searches available
- [ ] UI updates correctly

### **✅ Toggle Working:**
- [ ] "Toggle Subscription (Test)" works
- [ ] Status toggles between free/premium
- [ ] Search limits update accordingly

### **✅ Persistence Working:**
- [ ] Status survives app restart
- [ ] Search counts persist
- [ ] Daily limits reset properly

### **✅ UI Updates:**
- [ ] User menu shows correct status
- [ ] Search limit messages update
- [ ] Upgrade prompts appear when needed

## 🔧 **Production Notes:**

### **Before Production:**
1. **Remove Test Buttons**: Delete "Upgrade Now (Test)" and "Toggle Subscription (Test)"
2. **Implement StoreKit**: Replace test methods with real StoreKit integration
3. **Add Receipt Validation**: Verify purchases with App Store
4. **Add Analytics**: Track conversion rates

### **Current Test Implementation:**
- ✅ Simulates successful purchases
- ✅ Updates user status in Firestore
- ✅ Persists across app restarts
- ✅ Updates UI correctly
- ✅ Handles search limits properly

The subscription system should now work perfectly for testing! 🎯
