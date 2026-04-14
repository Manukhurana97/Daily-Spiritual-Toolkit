import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'auth_service.dart';

final purchaseProvider = ChangeNotifierProvider<PurchaseService>((ref) {
  return PurchaseService(ref);
});

class PurchaseService extends ChangeNotifier {
  static const _cacheKey = 'is_pro_user';
  static const _entitlementId = 'pro';

  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  bool _isPro = false;
  bool _isLoading = true;

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;

  PurchaseService(this._ref);

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final cached = await _storage.read(key: _cacheKey);
    if (cached == 'true') {
      _isPro = true;
      _isLoading = false;
      notifyListeners();
      _syncInBackground();
      return;
    }

    await _syncEntitlement();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncInBackground() async {
    try {
      await _syncEntitlement();
    } catch (_) {}
  }

  Future<void> _syncEntitlement() async {
    try {
      final auth = _ref.read(authProvider);
      if (auth.isSignedIn && auth.email != null) {
        final whitelisted = await _checkWhitelist(auth.email!);
        if (whitelisted) {
          await _grantPro();
          return;
        }
      }

      final customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.entitlements.all[_entitlementId]?.isActive == true) {
        await _grantPro();
      } else {
        await _revokePro();
      }
    } catch (e) {
      debugPrint('Entitlement sync error: $e');
    }
  }

  Future<bool> _checkWhitelist(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('whitelist')
          .doc(email.toLowerCase())
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Whitelist check error: $e');
      return false;
    }
  }

  Future<void> _grantPro() async {
    _isPro = true;
    await _storage.write(key: _cacheKey, value: 'true');
    notifyListeners();
  }

  Future<void> _revokePro() async {
    _isPro = false;
    await _storage.delete(key: _cacheKey);
    notifyListeners();
  }

  Future<bool> purchasePro() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return false;

      final package = current.availablePackages.first;
      await Purchases.purchasePackage(package);
      await _grantPro();
      return true;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.all[_entitlementId]?.isActive == true) {
        await _grantPro();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  Future<void> onUserSignedIn(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
    await _syncEntitlement();
  }

  Future<void> onUserSignedOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
    await _revokePro();
  }
}
