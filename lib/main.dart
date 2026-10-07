import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/accessibility_provider.dart';
import 'providers/subject_provider.dart';
import 'providers/user_provider.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AccessibilityProvider>(
      builder: (context, accessibility, child) {
        final activeColor = accessibility.activePrimaryColor;

        return MaterialApp(
          title: 'Tutor IA Accesible',
          debugShowCheckedModeBanner: false,

          themeMode: accessibility.isHighContrast
              ? ThemeMode.dark
              : accessibility.themeMode,

          // --- TEMA CLARO ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: activeColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: activeColor,
              primary: activeColor,
              brightness: Brightness.light,
              surface: AppColors.background,
            ),
            scaffoldBackgroundColor: AppColors.background,
            cardTheme: const CardThemeData(
              color: Colors.white,
              elevation: 1,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: activeColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),

          // --- TEMA OSCURO Y ALTO CONTRASTE ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: activeColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: activeColor,
              primary: activeColor,
              brightness: Brightness.dark,
              surface: accessibility.isHighContrast
                  ? Colors.black
                  : const Color(0xFF1E232A),
            ),
            scaffoldBackgroundColor: accessibility.isHighContrast
                ? Colors.black
                : const Color(0xFF14171D),
            cardTheme: CardThemeData(
              color: accessibility.isHighContrast
                  ? Colors.grey.shade900
                  : const Color(0xFF222831),
              elevation: 2,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: accessibility.isHighContrast
                  ? Colors.black
                  : const Color(0xFF1E232A),
              foregroundColor: accessibility.isHighContrast
                  ? Colors.yellowAccent
                  : Colors.white,
              elevation: 0,
            ),
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}
