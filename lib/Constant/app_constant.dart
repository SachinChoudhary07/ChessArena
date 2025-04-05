class AppConstants {
  // Icons
  static const String splashIcon = 'assets/Icons/splash_Icon.png';

  // Images
  static const String loginSignupImage = 'assets/images/lose.png';
  static const String googleImage = 'assets/images/google.png';
  static const String loaderImage = 'assets/images/king.png';

  // App Info
  static const String appName = 'Chess4Cash';

  // Authentication Texts
  static const String google = 'Continue with Google';
  static const String login = 'Login';
  static const String register = 'Register';
  static const String userName = 'Username';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String ageConfirmation = '18 years old ?';
  static const String alreadyAccount = 'Already have an account? Login';
  static const String dontHaveAccount = 'Don\'t have an account? Register';

  // Dashboard Text
  static const String home = 'Home';
  static const String addMoney = 'Add Money';
  static const String withdraw = 'Withdraw';
  static const String playFreeMatch = 'Play Free Match';
  static const String joinPaidContest = 'Join Paid Contest';
  static const String tournaments = 'Tournaments';
  static const String createContest = 'Create Contest';

  //Profile Text
  static const String profile = 'Profile';
  static const String updateProfile = 'Update Profile';
  static const String logout = 'Logout';
  static const String confirmLogout = 'Confirm Logout';
  static const String sureLogOut = 'Are you sure you want to logout?';
  static const String cancel = 'Cancel';
  static const String inviteFriends = 'Invite Friends';
  static const String deleteAccount = 'Delete Account';

  //Wallet screen text
  static const String totalBalance = 'Total Balance';
  static const String viewTransaction = 'Transaction History';
  static const String addCash = 'Add Cash';
  static const String wallet = 'Wallet';
  static const String cashExpiringSoon = 'Cash expiring soon';

  //Game History Text
  static const String history = 'History';
  static const String upcoming = 'Upcoming';
  static const String completed = 'Completed';

  //Join Contest Text
  static const String joinContest = 'Join Contest';

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
  static const String balanceField = 'Balance';

  // Security & Admin Control Fields
  static const String isBannedField = 'isBanned';
  static const String isVerifiedField = 'isVerified';
  static const String banReasonField = 'banReason';
  static const String suspiciousFlagField = 'suspiciousFlag';
}
