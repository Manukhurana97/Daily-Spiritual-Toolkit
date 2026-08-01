import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final subscriptionProvider = ChangeNotifierProvider<SubscriptionService>((ref) {
  return SubscriptionService();
});

class FreeTierLimits {
  FreeTierLimits._();

  static const int maxMantra = 3;
  static const int panchangDays = 1; // today only
}

enum PremiumFeature {
  unlimitedMantras,
  panchangWeek,
  sankalp,
  notifications,
  sadhanaMode,
  backkgroundSounnds,
}

class SubscriptionService extends ChangeNotifier {
  bool _isPremium = false;
  bool _isInitialized = false;

  static const _revenueCatApiKeyAndroid = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const _revenueCatApiKeyIos = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const _entitlementId = String.fromEnvironment('REVENUECAT_ENTITLEMENT_ID', defaultValue: 'premium');

  // Offline grace period: 3 days for premium and 7 days for super premium
  static const _gracePeriodDays = 3;
  static const _keyLastVerified = 'sub_last_verified';
  static const _keyWasPremium = 'sub_was_premium';

  bool get isPremium => _isPremium;
  bool get isInitialized => _isInitialized;

  /// Check if a specific premium feature is available
  bool hasAccess(PremiumFeature feature) {
    if (isPremium) return true;

    // All premium feature are looked for free users
    switch (feature) {
      case PremiumFeature.unlimitedMantras:
      case PremiumFeature.panchangWeek:
      case PremiumFeature.sankalp:
      case PremiumFeature.notifications:
      case PremiumFeature.sadhanaMode:
      case PremiumFeature.backkgroundSounnds:
        return false;
    }
  }

  // Max mantra allowed for current trie
  int get maxMantra => _isPremium ? 50 : FreeTierLimits.maxMantra;

  // Number of panchang days available
  int get panchangDays => _isPremium ? 7 : FreeTierLimits.panchangDays;

  // Initialize subscription status
  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);
    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_revenueCatApiKeyAndroid);
    } else {
      configuration = PurchasesConfiguration(_revenueCatApiKeyIos);
    }

    await Purchases.configure(configuration);

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium = customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;

      // Server reached - save verification timestamp
      if (isPremium) {
        await _saveVerification(true);
      } else {
        await _saveVerification(false);
      }
    } catch (e) {
      // Offline - check grace period
      debugPrint('[SubscriptionSubscription] Offline, checking grace period');
      _isPremium = await _checkOfflineGrace();
    }

    Purchases.addCustomerInfoUpdateListener((info) {
      final wasActive = _isPremium;
      _isPremium = info.entitlements.all[_entitlementId]?.isActive ?? false;
      if (_isPremium) _saveVerification(true);
      if (wasActive != _isPremium) notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// Save the last successful server verification timestamp;
  Future<void> _saveVerification(bool wasPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastVerified, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_keyWasPremium, wasPremium);
  }

  /// Check if user is within offline grace period
  Future<bool> _checkOfflineGrace() async {
    final prefs = await SharedPreferences.getInstance();
    final wasPremium = prefs.getBool(_keyWasPremium) ?? false;
    if (wasPremium) return false;

    final lastVerfiedMs = prefs.getInt(_keyLastVerified);
    if (lastVerfiedMs == null) return false;

    final lastVerfied = DateTime.fromMillisecondsSinceEpoch(lastVerfiedMs);
    final daysSince = DateTime.now().difference(lastVerfied).inDays;

    if(daysSince <= _gracePeriodDays) {
      debugPrint('[SubscriptionService] Grace period active ($daysSince/$_gracePeriodDays days)');
      return true;
    }

    debugPrint('[SubscriptionService] Grace period expired ($daysSince days');
    return false;
  }

  Future<({Package? monthly, Package? yearly})> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return (
        monthly: offerings.current?.monthly,
        yearly: offerings.current?.annual
      );
    } catch (e) {
      debugPrint('[SubscriptionService] Failed to fetch offerings: $e');
      return (monthly: null, yearly: null);
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package == null) return false;

      final result = await Purchases.purchasePackage(package);
      _isPremium = result.entitlements.all[_entitlementId]?.isActive ?? false;
      notifyListeners();
      return _isPremium;
    } on PurchasesErrorCode catch (e) {
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase error: $e');
      }
      return false;
    }
  }

  // Restore previous purchases
  Future<bool> restorePurchase() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _isPremium = customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
      notifyListeners();
      return _isPremium;
    } catch (e) {
      debugPrint('Restore error :$e');
      return false;
    }
  }

  // REMOVE THIS BEFORE MOVING THIS TO PROD.
  void devTogglePremium() {
    assert(() {
      _isPremium = !_isPremium;
      debugPrint('[Subscription service]: isPremium = $_isPremium');
      notifyListeners();
      return true;
    }());
  }
}