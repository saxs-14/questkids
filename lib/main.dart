import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'features/auth/screens/parent_child_setup_screen.dart';
import 'features/parent/screens/link_child_screen.dart';
import 'features/parent/screens/link_requests_screen.dart';
import 'features/parent/screens/document_vault_screen.dart';
import 'features/parent/screens/mood_checkin_screen.dart';
import 'features/parent/screens/messages_list_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/profile/screens/settings_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/dashboard/screens/learner_dashboard.dart';
import 'features/dashboard/screens/grade4_activities_hub_screen.dart';
import 'features/dashboard/screens/parent_dashboard.dart';
import 'features/dashboard/screens/teacher_dashboard.dart';
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

  // Debug providers only for now -- functions/src/config.ts's
  // ENFORCE_APP_CHECK stays false until Play Integrity (Android)/App
  // Attest (iOS)/reCAPTCHA v3 (Web) are configured in the Firebase
  // Console and this is swapped to the release providers. Activating
  // App Check even in debug mode is still useful: it starts attaching
  // (unenforced) tokens to requests now, so switching providers later
  // doesn't require touching this call site again.
  //
  // Web is skipped entirely rather than activated with no webProvider --
  // FirebaseAppCheck.instance.activate() on web hangs indefinitely
  // without a ReCaptchaV3Provider site key (live-verified: it blocks
  // main() before runApp() ever fires, producing a permanent blank
  // white screen with no console error). Re-enable for web once a real
  // reCAPTCHA v3 site key exists in the Firebase Console.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
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
        '/messages': (_) => const MessagesListScreen(),
        '/dashboard': (_) => const LearnerDashboard(),
        '/dashboard/learner': (_) => const LearnerDashboard(),
        '/grade4_hub': (_) => const Grade4ActivitiesHubScreen(),
        '/dashboard/parent': (_) => const ParentDashboard(),
        '/dashboard/teacher': (_) => const TeacherDashboard(),
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
