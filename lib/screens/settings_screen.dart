import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/accessibility_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _resetOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    AccessibilityProvider accessibility,
    Color primaryColor,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Cerrar sesión',
          style: accessibility.getTextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Seguro que quieres cerrar tu sesión?',
          style: accessibility.getTextStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancelar', style: accessibility.getTextStyle()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Cerrar sesión',
              style: accessibility.getTextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    await context.read<UserProvider>().signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);

    // Solo mostramos "Cerrar sesión" si hay una sesión activa
    final bool hasSession =
        Supabase.instance.client.auth.currentSession != null;

    final List<Color> themePalette = [
      AppColors.darkBlue,
      AppColors.periwinkle,
      AppColors.mint,
      AppColors.warmYellow,
      AppColors.lightBlue,
      const Color(0xFFE892A8),
    ];

    final Color bgColor =
        accessibility.isHighContrast ? Colors.black : AppColors.background;
    final Color cardColor =
        accessibility.isHighContrast ? Colors.grey.shade900 : Colors.white;
    final Color textColor =
        accessibility.isHighContrast ? Colors.white : AppColors.darkBlue;

    final Color primaryColor = accessibility.isColorBlindMode
        ? Colors.blue.shade700
        : (accessibility.isHighContrast
            ? Colors.yellowAccent
            : accessibility.customColor);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Configuración y Accesibilidad',
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
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- PERSONALIZACIÓN DE TEMA Y COLOR ---
          Text(
            'Tema y Color de Interfaz',
            style: accessibility.getTextStyle(
                overrideSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor),
          ),
          const SizedBox(height: 8),
          Card(
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo de pantalla:',
                    style: accessibility.getTextStyle(
                        color: textColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Sistema'),
                          icon: Icon(Icons.brightness_auto, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Claro'),
                          icon: Icon(Icons.light_mode, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Oscuro'),
                          icon: Icon(Icons.dark_mode, size: 18),
                        ),
                      ],
                      selected: {accessibility.themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        accessibility.setThemeMode(newSelection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: textColor.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona el color principal:',
                    style: accessibility.getTextStyle(
                        color: textColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: themePalette.map((color) {
                      final isSelected = accessibility.customColor.toARGB32() ==
                          color.toARGB32();
                      return InkWell(
                        onTap: () => accessibility.setCustomColor(color),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: accessibility.isHighContrast
                                        ? Colors.white
                                        : Colors.black87,
                                    width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- VISIÓN ---
          Text(
            'Visión',
            style: accessibility.getTextStyle(
                overrideSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor),
          ),
          Card(
            color: cardColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tamaño del texto: ${accessibility.fontSize.round()}',
                        style: accessibility.getTextStyle(
                            color: textColor, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Icon(Icons.text_fields, size: 16, color: textColor),
                          Expanded(
                            child: Slider(
                              value: accessibility.fontSize,
                              min: 14.0,
                              max: 36.0,
                              divisions: 11,
                              activeColor: primaryColor,
                              onChanged: (val) =>
                                  accessibility.setFontSize(val),
                            ),
                          ),
                          Icon(Icons.text_fields, size: 32, color: textColor),
                        ],
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: Text('Alto Contraste',
                      style: accessibility.getTextStyle(color: textColor)),
                  subtitle: Text('Fondo oscuro y colores brillantes',
                      style: accessibility.getTextStyle(
                          overrideSize: 12,
                          color: textColor.withValues(alpha: 0.7))),
                  value: accessibility.isHighContrast,
                  activeThumbColor: primaryColor,
                  onChanged: (val) => accessibility.toggleHighContrast(val),
                ),
                SwitchListTile(
                  title: Text('Modo Daltonismo',
                      style: accessibility.getTextStyle(color: textColor)),
                  subtitle: Text('Ajusta colores para mejor distinción',
                      style: accessibility.getTextStyle(
                          overrideSize: 12,
                          color: textColor.withValues(alpha: 0.7))),
                  value: accessibility.isColorBlindMode,
                  activeThumbColor: primaryColor,
                  onChanged: (val) => accessibility.toggleColorBlindMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- COGNITIVO Y NEURODIVERGENCIA ---
          Text(
            'Cognitivo y Neurodivergencia',
            style: accessibility.getTextStyle(
                overrideSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor),
          ),
          Card(
            color: cardColor,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Modo Lectura (Dislexia)',
                      style: accessibility.getTextStyle(color: textColor)),
                  value: accessibility.isDyslexicFriendly,
                  activeThumbColor: primaryColor,
                  onChanged: (val) => accessibility.toggleDyslexicFriendly(val),
                ),
                SwitchListTile(
                  title: Text('Modo TEA / Estructurado',
                      style: accessibility.getTextStyle(color: textColor)),
                  value: accessibility.isTeaMode,
                  activeThumbColor: primaryColor,
                  onChanged: (val) => accessibility.toggleTeaMode(val),
                ),
                SwitchListTile(
                  title: Text('Modo Foco (TDAH)',
                      style: accessibility.getTextStyle(color: textColor)),
                  subtitle: Text('Oculta distracciones de la interfaz',
                      style: accessibility.getTextStyle(
                          overrideSize: 12,
                          color: textColor.withValues(alpha: 0.7))),
                  value: accessibility.isFocusMode,
                  activeThumbColor: primaryColor,
                  onChanged: (val) => accessibility.toggleFocusMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- AUDICIÓN Y VOZ ---
          Text(
            'Audición y Voz',
            style: accessibility.getTextStyle(
                overrideSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor),
          ),
          Card(
            color: cardColor,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Lectura Automática en Voz Alta',
                      style: accessibility.getTextStyle(color: textColor)),
                  value: accessibility.autoReadText,
                  activeThumbColor: primaryColor,
                  onChanged: (val) => accessibility.toggleAutoRead(val),
                ),
                SwitchListTile(
                  title: Text('Intérprete LSA',
                      style: accessibility.getTextStyle(color: textColor)),
                  value: accessibility.isSignLanguageEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: (val) => accessibility.toggleSignLanguage(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
            ),
            icon: const Icon(Icons.restart_alt),
            label: Text(
              'Volver a configurar inicio',
              style: accessibility.getTextStyle(color: primaryColor),
            ),
            onPressed: () => _resetOnboarding(context),
          ),

          // --- CERRAR SESIÓN (solo si hay sesión activa) ---
          if (hasSession) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor:
                    accessibility.isHighContrast ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: Text(
                'Cerrar sesión',
                style: accessibility.getTextStyle(
                  color: accessibility.isHighContrast
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _signOut(context, accessibility, primaryColor),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
