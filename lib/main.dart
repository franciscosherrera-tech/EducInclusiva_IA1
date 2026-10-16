import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

/// Permite mostrar avisos desde fuera del árbol de pantallas.
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<RemoteMessage>? _foregroundSub;

  @override
  void initState() {
    super.initState();
    // Con la app abierta Android no dibuja la notificación: la mostramos acá
    _foregroundSub =
        PushService.instance.onForegroundMessage.listen(_showForegroundNotice);
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    super.dispose();
  }

  void _showForegroundNotice(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final text = [n.title, n.body].whereType<String>().join('\n');
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccessibilityProvider>(
      builder: (context, accessibility, child) {
        final activeColor = accessibility.activePrimaryColor;

        return MaterialApp(
          title: 'Tutor IA Accesible',
          scaffoldMessengerKey: messengerKey,
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
