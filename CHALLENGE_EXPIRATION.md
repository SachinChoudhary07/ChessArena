# Challenge Expiration Feature

## Overview

This feature implements automatic expiration of chess challenges after 2 minutes. When a user sends a challenge to an opponent, the challenge will automatically expire if the opponent doesn't respond within 2 minutes.

## Implementation Details

### 1. Challenge Model (`lib/Screens/PlayWithOnlineFriends/play_with_online_friend_provider.dart`)

- Added `Challenge` class with expiration logic
- Each challenge has a `createdAt` timestamp and calculated `expiresAt` time (2 minutes later)
- `isExpired` getter checks if current time is after expiration time

### 2. Challenge Service (`lib/Services/challenge_service.dart`)

- `validateChallenge()`: Validates if a challenge is still valid
- `acceptChallenge()`: Accepts a valid challenge
- `rejectChallenge()`: Rejects a valid challenge
- All methods check expiration before processing

### 3. Challenge Expiration Service (`lib/Services/challenge_expiration_service.dart`)

- Background timer that runs every 30 seconds
- Automatically updates expired challenges in Firestore
- Uses batch operations for efficiency

### 4. Updated Notification Handling (`lib/main.dart`)

- Extracts challenge ID from FCM notification data
- Validates challenge before showing dialog
- Shows different dialogs for valid vs expired challenges

## User Experience

### Valid Challenge
- User receives notification
- Taps notification or app is opened
- Challenge dialog appears with Accept/Reject buttons
- User can respond within 2 minutes

### Expired Challenge
- User receives notification
- Taps notification after 2+ minutes
- "Challenge Expired" dialog appears
- Only "OK" button to dismiss

### Background Expiration
- Challenges automatically marked as expired in database
- No user interaction required
- Prevents accepting expired challenges

## Database Schema

```javascript
// challenges collection
{
  challenger: "uid123",
  opponent: "uid456", 
  timeControl: "5 min",
  amount: 10,
  status: "pending", // pending, accepted, rejected, expired
  createdAt: Timestamp,
  acceptedAt: Timestamp, // optional
  rejectedAt: Timestamp, // optional
  expiredAt: Timestamp   // optional
}
```

## FCM Notification Payload

```javascript
{
  "message": {
    "token": "fcm_token",
    "notification": {
      "title": "New Chess Challenge!",
      "body": "Player challenged you to a 5 min game for ₹10."
    },
    "data": {
      "type": "challenge",
      "challengerUid": "uid123",
      "challengeId": "challenge_doc_id"
    }
  }
}
```

## Testing Scenarios

1. **Immediate Response**: User responds within 2 minutes - challenge accepted/rejected
2. **Late Response**: User responds after 2 minutes - "Challenge Expired" shown
3. **Background Expiration**: App closed, challenge expires in background
4. **Multiple Notifications**: Only latest challenge dialog shown
5. **Network Issues**: Graceful handling of validation errors

## Configuration

- Expiration time: 2 minutes (configurable in `Challenge.fromMap()`)
- Background check interval: 30 seconds (configurable in `ChallengeExpirationService`)
- FCM notification includes challenge ID for validation 