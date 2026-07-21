import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  static const _tabs = [
    _NavTab(
      path: AppConstants.routeHome,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    _NavTab(
      path: AppConstants.routeMarketplace,
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      label: 'Market',
    ),
    _NavTab(
      path: AppConstants.routeExperts,
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      label: 'Experts',
    ),
    _NavTab(
      path: AppConstants.routeTransport,
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping,
      label: 'Transport',
    ),
    _NavTab(
      path: AppConstants.routeKnowledge,
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      label: 'Learn',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();

    int currentIndex = 0;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) {
        currentIndex = i;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final tab = entry.value;
                final isActive = currentIndex == i;
                return _NavItem(
                  tab: tab,
                  isActive: isActive,
                  onTap: () => context.go(tab.path),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavTab({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? tab.activeIcon : tab.icon,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? AppColors.primary : AppColors.textTertiary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for home tab content
class HomeTabContent extends ConsumerWidget {
  const HomeTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar with greeting
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.white,
            elevation: 0,
            title: userAsync.when(
              data: (user) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_greeting()}, 👋',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    user?.fullName.split(' ').first ?? 'User',
                    style: AppTextStyles.titleLarge,
                  ),
                ],
              ),
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Agrotech Ghana'),
            ),
            actions: [
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('3',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () => context.go(AppConstants.routeNotifications),
              ),
              IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () => context.go(AppConstants.routeProfile),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet preview
                  _WalletCard(),
                  const SizedBox(height: 24),

                  // Quick actions
                  Text('Quick Actions', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 12),
                  _QuickActions(),
                  const SizedBox(height: 24),

                  // Market prices
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Market Prices', style: AppTextStyles.headlineSmall),
                      TextButton(
                        onPressed: () {},
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MarketPricesWidget(),
                  const SizedBox(height: 24),

                  // Recent listings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fresh Listings', style: AppTextStyles.headlineSmall),
                      TextButton(
                        onPressed: () => context.go(AppConstants.routeMarketplace),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _WalletCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.go(AppConstants.routeWallet),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Wallet Balance',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white.withOpacity(0.8)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₵0.00',
              style: AppTextStyles.displayMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _WalletAction(
                  icon: Icons.add,
                  label: 'Top Up',
                  onTap: () => context.go(AppConstants.routeWallet),
                ),
                const SizedBox(width: 12),
                _WalletAction(
                  icon: Icons.send,
                  label: 'Withdraw',
                  onTap: () => context.go(AppConstants.routeWallet),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WalletAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final _actions = const [
    _QuickAction('🌾', 'Sell\nProduce', AppConstants.routeCreateListing, AppColors.farmerRole),
    _QuickAction('🛒', 'Buy\nProduce', AppConstants.routeMarketplace, AppColors.primary),
    _QuickAction('🎓', 'Talk to\nExpert', AppConstants.routeExperts, AppColors.expertRole),
    _QuickAction('🚛', 'Transport\nGoods', AppConstants.routeCreateTransportJob, AppColors.driverRole),
    _QuickAction('📚', 'Browse\nCourses', '/knowledge/courses', AppColors.enthusiastRole),
  ];

  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final action = _actions[i];
          return GestureDetector(
            onTap: () => context.go(action.route),
            child: Container(
              width: 76,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: action.color.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(action.emoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: action.color,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction {
  final String emoji;
  final String label;
  final String route;
  final Color color;
  const _QuickAction(this.emoji, this.label, this.route, this.color);
}

class _MarketPricesWidget extends StatelessWidget {
  const _MarketPricesWidget();

  @override
  Widget build(BuildContext context) {
    // Placeholder static data — will be replaced by live Supabase query
    final prices = [
      {'item': 'Maize', 'price': '₵4.50/kg', 'change': '+0.20', 'up': true},
      {'item': 'Tomatoes', 'price': '₵6.00/kg', 'change': '-0.50', 'up': false},
      {'item': 'Cassava', 'price': '₵2.80/kg', 'change': '+0.10', 'up': true},
      {'item': 'Plantain', 'price': '₵3.20/kg', 'change': '0.00', 'up': null},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: prices.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final isUp = p['up'] as bool?;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(p['item'] as String,
                          style: AppTextStyles.titleSmall),
                    ),
                    Text(
                      p['price'] as String,
                      style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUp == null
                            ? AppColors.border
                            : isUp
                                ? AppColors.success.withOpacity(0.12)
                                : AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isUp != null)
                            Icon(
                              isUp
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 10,
                              color: isUp ? AppColors.success : AppColors.error,
                            ),
                          Text(
                            p['change'] as String,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isUp == null
                                  ? AppColors.textTertiary
                                  : isUp
                                      ? AppColors.success
                                      : AppColors.error,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < prices.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}
