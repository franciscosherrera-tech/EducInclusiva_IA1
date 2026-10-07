import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/accessibility_provider.dart';
import '../providers/user_provider.dart';
import '../services/psico_auth.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';
import 'psico_panel_screen.dart';
import 'settings_screen.dart';
import 'teacher_panel_screen.dart'; // Importante

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Ingresa un correo electrónico válido.');
      return;
    }
    if (password.length < 6) {
      _showMessage('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (!_isLogin && name.isEmpty) {
      _showMessage('Ingresa tu nombre completo.');
      return;
    }

    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'name': name},
        );

        if (res.session == null) {
          _showMessage(
            'Revisa tu correo para confirmar tu cuenta y luego inicia sesión.',
          );
          if (mounted) setState(() => _isLogin = true);
          return;
        }
      }

      if (!mounted) return;

      // Sincronizar datos del usuario con el Provider
      final userProvider = context.read<UserProvider>();
      await userProvider.loadFromSupabase();

      if (!mounted) return;

      final role = userProvider.role.toLowerCase();

      // Psicopedagoga
      if (role == 'psicopedagoga') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PsicoPanelScreen()),
        );
        return;
      }

      // Docente / Profesor
      if (role == 'docente') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherPanelScreen()),
        );
        return;
      }

      // Alumno / Referente
      if (!userProvider.onboardingCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage(
        'Ocurrió un error. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = accessibility.isHighContrast
        ? Colors.black
        : Theme.of(context).scaffoldBackgroundColor;
    final textColor = accessibility.isHighContrast
        ? Colors.yellowAccent
        : (isDark ? Colors.white : Colors.black87);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.accessibility_new, color: primaryColor, size: 32),
            tooltip: 'Ajustes de Accesibilidad',
            onPressed: () async {
              final ok = await PsicoAuth.showDialogGate(context);
              if (ok && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school,
                  size: 80,
                  color: primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'EducInclusiva IA',
                  style: accessibility.getTextStyle(
                    overrideSize: accessibility.fontSize * 1.5,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Inicia sesión para continuar'
                      : 'Crea tu cuenta inclusiva',
                  style: accessibility.getTextStyle(
                    overrideSize: accessibility.fontSize * 0.9,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!_isLogin) ...[
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nombre Completo',
                    icon: Icons.person,
                    accessibility: accessibility,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextField(
                  controller: _emailController,
                  label: 'Correo Electrónico',
                  icon: Icons.email,
                  accessibility: accessibility,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  icon: Icons.lock,
                  isPassword: true,
                  accessibility: accessibility,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accessibility.isHighContrast
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Ingresar' : 'Registrarme',
                            style: accessibility.getTextStyle(
                              color: accessibility.isHighContrast
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              overrideSize: accessibility.fontSize * 1.1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                  child: Text(
                    _isLogin
                        ? '¿No tienes cuenta? Regístrate aquí'
                        : '¿Ya tienes cuenta? Inicia sesión',
                    style: accessibility.getTextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AccessibilityProvider accessibility,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    final primaryColor = accessibility.activePrimaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = accessibility.isHighContrast
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: accessibility.getTextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: accessibility.getTextStyle(color: primaryColor),
        prefixIcon: Icon(icon, color: primaryColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
