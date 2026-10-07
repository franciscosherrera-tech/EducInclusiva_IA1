import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import 'auth_screen.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';
import 'psico_panel_screen.dart';
import 'teacher_panel_screen.dart'; // Importante

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startAppFlow();
  }

  Future<void> _startAppFlow() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    final prefs = await SharedPreferences.getInstance();
    final bool localOnboardingDone =
        prefs.getBool('onboarding_completed') ?? false;

    final session = Supabase.instance.client.auth.currentSession;
    final bool isLoggedIn = session != null;

    if (!mounted) return;

    Widget nextScreen;

    if (!isLoggedIn) {
      nextScreen =
          localOnboardingDone ? const AuthScreen() : const OnboardingScreen();
    } else {
      final userProvider = context.read<UserProvider>();
      await userProvider.loadFromSupabase();
      if (!mounted) return;

      final role = userProvider.role.toLowerCase();

      if (role == 'psicopedagoga') {
        nextScreen = const PsicoPanelScreen();
      } else if (role == 'docente') {
        nextScreen = const TeacherPanelScreen();
      } else if (!userProvider.onboardingCompleted) {
        nextScreen = const OnboardingScreen();
      } else {
        nextScreen = const MainNavigationScreen();
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
            ),
          ],
        ),
      ),
    );
  }
}
