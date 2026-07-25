import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nitya_sadhana/core/theme/app_theme.dart';
import 'package:nitya_sadhana/services/subscription_service.dart';
import 'package:purchases_flutter/models/package_wrapper.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.featureTitle});

  final String? featureTitle;

  static Future<bool> show(BuildContext context, {String? featureTitle}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => PaywallScreen(featureTitle: featureTitle)
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}


class _PaywallScreenState extends ConsumerState<PaywallScreen> {

  Package? _monthlyPackage;
  Package? _yearlypackage;
  bool _loadingOfferings = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    final offerings = await ref.read(subscriptionProvider).getOfferings();
    if (mounted) {
      setState(() {
        _monthlyPackage = offerings.monthly;
        _yearlypackage = offerings.yearly;
        _loadingOfferings = false;
      });
    }
  }

  /// Calculate savings percentage if both plans are available
  String? _savingsLabels() {
    if (_monthlyPackage == null || _yearlypackage == null) return null;
    final monthlyAnnualized = _monthlyPackage!.storeProduct.price * 12;
    final yearlyPrice = _yearlypackage!.storeProduct.price;
    if (monthlyAnnualized <= 0) return null;
    final pct = ((monthlyAnnualized - yearlyPrice) / monthlyAnnualized * 100).round();
    return pct > 0 ? 'Save $pct%' : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      appBar: AppBar(
        title: const Text("Upgrade to Premium"),
        leading: IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [
                          AppColors.saffron.withValues(alpha: 0.15),
                          AppColors.gold.withValues(alpha: 0.1),
                        ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.saffron.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                          Icons.spa_rounded,
                        size: 48,
                        color: AppColors.saffron,
                      ),
                      const SizedBox(height: 12),
                      Text(
                          'Nitya Sadhana Premium',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark
                            ? AppColors.darkTextPrimary
                              : AppColors.textPrimary
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Deepen your spiritual practice',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                            ? AppColors.darkTextSecondary
                              : AppColors.textSecondary
                        ),
                      ),
                      if( widget.featureTitle != null) ...[
                        const SizedBox(height: 12,),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.saffron.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🔒 "$widget.featureTitle" is a Premium feature',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.saffron
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Feature list
                _FeatureRow(
                  icon: Icons.spa_rounded,
                  title: 'Unlimited Mantras',
                  subtitle: 'Add as many mantras as you need',
                  isDark: isDark
                ),
                _FeatureRow(
                    icon: Icons.calendar_month_rounded,
                    title: '7-day Panchang with very high Accuracy',
                    subtitle: 'Plan ahead with weekly forcast',
                    isDark: isDark
                ),
                _FeatureRow(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Sankalp (Goals)',
                    subtitle: 'Set and track spiritual commitments',
                    isDark: isDark
                ),
                _FeatureRow(
                    icon: Icons.notifications_active_rounded,
                    title: 'Smart Notifications',
                    subtitle: 'SNS for distraction-free practice',
                    isDark: isDark
                ),
                _FeatureRow(
                    icon: Icons.do_not_disturb_on_rounded,
                    title: 'Sadhana Mode',
                    subtitle: 'DND for distraction-free practice',
                    isDark: isDark
                ),
                _FeatureRow(
                    icon: Icons.music_note_rounded,
                    title: 'Background Sounds',
                    subtitle: 'Soothing sounds during japa',
                    isDark: isDark
                ),
                _FeatureRow(
                    icon: Icons.block_rounded,
                    title: 'Ad-Free Experience',
                    subtitle: 'No interruptions, pure devotion',
                    isDark: isDark
                ),

                const SizedBox(width: 24),

                // Pricing cards dynamic from RevenueCat,
                if (_loadingOfferings)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: AppColors.saffron),
                  )
                else if (_monthlyPackage == null && _yearlypackage == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Uanble to load pricing. Please check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (_monthlyPackage != null)
                        Expanded(
                          child: _PricingCard(
                            title: 'Monthly',
                            price: _monthlyPackage!.storeProduct.priceString,
                            period: '/month',
                            isDark: isDark,
                            isPopular: false,
                            onTap: _purchasing ? null : () => _handlePurchase(_monthlyPackage!),
                          ),
                        ),
                      if(_monthlyPackage != null && _yearlypackage != null)
                        const SizedBox(width: 12,),
                      if(_yearlypackage != null)
                        Expanded(
                            child: _PricingCard(
                              title: 'Yearly',
                              price: _yearlypackage!.storeProduct.priceString,
                              period: '/yearly',
                              isDark: isDark,
                              isPopular: true,
                              savings: _savingsLabels(),
                              onTap: _purchasing ? null : () => _handlePurchase(_monthlyPackage!),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),

                // Restore purchase
                TextButton(
                    onPressed: _purchasing ? null : () => _handleRestore(),
                    child: Text(
                      'Restore Purchase',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                          ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                ),

                const SizedBox(height: 8),

                // Legal
                Text(
                  'Payment will be charged to your App Store / Play Store Account. '
                      'Subscription auto-renews unless cancelled 24 hours before the end of the current period.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                      ? AppColors.darkTextSecondary.withValues(alpha: 0.6)
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          )
      ),
    );
  }
  
  Future<void> _handlePurchase(Package package) async {
    setState(() => _purchasing = true);
    final success = await ref.read(subscriptionProvider).purchasePackage(package);
    if (mounted) {
      setState(() => _purchasing = false);
      if(success) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Welcome to Premium! 🙏'),
              behavior: SnackBarBehavior.floating,
            ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase could not be completed.'),
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }
  
  Future<void> _handleRestore() async {
    setState(() => _purchasing = true);
    final restored = await ref.read(subscriptionProvider).restorePurchase();
    if (mounted) {
      setState(() => _purchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(restored
              ? 'Premium restored successfully! 🙏'
              : 'No Previously purchases found.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (restored) Navigator.pop(context, true);
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsetsGeometry.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.saffron.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.saffron),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                          ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                    ),
                ),
              ],
            ),
            ),

            const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.teal),
          ],
        ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final bool isDark;
  final bool isPopular;
  final String? savings;
  final VoidCallback? onTap;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    required this.isDark,
    required this.isPopular,
    this.savings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isPopular
              ? AppColors.saffron
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: isPopular
            ? null
              : Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.divider
          ),
          boxShadow: isPopular ? [
            BoxShadow(
              color: AppColors.saffron.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
            : null,
        ),
        child: Column(
          children: [
            if (isPopular && savings != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  savings!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPopular ? Colors.white : AppColors.saffron,
                  ),
                ),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isPopular ? Colors.white.withValues(alpha: 0.85) : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isPopular
                          ? Colors.white
                          : (isDark
                            ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                    ),
                  ),

                  TextSpan(
                    text: period,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isPopular
                        ? Colors.white.withValues(alpha: 0.8)
                        : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                    )
                  )
                ]
              )
            )
          ],
        ),
      ),
    );
  }
}