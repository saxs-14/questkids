import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
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
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/profile/screens/settings_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/dashboard/screens/learner_dashboard.dart';
import 'features/dashboard/screens/parent_dashboard.dart';
import 'features/dashboard/screens/teacher_dashboard.dart';

/// Shared between AuthProvider (to show a foreground push banner from a
/// stream listener with no local BuildContext) and MaterialApp itself.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLocalDatabase();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
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
        '/dashboard': (_) => const LearnerDashboard(),
        '/dashboard/learner': (_) => const LearnerDashboard(),
        '/dashboard/parent': (_) => const ParentDashboard(),
        '/dashboard/teacher': (_) => const TeacherDashboard(),
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
