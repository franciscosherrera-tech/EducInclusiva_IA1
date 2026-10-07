import 'package:flutter/material.dart';
import '../services/psico_auth.dart';
import 'subjects_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isSettingsUnlocked = false;

  final List<Widget> _screens = const [
    SubjectsScreen(),
    SettingsScreen(),
  ];

  Future<void> _handleTabSelection(int index) async {
    if (index == 1 && !_isSettingsUnlocked) {
      final authenticated = await PsicoAuth.showDialogGate(context);
      if (authenticated && mounted) {
        setState(() {
          _isSettingsUnlocked = true;
          _currentIndex = index;
        });
      }
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _handleTabSelection,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school, color: Colors.teal),
            label: 'Materias',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Colors.teal),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
