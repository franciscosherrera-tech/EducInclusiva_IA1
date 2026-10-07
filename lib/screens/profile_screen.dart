import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/accessibility_provider.dart';
import '../providers/user_provider.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _nameController = TextEditingController(text: userProvider.name);
    _emailController = TextEditingController(text: userProvider.email);
    _loadProfileFromSupabase();
  }

  Future<void> _loadProfileFromSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          if (profile['name'] != null &&
              profile['name'].toString().isNotEmpty) {
            _nameController.text = profile['name'];
          }
          if (user.email != null) {
            _emailController.text = user.email!;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  ImageProvider? _getProfileImage(String path) {
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  Future<void> _saveProfileChanges(UserProvider userProvider) async {
    setState(() => _isSaving = true);
    final user = _supabase.auth.currentUser;

    try {
      final newName = _nameController.text.trim();
      userProvider.updateName(newName);
      userProvider.updateEmail(_emailController.text.trim());

      if (user != null) {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'name': newName,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar en Supabase: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;

    final imageProvider = _getProfileImage(userProvider.profileImagePath);

    return Scaffold(
      backgroundColor: accessibility.isHighContrast
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Mi Perfil',
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 1.1,
            color: accessibility.isHighContrast
                ? Colors.yellowAccent
                : Colors.white,
          ),
        ),
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor:
            accessibility.isHighContrast ? Colors.yellowAccent : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final image =
                    await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  userProvider.updateProfileImage(image.path);
                }
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  imageProvider == null
                      ? userProvider.getDefaultAvatar(
                          radius: 60, color: primaryColor)
                      : CircleAvatar(
                          radius: 60,
                          backgroundImage: imageProvider,
                        ),
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    radius: 20,
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildCustomTextField(
              label: 'Nombre Completo',
              controller: _nameController,
              icon: Icons.person,
              accessibility: accessibility,
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              label: 'Correo Electrónico',
              controller: _emailController,
              icon: Icons.email,
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
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed:
                    _isSaving ? null : () => _saveProfileChanges(userProvider),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Guardar Cambios',
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(
                  'Cerrar Sesión',
                  style: accessibility.getTextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    overrideSize: accessibility.fontSize * 1.0,
                  ),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cerrar Sesión'),
                      content: const Text('¿Estás seguro de que deseas salir?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Salir',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await _supabase.auth.signOut();
                    await userProvider.signOut();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required AccessibilityProvider accessibility,
  }) {
    final primaryColor = accessibility.activePrimaryColor;
    return TextField(
      controller: controller,
      style: accessibility.getTextStyle(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: accessibility.getTextStyle(color: primaryColor),
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
