import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/services/db_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/rewards_provider.dart';
import 'providers/ai_tutor_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/parent_provider.dart';
import 'features/auth/screens/parent_child_setup_screen.dart';
import 'features/parent/screens/link_child_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/dashboard/screens/learner_dashboard.dart';
import 'features/dashboard/screens/parent_dashboard.dart';
import 'features/dashboard/screens/teacher_dashboard.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ParentProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => RewardsProvider()),
        ChangeNotifierProvider(create: (_) => AiTutorProvider()),
        ChangeNotifierProvider(
            create: (_) => ConnectivityProvider()),
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
      title: 'QuestKids',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/parent_child_setup': (_) => const ParentChildSetupScreen(),
        '/link_child': (_) => const LinkChildScreen(),
        '/dashboard': (_) => const LearnerDashboard(),
        '/dashboard/learner': (_) => const LearnerDashboard(),
        '/dashboard/parent': (_) => const ParentDashboard(),
        '/dashboard/teacher': (_) => const TeacherDashboard(),
        '/splash': (_) => const SplashScreen(),
      },
    );
  }
}
