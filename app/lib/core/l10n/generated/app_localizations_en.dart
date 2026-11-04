// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tangent Smart Manager';

  @override
  String get appTagline => 'Manage · Track · Grow';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginButton => 'Log in';

  @override
  String get loginEmailRequired => 'Email is required';

  @override
  String get loginEmailInvalid => 'Enter a valid email';

  @override
  String get loginPasswordRequired => 'Password is required';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get mfaPrompt => 'Enter the 6-digit code from your authenticator app';

  @override
  String get mfaVerifyButton => 'Verify';

  @override
  String get mfaBackToLogin => 'Back to login';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navHouseholdAccounts => 'Household Accounts';

  @override
  String get navMyRecords => 'My Records';

  @override
  String get navGoatFarm => 'Goat Farm';

  @override
  String get navLandRecords => 'Land Records';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navContacts => 'Customers & Suppliers';

  @override
  String get navAccounts => 'Bank & Accounts';

  @override
  String get navReports => 'Reports & Analytics';

  @override
  String get navAiAssistant => 'AI Assistant';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAdminConsole => 'Admin Console';

  @override
  String get searchHint => 'Search anything...';

  @override
  String get openMenu => 'Open menu';

  @override
  String get logOut => 'Log out';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsSecuritySection => 'Multi-factor authentication';

  @override
  String get settingsSessionsSection => 'Active sessions';

  @override
  String get notBuiltYet => 'This module is not built yet.';

  @override
  String get createWorkspaceTitle => 'Create your workspace';

  @override
  String get createWorkspaceSubtitle =>
      'A workspace holds your accounts, farm, and land records. You can invite others to it later.';

  @override
  String get createWorkspaceNameLabel => 'Workspace name';

  @override
  String get createWorkspaceButton => 'Create workspace';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'Confirm';

  @override
  String get enable => 'Enable';

  @override
  String get disable => 'Disable';

  @override
  String get revoke => 'Revoke';

  @override
  String get refresh => 'Refresh';
}
