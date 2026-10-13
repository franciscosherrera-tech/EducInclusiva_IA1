// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/push_service.dart';

class UserProvider extends ChangeNotifier {
  static const String _defaultName = 'Usuario Inclusivo';
  static const String _defaultRole = 'Estudiante';

  String _name = _defaultName;
  String _email = '';
  String _profileImagePath = '';
  String _role = _defaultRole;
  bool _onboardingCompleted = false;
  // Curso asignado por la psicopedagoga (ej. "1°" + "2da")
  String _year = '';
  String _division = '';

  String get name => _name;
  String get year => _year;
  String get division => _division;
  bool get hasCourse => _year.isNotEmpty && _division.isNotEmpty;
  String get email => _email;
  String get profileImagePath => _profileImagePath;
  String get role => _role;
  String get userRole => _role; // Alias para compatibilidad
  bool get onboardingCompleted => _onboardingCompleted;

  SupabaseClient get _supabase => Supabase.instance.client;

  UserProvider() {
    _loadUserData();
    // Si FCM renueva el token del teléfono, lo volvemos a guardar
    PushService.instance.onTokenRefresh.listen(_saveFcmToken);
  }

  /// Guarda el token de este teléfono en profiles.fcm_token para que el
  /// servidor pueda enviarle notificaciones. Se llama al iniciar sesión.
  Future<void> syncPushToken() async {
    final token = await PushService.instance.getToken();
    if (token != null) await _saveFcmToken(token);
  }

  Future<void> _saveFcmToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', user.id);
    } catch (e) {
      debugPrint('No se pudo guardar el token de notificaciones: $e');
    }
  }

  /// Carga primero la caché local y luego sincroniza con Supabase.
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('user_name') ?? _defaultName;
    _email = prefs.getString('user_email') ?? '';
    _profileImagePath = prefs.getString('user_photo') ?? '';
    _role = prefs.getString('user_role') ?? _defaultRole;
    _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    _year = prefs.getString('user_year') ?? '';
    _division = prefs.getString('user_division') ?? '';
    notifyListeners();

    if (_supabase.auth.currentUser != null) {
      await loadFromSupabase();
    }
  }

  /// Trae los datos del perfil desde la base de datos Supabase.
  Future<void> loadFromSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      _email = user.email ?? '';

      final dbName = data?['name'] as String?;
      _name = (dbName != null && dbName.isNotEmpty) ? dbName : _defaultName;

      _profileImagePath = (data?['photo_url'] as String?) ?? '';
      _role = (data?['role'] as String?) ?? _role;
      _onboardingCompleted = (data?['onboarding_completed'] as bool?) ?? false;
      _year = (data?['year'] as String?) ?? '';
      _division = (data?['division'] as String?) ?? '';

      await _saveCache();
    } catch (e) {
      debugPrint('Error al cargar el perfil: $e');
      _email = user.email ?? _email;
    }
    notifyListeners();
    syncPushToken();
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _name);
    await prefs.setString('user_email', _email);
    await prefs.setString('user_photo', _profileImagePath);
    await prefs.setString('user_role', _role);
    await prefs.setBool('onboarding_completed', _onboardingCompleted);
    await prefs.setString('user_year', _year);
    await prefs.setString('user_division', _division);
  }

  Future<void> setRole(String newRole) async {
    _role = newRole;
    notifyListeners();
    await _saveCache();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'role': newRole}).eq('id', user.id);
      } catch (e) {
        debugPrint('Error al actualizar el rol: $e');
      }
    }
  }

  /// Setea el rol seleccionado en el onboarding y lo guarda en Supabase
  Future<void> setRoleAndCompleteOnboarding(String selectedRole) async {
    _role = selectedRole;
    _onboardingCompleted = true;
    notifyListeners();
    await _saveCache();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'name': _name,
          'email': _email,
          'role': selectedRole,
          'onboarding_completed': true,
        });
      } catch (e) {
        debugPrint('Error al completar el onboarding en Supabase: $e');
      }
    }
  }

  Future<void> updateName(String newName) async {
    _name = newName;
    notifyListeners();
    await _saveCache();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'name': newName}).eq('id', user.id);
      } catch (e) {
        debugPrint('Error al actualizar el nombre: $e');
      }
    }
  }

  Future<void> updateEmail(String newEmail) async {
    _email = newEmail;
    notifyListeners();
    await _saveCache();
  }

  Future<void> updateProfileImage(String path) async {
    _profileImagePath = path;
    notifyListeners();
    await _saveCache();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'photo_url': path}).eq('id', user.id);
      } catch (e) {
        debugPrint('Error al actualizar la foto: $e');
      }
    }
  }

  /// Cierra la sesión y limpia la caché local.
  Future<void> signOut() async {
    // Este teléfono deja de recibir avisos de la cuenta que se cierra
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'fcm_token': null}).eq('id', user.id);
      } catch (_) {}
    }
    await PushService.instance.deleteToken();

    await _supabase.auth.signOut();

    _name = _defaultName;
    _email = '';
    _profileImagePath = '';
    _role = _defaultRole;
    _onboardingCompleted = false;
    _year = '';
    _division = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_photo');
    await prefs.remove('user_role');
    await prefs.remove('onboarding_completed');
    await prefs.remove('user_year');
    await prefs.remove('user_division');

    notifyListeners();
  }

  Widget getDefaultAvatar({required double radius, required Color color}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: radius,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
