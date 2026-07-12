import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                theme.isDark ? Icons.nightlight_round : Icons.wb_sunny,
                color: AppColors.primary,
              ),
              title: Text('Dark Mode', style: AppTextStyles.bodyMedium),
              subtitle: Text(
                theme.isDark ? 'On' : 'Off',
                style: AppTextStyles.bodySmall,
              ),
              value: theme.isDark,
              onChanged: (_) => theme.toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }
}
