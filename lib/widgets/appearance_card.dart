import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';
import '../theme/app_colors.dart';

/// Elección de tema (claro, oscuro o el del teléfono) y color principal.
/// La ve cualquier usuario (alumno, docente o psicopedagoga).
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = accessibility.isHighContrast || isDark
        ? Colors.white
        : AppColors.darkBlue;

    return Card(
      color: accessibility.isHighContrast
          ? Colors.grey.shade900
          : Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Apariencia',
                  style: accessibility.getTextStyle(
                    overrideSize: accessibility.fontSize * 1.05,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Tema de pantalla',
              style: accessibility.getTextStyle(
                  color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Teléfono'),
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
                onSelectionChanged: (selection) =>
                    accessibility.setThemeMode(selection.first),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"Teléfono" sigue el modo claro u oscuro de tu celular.',
              style: accessibility.getTextStyle(
                overrideSize: accessibility.fontSize * 0.75,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Color principal',
              style: accessibility.getTextStyle(
                  color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (accessibility.isHighContrast)
              Text(
                'El alto contraste está activado y define los colores.',
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 0.85,
                  color: textColor.withValues(alpha: 0.8),
                ),
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: accessibility.availableColors.map((color) {
                  final isSelected =
                      accessibility.customColor.toARGB32() == color.toARGB32();
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: 'Elegir este color',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => accessibility.setCustomColor(color),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: textColor, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (accessibility.isColorBlindMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Estos colores se distinguen bien con tu tipo de daltonismo.',
                  style: accessibility.getTextStyle(
                    overrideSize: accessibility.fontSize * 0.75,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
