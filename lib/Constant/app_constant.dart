class AppConstants {
  // Icons
  static const String splashIcon = 'assets/Icons/splash_Icon.png';

  // Images
  static const String loginSignupImage = 'assets/images/lose.png';
  static const String googleImage = 'assets/images/google.png';

  // App Info
  static const String appName = 'Chess4Cash';

  // Authentication Texts
  static const String google = 'Continue with Google';
  static const String login = 'Login';
  static const String register = 'Register';
  static const String userName = 'Username';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String ageConfirmation =
      'I confirm that I am at least 18 years old.';
  static const String alreadyAccount = 'Already have an account? Login';
  static const String dontHaveAccount = 'Don\'t have an account? Register';

  // Dashboard Text
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

  // Firestore Collections & Fields
  static const String usersCollection = 'users';
  static const String uidField = 'uid';
  static const String emailField = 'email';
  static const String usernameField = 'username';
  static const String createdAtField = 'createdAt';
}
