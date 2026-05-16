import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemesSettings extends StatefulWidget {
  const ThemesSettings({super.key});

  @override
  State<ThemesSettings> createState() => _ThemesSettingsState();
}

class _ThemesSettingsState extends State<ThemesSettings> {
  final _settingsBox = Hive.box('settings');

  static const _presetColors = [
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.grey,
  ];

  Color get _currentColor =>
      _settingsBox.get('color', defaultValue: Colors.grey) as Color;

  int? get _brightness => _settingsBox.get('brightness') as int?;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Appearance'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int?>(
            segments: const [
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.light_mode_rounded, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.dark_mode_rounded, size: 18),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: null,
                icon: Icon(Icons.contrast_rounded, size: 18),
                label: Text('Auto'),
              ),
            ],
            selected: {_brightness},
            onSelectionChanged: (selection) {
              _settingsBox.put('brightness', selection.first);
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(context, 'Accent Color'),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _presetColors.map((seedColor) {
            final scheme = ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: theme.brightness,
              dynamicSchemeVariant: DynamicSchemeVariant.neutral,
            );
            return _ColorSwatch(
              color: scheme.primary,
              isSelected: _currentColor == seedColor,
              onTap: () {
                _settingsBox.put('color', seedColor);
                setState(() {});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}
