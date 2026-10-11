import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/config/emulator_config.dart';
import 'core/services/analytics_service.dart';
import 'core/services/db_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/app_error_view.dart';
import 'providers/auth_provider.dart';
import 'providers/rewards_provider.dart';
import 'providers/ai_tutor_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/mission_provider.dart';
import 'providers/parent_provider.dart';
import 'providers/quiz_provider.dart';
import 'features/auth/screens/parent_child_setup_screen.dart';
import 'features/parent/screens/link_child_screen.dart';
import 'features/parent/screens/link_requests_screen.dart';
import 'features/parent/screens/document_vault_screen.dart';
import 'features/parent/screens/mood_checkin_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/profile/screens/settings_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/dashboard/screens/learner_dashboard.dart';
import 'features/games/core/grade_four_game_levels_screen.dart';
import 'features/dashboard/screens/parent_dashboard.dart';
import 'features/dashboard/screens/admin_dashboard.dart';
import 'features/rewards/screens/trading_post_screen.dart';

/// Shared between AuthProvider (to show a foreground push banner from a
/// stream listener with no local BuildContext) and MaterialApp itself.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLocalDatabase();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Point every Firebase service at the local emulator suite instead of
  // production, for local dev/testing only -- must run before any other
  // Firebase call. See core/config/emulator_config.dart: this same
  // connection must also be applied to any secondary FirebaseApp instance
  // created later (e.g. auth_service.dart's temp apps for child-account
  // registration), not just this default app.
  await connectToEmulatorsIfEnabled(Firebase.app());

  // Route every uncaught Flutter framework error to Crashlytics instead of
  // just printing to the console, so crashes are visible after launch.
  // firebase_crashlytics has no web implementation (its pubspec declares
  // only android/ios/macos) -- calling it unguarded on web throws from
  // inside the error handler itself, silently swallowing whatever error
  // it was trying to report instead of surfacing it anywhere (not even
  // the browser console). Guard both handlers with kIsWeb so errors on
  // web still reach FlutterError.presentError / are left uncaught (both
  // of which do reach the console), rather than vanishing.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };
  // Catches errors outside the Flutter framework's own error zone (e.g.
  // from a Future that isn't awaited) that FlutterError.onError misses.
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kIsWeb) return false;
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // functions/src/config.ts's ENFORCE_APP_CHECK stays false until this is
  // verified end-to-end on a real release build -- but a release build
  // now gets the REAL attestation providers (Play Integrity / App Attest),
  // not debug tokens. A debug token is only valid for devices manually
  // registered in the Firebase Console, which doesn't scale to real
  // users, so shipping a release build with the debug provider would
  // make App Check permanently unenforceable for production traffic even
  // after this flag flips. Activating App Check even while
  // ENFORCE_APP_CHECK is false is still useful: it starts attaching
  // (unenforced) tokens to requests now, so enabling enforcement later
  // doesn't require a new client release.
  //
  // Web stays skipped: a real reCAPTCHA Enterprise key now exists
  // (6LfYiektAAAAAGeLoLViV8E9p2TMV6rdBGNUFzce, registered against this
  // web app's App Check config), but activating with it still hangs
  // main() before runApp() fires -- live-verified 2026-10-11 via a real
  // (non-headless) Chrome instance driven over the DevTools Protocol:
  // main() starts, network reachability to
  // https://www.google.com/recaptcha/enterprise.js is confirmed fine
  // (200 OK), yet the page never progresses past that and the title
  // never updates, even after 60+ seconds. Root cause not yet isolated
  // (possibly a domain-validation or grecaptcha.enterprise.ready() quirk
  // specific to this integration) -- do not re-enable for web without
  // debugging this further with real DevTools Network/JS-stack
  // inspection, not just reachability checks.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider:
          kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
    );
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(navigatorKey: navigatorKey)),
        ChangeNotifierProvider(create: (_) => ParentProvider()),
        ChangeNotifierProvider(create: (_) => RewardsProvider()),
        ChangeNotifierProvider(create: (_) => AiTutorProvider()),
        ChangeNotifierProvider(create: (_) => MissionProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ConnectivityProvider>(
          create: (_) => ConnectivityProvider(),
          update: (_, auth, connectivity) {
            connectivity!.setUid(auth.user?.uid);
            return connectivity;
          },
        ),
      ],
      child: const QuestKidsApp(),
    ),
  );
}

class QuestKidsApp extends StatelessWidget {
  const QuestKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [AnalyticsService.observer],
      title: 'QuestKids',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return AnimatedTheme(
          data: themeProvider.isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          duration: const Duration(milliseconds: 300),
          child: child!,
        );
      },
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot_password': (_) => const ForgotPasswordScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/edit_profile': (_) => Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final user = auth.user;
                return EditProfileScreen(
                  initialName: user?.name ?? '',
                  initialSurname: user?.surname ?? '',
                  initialGrade: user?.grade ?? 'Grade 1',
                  initialLanguage: user?.preferredLanguage ?? 'English',
                );
              },
            ),
        '/parent_child_setup': (_) => const ParentChildSetupScreen(),
        '/link_child': (_) => const LinkChildScreen(),
        '/link_requests': (_) => const LinkRequestsScreen(),
        '/document_vault': (_) => const DocumentVaultScreen(),
        '/mood_checkin': (_) => const MoodCheckinScreen(),
        '/dashboard': (_) => const LearnerDashboard(),
        '/dashboard/learner': (_) => const LearnerDashboard(),
        '/grade4_hub': (_) => Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final user = auth.user;
                if (user == null) return const LoginScreen();
                return GradeFourGameLevelsScreen(user: user);
              },
            ),
        '/dashboard/parent': (_) => const ParentDashboard(),
        '/dashboard/admin': (_) => const AdminDashboard(),
        '/trading_post': (_) => const TradingPostScreen(),
        '/splash': (_) => const SplashScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: AppErrorView(
            message: "We couldn't find that page.",
            onRetry: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            ),
          ),
        ),
      ),
    );
  }
}
