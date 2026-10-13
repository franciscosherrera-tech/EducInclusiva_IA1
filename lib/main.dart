import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/accessibility_provider.dart';
import 'providers/new_content_provider.dart';
import 'providers/subject_provider.dart';
import 'providers/user_provider.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  // Notificaciones push (si Firebase no está configurado, la app sigue igual)
  await PushService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(create: (_) => NewContentProvider()),
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
          theme: AppTheme.light(activeColor),
          darkTheme: AppTheme.dark(
            activeColor,
            highContrast: accessibility.isHighContrast,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
