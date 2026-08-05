import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nitya_sadhana/services/subscription_service.dart';

/// Ad Service = ABMob interstitial + banner ads
/// Placement Strategy (respecfully for spritual app):
///  * Interstitial after japa session end (70% -> 1, 30% -> 2)
///  * Interstitial on first panchang visit per app session
///  Banner at bottom of Settings page
///  Never duing activbe japa
///  All ads hindden for premium users


final adProviderService = ChangeNotifierProvider<AdService>((ref) {
  return AdService(ref);
});

class AdService extends ChangeNotifier {
  final Ref _ref;
  final _random = Random();

  // Injected via -- dart-define-from-file
  // Fallback to google's ad Id if not provided
  static const _interstitialAdInitAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _interstitialAdInitIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const _bannerADUnitAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const _bannerADUnitIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  bool _isInterstitialReady = false;
  bool _isBannerReally = false;
  bool _isIntialized = false;

  bool _panchangAdShownThisSession = false;
  int _pendingJapaAd = 0;

  bool get isInterstitialReady => _isInterstitialReady;
  bool get isBannerReady => _isBannerReally;
  BannerAd? get bannerId => _bannerAd;

  bool get _shouldShowAd {
    final sub = _ref.read(subscriptionProvider);
    return !sub.isPremium;
  }

  AdService(this._ref);

  Future<void> initialize() async {
    if (_isIntialized) return;
    await MobileAds.instance.initialize();
    _isIntialized = true;

    if (_shouldShowAd) {
      _loadInterstitial();
    }
  }

  void _loadInterstitial() {
    if (!_shouldShowAd) return;

    final adUnitId = defaultTargetPlatform == TargetPlatform.android
    ? _interstitialAdInitAndroid
        : _interstitialAdInitIos;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isInterstitialReady = true;
          _interstitialAd = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialReady = false;
              _interstitialAd = null;

              if (_pendingJapaAd > 0) {
                _pendingJapaAd--;
                _loadInterstitial();
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_isInterstitialReady) {
                    _showInterstitial();
                  }
                });
              } else {
                _loadInterstitial();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[AdService] Interstitial failed to show: $error');
              ad.dispose();
              _isInterstitialReady = false;
              _interstitialAd = null;
              _pendingJapaAd = 0;
              _loadInterstitial();
            }
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint("[AdService] Interstitial failed to load: $error");
          _isInterstitialReady = false;
          _pendingJapaAd = 0;
        }
      )
    );
  }

  void _showInterstitial() {
    if (_interstitialAd != null && _isInterstitialReady) {
      _interstitialAd!.show();
    }
  }

  void showJapaSessionAd() {
    if (!_shouldShowAd) return;

    final roll = _random.nextDouble();
    final adCount = roll < 0.7 ? 1: 2;

    debugPrint('[AdService] japa Session end - showing $adCount ad(s) (roll ${roll.toStringAsFixed(2)}');

    if (adCount == 2) {
      _pendingJapaAd = 1;
    }

    if (_isInterstitialReady) {
      _showInterstitial();
    } else {
      _pendingJapaAd = 0;
      _loadInterstitial();
    }
  }
  
  bool showPanchangAd() {
    if (!_shouldShowAd) return false;
    if (_panchangAdShownThisSession) return false;
    
    _panchangAdShownThisSession = true;
    
    if (_isInterstitialReady) {
      _showInterstitial();
      return true;
    }
    return false;
  }
  
  void loadBanner() {
    if (!_shouldShowAd) return;
    if (_isBannerReally) return;
    
    final adUnitId = defaultTargetPlatform == TargetPlatform.android
    ? _bannerADUnitAndroid : _bannerADUnitIos;
    
    _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: adUnitId,
        request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerReally = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] banner failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerReally = false;
        }
      ),
    )..load();
  }

  /// Dispose banner ad (call when settings screen is disposed)
  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerReally = false;
    notifyListeners();
  }

  /// Call when premium status changes (to stop/start ads)
  void onPermiumStatusChanged() {
    if (_shouldShowAd) {
      _loadInterstitial();
    } else {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialReady = false;
      disposeBanner();
      _pendingJapaAd = 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }
}