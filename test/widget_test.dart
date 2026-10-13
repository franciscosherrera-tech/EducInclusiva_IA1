import 'package:eduinclusiva_ia/providers/accessibility_provider.dart';
import 'package:eduinclusiva_ia/widgets/activity_chart.dart';
import 'package:eduinclusiva_ia/widgets/appearance_card.dart';
import 'package:eduinclusiva_ia/services/tracking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(AccessibilityProvider provider, Widget child) {
  return ChangeNotifierProvider<AccessibilityProvider>.value(
    value: provider,
    child:
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppearanceCard', () {
    testWidgets('el usuario puede elegir tema oscuro', (tester) async {
      final provider = AccessibilityProvider();
      await tester.pumpWidget(_wrap(provider, const AppearanceCard()));

      expect(provider.themeMode, ThemeMode.system);
      await tester.tap(find.text('Oscuro'));
      await tester.pump();

      expect(provider.themeMode, ThemeMode.dark);
    });

    testWidgets('el usuario puede elegir su color principal', (tester) async {
      final provider = AccessibilityProvider();
      await tester.pumpWidget(_wrap(provider, const AppearanceCard()));

      final target = provider.availableColors[3];
      expect(provider.customColor, isNot(target));

      // Los círculos de color son los InkWell con botón "Elegir este color"
      await tester.tap(find.bySemanticsLabel('Elegir este color').at(3));
      await tester.pump();

      expect(provider.customColor, target);
    });

    testWidgets('con alto contraste avisa que los colores están definidos',
        (tester) async {
      final provider = AccessibilityProvider();
      await tester.pumpWidget(_wrap(provider, const AppearanceCard()));
      provider.toggleHighContrast(true);
      await tester.pump();

      expect(find.text('El alto contraste está activado y define los colores.'),
          findsOneWidget);
    });
  });

  group('ActivityChart', () {
    final days = buildDailyActivity(
      messageDates: [DateTime.now(), DateTime.now()],
      materialDates: [DateTime.now()],
    );

    testWidgets('muestra el total del día con actividad', (tester) async {
      await tester.pumpWidget(_wrap(
        AccessibilityProvider(),
        ActivityChart(days: days, primaryColor: Colors.blue),
      ));

      expect(find.text('3'), findsOneWidget); // 2 mensajes + 1 acción
    });

    testWidgets('sin actividad lo dice', (tester) async {
      await tester.pumpWidget(_wrap(
        AccessibilityProvider(),
        ActivityChart(
          days: buildDailyActivity(messageDates: [], materialDates: []),
          primaryColor: Colors.blue,
        ),
      ));

      expect(find.text('Sin actividad en este período.'), findsOneWidget);
    });
  });
}
