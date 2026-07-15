import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/labels.dart';
import '../../../core/constants/trading_post_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_coin_pill.dart';
import '../../../core/widgets/quest_boy_mascot.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rewards_provider.dart';
import '../widgets/trading_post_item_card.dart';

/// Gold economy screen: the Trading Post (buy cosmetics with Gold) and
/// the Hideout (equip an owned cosmetic on Quest Boy), as two tabs of
/// one screen since they share the same wallet/inventory state. Reached
/// from a button on the Rewards Overview tab.
class TradingPostScreen extends StatefulWidget {
  const TradingPostScreen({super.key});

  @override
  State<TradingPostScreen> createState() => _TradingPostScreenState();
}

class _TradingPostScreenState extends State<TradingPostScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      final rewards = context.read<RewardsProvider>();
      if (uid != null && rewards.rewards == null) {
        rewards.loadRewards(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabCtrl.index == 0
            ? QuestLabels.tradingPost
            : QuestLabels.hideout),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: QuestLabels.tradingPost),
            Tab(text: QuestLabels.hideout),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [_ShopTab(), _HideoutTab()],
      ),
    );
  }
}

Future<void> _buy(BuildContext context, TradingPostItem item) async {
  final uid = context.read<AuthProvider>().user?.uid;
  if (uid == null) return;
  final rewards = context.read<RewardsProvider>();
  final ok = await rewards.purchaseItem(uid, item);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? "You got the ${item.name}! 🎉"
            : (rewards.walletError ?? 'Something went wrong.'),
      ),
    ),
  );
  rewards.clearWalletError();
}

Future<void> _equip(BuildContext context, String itemId) async {
  final uid = context.read<AuthProvider>().user?.uid;
  if (uid == null) return;
  await context.read<RewardsProvider>().equipItem(uid, itemId);
}

class _ShopTab extends StatelessWidget {
  const _ShopTab();

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsProvider>();
    final owned = rewards.ownedItemIds.toSet();
    final equipped = rewards.equippedItemId;
    final forSale = TradingPostCatalog.items
        .where((i) => i.id != TradingPostCatalog.starterItemId)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: AppGoldLabel(amount: rewards.goldBalance)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Spend Gold you earn from quests on new looks for Quest Boy.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.85,
            ),
            itemCount: forSale.length,
            itemBuilder: (_, i) {
              final item = forSale[i];
              final isOwned = owned.contains(item.id);
              final isEquipped = equipped == item.id;
              return TradingPostItemCard(
                item: item,
                owned: isOwned,
                equipped: isEquipped,
                onTap: isOwned
                    ? () => _equip(context, item.id)
                    : () => _buy(context, item),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HideoutTab extends StatelessWidget {
  const _HideoutTab();

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsProvider>();
    final owned = rewards.ownedItemIds.toSet();
    final equipped = rewards.equippedItemId;
    final ownedItems =
        TradingPostCatalog.items.where((i) => owned.contains(i.id)).toList();
    final equippedItem = TradingPostCatalog.byId(equipped);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                QuestBoyMascot(
                  size: 140,
                  state: QuestBoyState.waving,
                  skin: equippedItem.skin,
                ),
                const SizedBox(height: 8),
                Text(equippedItem.name, style: AppTextStyles.h4),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Your Collection', style: AppTextStyles.h3),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.85,
            ),
            itemCount: ownedItems.length,
            itemBuilder: (_, i) {
              final item = ownedItems[i];
              final isEquipped = equipped == item.id;
              return TradingPostItemCard(
                item: item,
                owned: true,
                equipped: isEquipped,
                onTap: () => _equip(context, item.id),
              );
            },
          ),
        ],
      ),
    );
  }
}
