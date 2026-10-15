# FCM Push Notifications - Testing Guide

## ✅ What's Implemented

### Backend Setup Required
1. **Token Storage** - `/users/fcm-token` endpoint to save FCM tokens
2. **Push Sending** - Backend can send notifications to stored tokens

### Mobile Features
- ✅ FCM initialization on app startup
- ✅ Request notification permissions (Android 13+)
- ✅ Get FCM token automatically
- ✅ Send token to backend: `POST /users/fcm-token`
- ✅ Refresh token when it changes
- ✅ Foreground notifications (in-app banner)
- ✅ Lock screen notifications
- ✅ Notification tap routing to correct screens

## 🧪 Testing Checklist

### 1. Verify Token is Saved
```bash
# Check if user has FCM token
curl -X GET https://your-backend/api/v1/auth/me \
  -H "Authorization: Bearer $TOKEN"

# Response should include:
{
  "id": "user-id",
  "fcmToken": "eUm5X9...",
  "email": "user@example.com"
}
```

### 2. Test Foreground Notification (App Open)
**Step 1:** Open the app and keep it active
**Step 2:** Send test notification from backend:
```bash
curl -X POST https://your-backend/api/v1/test/send-notification \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-id",
    "title": "Chat Message",
    "body": "You have a new message",
    "type": "chat",
    "threadId": "thread-123"
  }'
```
**Expected:** Yellow banner appears at top of screen → auto-dismisses in 5 seconds

### 3. Test Background Notification (App Closed)
**Step 1:** Close the app completely (not backgrounded)
**Step 2:** Send same notification from backend
**Step 3:** Check notification center/lock screen
**Expected:** Notification appears on lock screen with sound/vibration

### 4. Test Notification Tap Routing

#### Test Chat Navigation
```bash
curl -X POST https://your-backend/api/v1/test/send-notification \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "userId": "user-id",
    "title": "New Chat",
    "body": "You have a new message",
    "type": "chat",
    "threadId": "thread-abc123"
  }'
```
**Action:** Tap notification
**Expected:** App opens → Navigate to chat screen with threadId "thread-abc123"

#### Test Deal Navigation
```bash
curl -X POST https://your-backend/api/v1/test/send-notification \
  -d '{
    "userId": "user-id",
    "title": "Deal Update",
    "body": "Deal terms updated",
    "type": "deal",
    "interestId": "interest-xyz789"
  }'
```
**Action:** Tap notification
**Expected:** App opens → Navigate to `/deals/interest-xyz789`

#### Test Proposal Navigation
```bash
curl -X POST https://your-backend/api/v1/test/send-notification \
  -d '{
    "userId": "user-id",
    "title": "Proposal Response",
    "body": "Your proposal was approved",
    "type": "proposal",
    "interestId": "proposal-456"
  }'
```
**Action:** Tap notification
**Expected:** App opens → Navigate to `/proposals/proposal-456`

#### Test Support Navigation
```bash
curl -X POST https://your-backend/api/v1/test/send-notification \
  -d '{
    "userId": "user-id",
    "title": "Support Response",
    "body": "Meetday support replied",
    "type": "support"
  }'
```
**Action:** Tap notification
**Expected:** App opens → Navigate to support chat screen

### 5. Token Refresh Test
**Step 1:** Get initial token: Check logs for `FCM Token: eUm5X...`
**Step 2:** Reinstall app (clears Firebase cache)
**Step 3:** New token generated
**Step 4:** Check backend - new token saved to user record
**Expected:** Token in `GET /auth/me` changed

## 📱 Supported Notification Types

| Type | Route | Use Case |
|------|-------|----------|
| `chat` | `/chat/{threadId}` | Hub chat messages |
| `sponsorship_chat` | `/chat/{threadId}` | Sponsorship chat |
| `space_chat` | `/chat/{threadId}` | Space partnership chat |
| `community_chat` | `/chat/{threadId}` | Community collaboration |
| `brand_community_chat` | `/chat/{threadId}` | Brand-community chat |
| `deal` | `/deals/{interestId}` | Deal updates |
| `sponsorship_deal` | `/deals/{interestId}` | Sponsorship deal |
| `space_deal` | `/deals/{interestId}` | Space deal |
| `proposal` | `/proposals/{interestId}` | Proposal responses |
| `sponsorship_proposal` | `/proposals/{interestId}` | Sponsorship proposal |
| `support` | `/support` | Support responses |
| `campaign` | `/campaigns/{campaignId}` | Campaign updates |

## 🔍 Debugging

### Check Notification Logs
```bash
# iOS
xcrun simctl log parse

# Android
adb logcat | grep FCM
```

### Verify Token Sent to Backend
Check server logs for:
```
FCM token sent to backend
POST /users/fcm-token { fcmToken: "..." }
```

### Check Notification Handler
Look for logs:
```
Foreground message: Chat Message
Notification tap: Chat Message
Navigating to: chat with data: {...}
Navigated to chat: thread-123
```

## 🚀 Production Checklist

Before deploying:
- [ ] `/users/fcm-token` endpoint implemented
- [ ] Push notification endpoint implemented
- [ ] Tested on Android 13+ device
- [ ] Tested on iOS 14+ device
- [ ] Tested with real notifications (not just test endpoint)
- [ ] Token refresh works after app reinstall
- [ ] Notification routing navigates correctly
- [ ] No console errors when receiving notifications
- [ ] Background notifications have sound/vibration
- [ ] Foreground banner dismisses correctly

## 📝 Payload Format (Backend)

When sending notifications, use this format:

```json
{
  "userId": "firebase-uid",
  "title": "Notification Title",
  "body": "Notification message body",
  "type": "chat|deal|proposal|support|campaign",
  "threadId": "optional-for-chat-types",
  "interestId": "optional-for-deal-proposal-types",
  "campaignId": "optional-for-campaign-type"
}
```

The app will automatically:
1. Show notification on lock screen
2. Show in-app banner if app is open
3. Route to correct screen when tapped
4. Pass data to the screen component

## ✅ Implementation Status

- ✅ FCM service initialized
- ✅ Permissions requested
- ✅ Token obtained and sent to backend
- ✅ Foreground notifications with banner
- ✅ Background notifications (lock screen)
- ✅ Notification tap routing
- ✅ All chat types supported
- ✅ Deal/Proposal/Support/Campaign routing
- ✅ Token refresh on device change
- ⏳ Production testing (awaiting backend notification endpoint)
