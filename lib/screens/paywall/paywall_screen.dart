import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/purchase_service.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(purchaseProvider);
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (purchase.isPro) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pro')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 64, color: AppColors.gold),
              const SizedBox(height: 16),
              Text(
                'You are a Pro member!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All features are unlocked.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Pro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.auto_awesome_rounded, size: 56, color: AppColors.gold),
              const SizedBox(height: 16),
              Text(
                'Nitya Sadhana Pro',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock the complete spiritual experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Feature list
              ..._features.map((f) => _FeatureRow(icon: f.$1, text: f.$2, isDark: isDark)),

              const SizedBox(height: 32),

              // Price
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.saffron, AppColors.deepMaroon],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      Platform.isIOS ? '₹65' : '₹49',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'One-time purchase. No subscriptions.',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: purchase.isLoading
                            ? null
                            : () async {
                                if (!auth.isSignedIn) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please sign in first from Settings.')),
                                  );
                                  return;
                                }
                                final success = await ref.read(purchaseProvider).purchasePro();
                                if (success && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.saffron,
                        ),
                        child: const Text('Purchase Pro'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final restored = await ref.read(purchaseProvider).restorePurchases();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(restored ? 'Purchases restored!' : 'No purchases found.')),
                    );
                    if (restored) Navigator.of(context).pop();
                  }
                },
                child: const Text('Restore Purchases'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _features = [
    (Icons.all_inclusive_rounded, 'Unlimited mantras'),
    (Icons.auto_awesome_rounded, 'Sankalp (Vow) system with progress tracking'),
    (Icons.volume_up_rounded, 'Volume button counting'),
    (Icons.music_note_rounded, 'Background sounds (Tanpura, Temple Bells)'),
    (Icons.local_fire_department_rounded, 'Streaks & weekly charts'),
    (Icons.file_download_rounded, 'CSV export of japa history'),
    (Icons.notifications_active_rounded, 'Brahma Muhurta & Sandhya Kaal alerts'),
    (Icons.temple_hindu, 'Pilgrimage compass & ritual modes'),
    (Icons.dark_mode_rounded, 'Dark mode'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _FeatureRow({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.saffron),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.teal),
        ],
      ),
    );
  }
}
