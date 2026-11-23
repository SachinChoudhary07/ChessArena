class AppConstants {
  // Icons
  static const String splashIcon = 'assets/Icons/splash_Icon.png';

  // Images
  static const String loginSignupImage = 'assets/images/lose.png';
  static const String googleImage = 'assets/images/google.png';
  static const String loaderImage = 'assets/images/king.png';
  static const String defaultProfileImage = 'assets/images/pawn_image.jpg';

  // App Info
  static const String appName = 'ChessArena';
  static const String appMotto = 'Play free. Climb your Elo.';

  // Authentication Texts
  static const String google = 'Continue with Google';
  static const String login = 'Login';
  static const String register = 'Register';
  static const String userName = 'Username';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String ageConfirmation = 'I am 18+ years old.';
  static const String alreadyAccount = 'Already have an account? Login';
  static const String dontHaveAccount = 'Don\'t have an account? Register';
  static const String privacyPolicy =
      'By creating an account, I agree to the Terms & Conditions and Privacy Policy outlined here.';

  // Dashboard Text
  static const String home = 'Home';
  static const String playFreeMatch = 'Play Free Match';
  static const String tournaments = 'Tournaments';
  static const String playWithFriends = 'Play With Friends';
  static const String playWithOnlineFriends = 'Play With Online Friends';

  //Profile Text
  static const String profile = 'Profile';
  static const String updateProfile = 'Update Profile';
  static const String logout = 'Logout';
  static const String confirmLogout = 'Confirm Logout';
  static const String sureLogOut = 'Are you sure you want to logout?';
  static const String cancel = 'Cancel';
  static const String inviteFriends = 'Invite Friends';
  static const String deleteAccount = 'Delete Account';

  //Game History Text
  static const String history = 'History';
  static const String upcoming = 'Upcoming';
  static const String completed = 'Completed';

  // Matchmaking Text
  static const String waitingText =
      'Looking for opponents with similar skills as you...';
  static const String you = 'You';

  // Success Messages
  static const String registrationSuccess = 'Registration successful';
  static const String loginSuccess = 'Login successful';
  static const String logoutSuccess = 'Logged out successfully';

  // Error Messages
  static const String emailAlreadyInUse = 'This email is already registered';
  static const String invalidEmail = 'Invalid email format';
  static const String weakPassword = 'Password is too weak';
  static const String userNotFound = 'No user found with this email';
  static const String wrongPassword = 'Incorrect password';
  static const String authFailed = 'Authentication failed';
  static const String unexpectedError = 'An unexpected error occurred';

  // Collection Names
  static const String usersCollection = 'users';

  // User Profile Fields
  static const String uidField = 'uid';
  static const String emailField = 'email';
  static const String usernameField = 'username';
  static const String profileImageField = 'profileImage';
  static const String createdAtField = 'createdAt';
  static const String deviceInfoField = 'deviceInfo';
  static const String fcmTokenField = 'fcmToken';

  // Chess & Game-Related Fields
  static const String eloRatingField = 'eloRating';
  static const String gamesPlayedField = 'gamesPlayed';
  static const String gamesWonField = 'gamesWon';
  static const String gamesLostField = 'gamesLost';
  static const String gamesDrawnField = 'gamesDrawn';
  static const String rankingField = 'ranking';

  // Security & Admin Control Fields
  static const String isBannedField = 'isBanned';
  static const String isVerifiedField = 'isVerified';
  static const String banReasonField = 'banReason';
  static const String suspiciousFlagField = 'suspiciousFlag';

  //Game
  static const String custom = 'Custom';

  static const String uid = 'uid';
  static const String name = 'name';
  static const String image = 'image';
  static const String createdAt = 'createdAt';

  static const String userImages = 'userImages';
  static const String users = 'users';

  static const String userModel = 'userModel';
  static const String isSinedIn = 'isSinedIn';
  static const String playerRating = 'playerRating';
  static const String gameCreatorRating = 'gameCreatorRating';
  static const String userRating = 'userRating';

  static const String availableGames = 'availableGames';
  static const String photoUrl = 'photoUrl';
  static const String gameCreatorUid = 'gameCreatorUid';
  static const String gameCreatorName = 'gameCreatorName';
  static const String gameCreatorImage = 'gameCreatorImage';
  static const String isPlaying = 'isPlaying';
  static const String gameId = 'gameId';
  static const String dateCreated = 'dateCreated';
  static const String whitesTime = 'whitesTime';
  static const String blacksTime = 'blacksTime';

  static const String userId = 'userId';
  static const String positonFen = 'positonFen';
  static const String winnerId = 'winnerId';
  static const String whitsCurrentMove = 'whitsCurrentMove';
  static const String blacksCurrentMove = 'blacksCurrentMove';
  static const String boardState = 'boardState';
  static const String playState = 'playState';
  static const String isWhitesTurn = 'isWhitesTurn';
  static const String isGameOver = 'isGameOver';
  static const String squareState = 'squareState';
  static const String moves = 'moves';

  static const String runningGames = 'runningGames';
  static const String game = 'game';

  static const String userImage = 'userImage';
  static const String gameScore = 'gameScore';

  static const String searchingPlayerText =
      'Searching for player, please wait...';
  static const String joiningGameText = 'Joining game, please wait...';
}

enum GameDifficulty {
  easy,
  medium,
  hard,
}

enum PlayerColor {
  white,
  black,
}

class UCICommands {
  static const String isReady = 'isready';
  static const String goMoveTime = 'go movetime';
  static const String goInfinite = 'go infinite';
  static const String stop = 'stop';
  static const String position = 'position fen';
  static const String bestMove = 'bestmove';
}
