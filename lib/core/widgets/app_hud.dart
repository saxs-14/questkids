import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Game-shell HUD bar: a horizontal strip of stat pills (Gold, streak,
/// hearts/lives, timer, etc). Deliberately takes arbitrary [children]
/// rather than a fixed data model -- which stats a given screen shows
/// varies (a game-intro HUD differs from a results-screen HUD), so the
/// composition decision belongs to the caller, not this widget. Pair with
/// [AppCoinPill] and similar pill widgets as children.
class AppHud extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;

  const AppHud({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.spaceBetween,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowSoftDark : AppColors.shadowSoft,
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}
