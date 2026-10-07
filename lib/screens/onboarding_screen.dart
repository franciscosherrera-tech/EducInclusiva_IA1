import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/accessibility_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import 'auth_screen.dart';
import 'main_navigation_screen.dart';
import 'teacher_panel_screen.dart'; // Importante

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedRole = 'Estudiante';

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'Estudiante',
      'title': 'Estudiante / Alumno',
      'icon': Icons.school_rounded,
      'description': 'Aprende y realiza consultas adaptadas con el Tutor IA.',
    },
    {
      'id': 'Referente Afectivo',
      'title': 'Referente Afectivo',
      'icon': Icons.favorite_rounded,
      'description':
          'Familia o acompañante que brinda apoyo afectivo y seguimiento.',
    },
    {
      'id': 'Docente',
      'title': 'Docente / Profesor',
      'icon': Icons.assignment_ind_rounded,
      'description': 'Diseña actividades y realiza seguimiento pedagógico.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bool isLoggedIn =
        Supabase.instance.client.auth.currentSession != null;

    if (isLoggedIn) {
      await userProvider.setRoleAndCompleteOnboarding(_selectedRole);
    } else {
      await userProvider.setRole(_selectedRole);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    Widget targetScreen;
    if (isLoggedIn) {
      if (_selectedRole.toLowerCase() == 'docente') {
        targetScreen = const TeacherPanelScreen();
      } else {
        targetScreen = const MainNavigationScreen();
      }
    } else {
      targetScreen = const AuthScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;

    final Color bgColor = accessibility.isHighContrast
        ? Colors.black
        : Theme.of(context).scaffoldBackgroundColor;
    final Color textColor =
        accessibility.isHighContrast ? Colors.yellowAccent : AppColors.darkBlue;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        elevation: 0,
        title: Text(
          'Configuración Inicial',
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 1.1,
            color: accessibility.isHighContrast
                ? Colors.yellowAccent
                : Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- BARRA DE PASOS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    decoration: BoxDecoration(
                      color: index <= _currentPage
                          ? (accessibility.isHighContrast
                              ? Colors.yellowAccent
                              : primaryColor)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),

          // --- VISTAS SLIDER ---
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildRoleSelectionPage(accessibility, primaryColor, textColor),
                _buildAccessibilityPage(accessibility, primaryColor, textColor),
                _buildSummaryPage(accessibility, primaryColor, textColor),
              ],
            ),
          ),

          // --- BOTÓN CONTINUAR ---
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _nextPage,
                child: Text(
                  _currentPage == 2 ? 'Comenzar Experiencia' : 'Siguiente',
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
          ),
        ],
      ),
    );
  }

  // PASO 1: SELECCIÓN DE ROL
  Widget _buildRoleSelectionPage(
    AccessibilityProvider accessibility,
    Color primaryColor,
    Color textColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Bienvenido/a a EduInclusiva!',
            style: accessibility.getTextStyle(
              overrideSize: accessibility.fontSize * 1.3,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona tu perfil o rol en la plataforma:',
            style: accessibility.getTextStyle(
              overrideSize: accessibility.fontSize * 0.9,
            ),
          ),
          const SizedBox(height: 20),
          ..._roles.map((role) {
            final isSelected = _selectedRole == role['id'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: accessibility.isHighContrast
                    ? Colors.grey.shade900
                    : (isSelected
                        ? primaryColor.withValues(alpha: 0.1)
                        : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (accessibility.isHighContrast
                          ? Colors.grey.shade700
                          : Colors.grey.shade300),
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? primaryColor
                      : primaryColor.withValues(alpha: 0.2),
                  child: Icon(
                    role['icon'],
                    color: isSelected
                        ? Colors.white
                        : (accessibility.isHighContrast
                            ? Colors.yellowAccent
                            : primaryColor),
                  ),
                ),
                title: Text(
                  role['title'],
                  style: accessibility.getTextStyle(
                    fontWeight: FontWeight.bold,
                    overrideSize: accessibility.fontSize * 0.95,
                  ),
                ),
                subtitle: Text(
                  role['description'],
                  style: accessibility.getTextStyle(
                    overrideSize: accessibility.fontSize * 0.8,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: primaryColor)
                    : null,
                onTap: () {
                  setState(() => _selectedRole = role['id']);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // PASO 2: AJUSTES DE ACCESIBILIDAD
  Widget _buildAccessibilityPage(
    AccessibilityProvider accessibility,
    Color primaryColor,
    Color textColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajustes de Accesibilidad',
            style: accessibility.getTextStyle(
              overrideSize: accessibility.fontSize * 1.3,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Personaliza la app según tus preferencias de lectura y asistencia:',
            style: accessibility.getTextStyle(
              overrideSize: accessibility.fontSize * 0.85,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              value: accessibility.isTeaMode,
              title: Text('Modo TEA / Neurodivergente',
                  style: accessibility.getTextStyle(
                      fontWeight: FontWeight.bold,
                      overrideSize: accessibility.fontSize * 0.9)),
              subtitle: Text(
                  'Respuestas estructuradas y menor sobrecarga cognitiva.',
                  style: accessibility.getTextStyle(
                      overrideSize: accessibility.fontSize * 0.8)),
              secondary: Icon(Icons.psychology, color: primaryColor),
              onChanged: (val) => accessibility.toggleTeaMode(val),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              value: accessibility.isSignLanguageEnabled,
              title: Text('Intérprete LSA (Lengua de Señas)',
                  style: accessibility.getTextStyle(
                      fontWeight: FontWeight.bold,
                      overrideSize: accessibility.fontSize * 0.9)),
              subtitle: Text('Avatar animado con interpretación en señas.',
                  style: accessibility.getTextStyle(
                      overrideSize: accessibility.fontSize * 0.8)),
              secondary: Icon(Icons.accessibility, color: primaryColor),
              onChanged: (val) => accessibility.toggleSignLanguage(val),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              value: accessibility.autoReadText,
              title: Text('Lectura en Voz Alta Automática',
                  style: accessibility.getTextStyle(
                      fontWeight: FontWeight.bold,
                      overrideSize: accessibility.fontSize * 0.9)),
              subtitle: Text('Lee en voz alta las respuestas del Tutor IA.',
                  style: accessibility.getTextStyle(
                      overrideSize: accessibility.fontSize * 0.8)),
              secondary: Icon(Icons.volume_up, color: primaryColor),
              onChanged: (val) => accessibility.toggleAutoRead(val),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tamaño del Texto:',
            style: accessibility.getTextStyle(
                fontWeight: FontWeight.bold,
                overrideSize: accessibility.fontSize * 0.95),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ChoiceChip(
                label: const Text('Normal'),
                selected: accessibility.fontSize == 16.0,
                onSelected: (_) => accessibility.setFontSize(16.0),
              ),
              ChoiceChip(
                label: const Text('Grande'),
                selected: accessibility.fontSize == 20.0,
                onSelected: (_) => accessibility.setFontSize(20.0),
              ),
              ChoiceChip(
                label: const Text('Muy Grande'),
                selected: accessibility.fontSize == 24.0,
                onSelected: (_) => accessibility.setFontSize(24.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // PASO 3: RESUMEN Y CONFIRMACIÓN
  Widget _buildSummaryPage(
    AccessibilityProvider accessibility,
    Color primaryColor,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: primaryColor.withValues(alpha: 0.2),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 60,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Configuración Completa!',
            style: accessibility.getTextStyle(
              overrideSize: accessibility.fontSize * 1.3,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresarás con el rol de "$_selectedRole" y tus ajustes adaptativos activos.',
            textAlign: TextAlign.center,
            style: accessibility.getTextStyle(
              overrideSize: accessibility.fontSize * 0.95,
            ),
          ),
        ],
      ),
    );
  }
}
