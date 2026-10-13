import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Se ejecuta cuando llega una notificación con la app cerrada o en segundo
/// plano. Tiene que ser una función de nivel superior (no un método).
/// Los mensajes con "notification" los muestra el sistema solo; acá no hace
/// falta dibujar nada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Notificación en segundo plano: ${message.messageId}');
}

/// Notificaciones push con Firebase Cloud Messaging (FCM).
///
/// Si Firebase todavía no está configurado en el proyecto (falta
/// google-services.json), la app sigue funcionando igual, sin notificaciones.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _available = false;
  bool get isAvailable => _available;

  final _tokenRefresh = StreamController<String>.broadcast();

  /// Avisa cuando FCM cambia el token del teléfono (hay que volver a guardarlo).
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  /// Mensajes que llegan con la app abierta (no se muestran como notificación).
  final _foreground = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage => _foreground.stream;

  /// Inicia Firebase, pide el permiso y deja escuchando los mensajes.
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      // Android 13+ muestra el cuadro de permiso; en versiones anteriores
      // las notificaciones ya están permitidas.
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      messaging.onTokenRefresh.listen(_tokenRefresh.add);
      FirebaseMessaging.onMessage.listen(_foreground.add);

      _available = true;
    } catch (e) {
      debugPrint('Notificaciones desactivadas (Firebase sin configurar): $e');
    }
  }

  /// Token del teléfono, o null si las notificaciones no están disponibles.
  Future<String?> getToken() async {
    if (!_available) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('No se pudo obtener el token FCM: $e');
      return null;
    }
  }

  /// Borra el token de este teléfono (al cerrar sesión).
  Future<void> deleteToken() async {
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
