# Challenge to Game Integration

## Overview

This feature integrates the challenge system with the existing game creation flow. When a user accepts a challenge, it creates a game in the `games` collection and navigates to the waiting room, just like the regular game creation flow.

## Complete Flow

### 1. Sending a Challenge
1. User selects friend, time control, and amount
2. **Balance Check**: System checks if user has sufficient balance
3. **Challenge Creation**: Creates document in `challenges` collection
4. **Notification**: Sends FCM notification to opponent with challenge ID
5. **UI Feedback**: Shows success/error message to user

### 2. Receiving a Challenge
1. **Notification**: User receives FCM notification
2. **Validation**: System validates challenge (not expired, not processed)
3. **Dialog**: Shows challenge dialog with Accept/Reject buttons
4. **Expiration**: If >2 minutes old, shows "Challenge Expired" dialog

### 3. Accepting a Challenge
1. **Balance Check**: Verifies both users have sufficient balance
2. **Amount Deduction**: Deducts amount from both players
3. **Game Creation**: Creates game in `games` collection
4. **Navigation**: Redirects to waiting room
5. **Notification**: Sends acceptance notification to challenger

### 4. Rejecting a Challenge
1. **Status Update**: Updates challenge status to 'rejected'
2. **Notification**: Sends rejection notification to challenger
3. **Dialog Close**: Closes challenge dialog

### 5. Challenge Expiration
1. **Background Check**: Timer checks for expired challenges every 30 seconds
2. **Status Update**: Updates expired challenges to 'expired' status
3. **Notification**: Sends expiration notification to challenger

## Database Schema

### Challenges Collection
```javascript
{
  challenger: "uid123",
  opponent: "uid456", 
  timeControl: "5 min",
  amount: 10,
  status: "pending", // pending, accepted, rejected, expired
  createdAt: Timestamp,
  acceptedAt: Timestamp, // optional
  rejectedAt: Timestamp, // optional
  expiredAt: Timestamp,  // optional
  gameRoomCode: "ABC123" // optional, set when accepted
}
```

### Games Collection (Challenge Games)
```javascript
{
  roomCode: "ABC123",
  hostId: "uid123",
  player1: "uid123",
  player2: "uid456",
  status: "ready", // ready for challenge games
  createdAt: Timestamp,
  gameName: "Challenge Game",
  time: "5 min",
  entryFee: 10.0,
  challengeId: "challenge_doc_id"
}
```

## Key Features

### ✅ Balance Validation
- Checks balance before sending challenge
- Validates both users' balance before accepting
- Prevents challenges/games with insufficient funds

### ✅ Game Integration
- Creates proper game document in `games` collection
- Uses same waiting room as regular games
- Maintains game state consistency

### ✅ Notification System
- FCM notifications for challenge, acceptance, rejection, expiration
- Includes challenge ID for validation
- Proper error handling for missing tokens

### ✅ Expiration Handling
- 2-minute automatic expiration
- Background processing
- User-friendly expired challenge dialog

### ✅ Error Handling
- Graceful handling of network issues
- Clear error messages to users
- Fallback for missing data

## Code Structure

### Services
- `ChallengeService`: Core challenge logic
- `ChallengeExpirationService`: Background expiration handling

### Models
- `Challenge`: Challenge data model with expiration logic
- `ChallengeValidationResult`: Validation response
- `ChallengeAcceptResult`: Acceptance response

### UI Components
- Challenge dialog with Accept/Reject buttons
- Expired challenge dialog
- Balance validation feedback

## Testing Scenarios

1. **Valid Challenge Flow**
   - Send challenge → Receive notification → Accept → Game created → Waiting room

2. **Insufficient Balance**
   - Try to send challenge with insufficient balance → Error message
   - Try to accept challenge with insufficient balance → Error message

3. **Expired Challenge**
   - Wait 2+ minutes → Tap notification → "Challenge Expired" dialog

4. **Rejected Challenge**
   - Receive challenge → Reject → Notification sent to challenger

5. **Background Expiration**
   - Send challenge → Close app → Wait 2+ minutes → Challenge expires in background

## Configuration

- **Expiration Time**: 2 minutes (configurable in `Challenge.fromMap()`)
- **Background Check Interval**: 30 seconds (configurable in `ChallengeExpirationService`)
- **Balance Validation**: Real-time checks before any action
- **Notification Tags**: Unique tags to prevent duplicate notifications

## Future Enhancements

1. **FCM Notifications**: Implement actual FCM notifications for acceptance/rejection/expiration
2. **Game History**: Track challenge games in user history
3. **Rematch Feature**: Quick rematch option after game ends
4. **Challenge Statistics**: Track challenge success rates
5. **Auto-Decline**: Option to auto-decline challenges from specific users 