import 'package:flutter/material.dart';
import '../../../core/constants/trading_post_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_coin_pill.dart';

/// A single Trading Post catalog item. Renders one of three states:
/// locked (shows price, tappable to buy), owned (shows an "Owned" tag,
/// tappable to equip), or equipped (highlighted, non-interactive).
class TradingPostItemCard extends StatelessWidget {
  final TradingPostItem item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  const TradingPostItemCard({
    super.key,
    required this.item,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: equipped ? null : onTap,
      accentColor: equipped ? AppColors.gold : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.previewEmoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          if (equipped)
            const _Tag(label: 'Equipped', color: AppColors.gold)
          else if (owned)
            const _Tag(label: 'Owned · tap to equip', color: AppColors.success)
          else
            AppCoinPill(amount: item.priceGold, compact: true),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall
            .copyWith(color: color, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
    );
  }
}
