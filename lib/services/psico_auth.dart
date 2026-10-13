import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class PsicoAuth {
  /// Devuelve null si todo está OK, o el mensaje de error.
  /// Usa un cliente temporal: no pisa la sesión del alumno.
  static Future<String?> verify(String email, String password) async {
    final tmp = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    try {
      final response =
          await tmp.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) return 'Credenciales incorrectas.';

      final profile = await tmp
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = (profile?['role'] as String?)?.toLowerCase();
      if (role == 'psicopedagoga') return null;
      return 'Esta cuenta no tiene permisos de psicopedagoga.';
    } on AuthException {
      return 'Credenciales incorrectas.';
    } catch (_) {
      return 'Error al validar credenciales. Revisa tu conexión.';
    } finally {
      try {
        await tmp.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }
  }

  /// Muestra el diálogo. Devuelve true si las credenciales son de psicopedagoga.
  static Future<bool> showDialogGate(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PsicoGateDialog(),
    );
    return result ?? false;
  }
}

class _PsicoGateDialog extends StatefulWidget {
  const _PsicoGateDialog();

  @override
  State<_PsicoGateDialog> createState() => _PsicoGateDialogState();
}

class _PsicoGateDialogState extends State<_PsicoGateDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Completa correo y contraseña.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await PsicoAuth.verify(email, password);
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_person_outlined),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Acceso Docente / Psicopedagoga',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa con tu cuenta para modificar la configuración de accesibilidad.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              onSubmitted: (_) => _isLoading ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Ingresar'),
        ),
      ],
    );
  }
}
