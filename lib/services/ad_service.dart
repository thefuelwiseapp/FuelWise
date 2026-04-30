import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'subscription_service.dart';

/// Service for managing ads in FuelWise
class AdService extends ChangeNotifier {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal() {
    _subscriptionService.addListener(_onSubscriptionChanged);
  }

  // Production AdMob IDs
  static const String _bannerAdUnitIdAndroid =
      'ca-app-pub-9562773239981411/8021291631';
  static const String _bannerAdUnitIdIOS =
      'ca-app-pub-3940256099942544/2934735716'; // TODO: Add iOS banner ID

  static const String _interstitialAdUnitIdAndroid =
      'ca-app-pub-9562773239981411/2786038560';
  static const String _interstitialAdUnitIdIOS =
      'ca-app-pub-3940256099942544/4411468910'; // TODO: Add iOS interstitial ID

  static const String _appOpenAdUnitIdAndroid =
      'ca-app-pub-9562773239981411/8042234677';
  static const String _appOpenAdUnitIdIOS =
      'ca-app-pub-3940256099942544/5662855259'; // TODO: Add iOS app open ID

  final SubscriptionService _subscriptionService = SubscriptionService();

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;

  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  bool _isAppOpenAdLoaded = false;
  bool _isShowingAppOpenAd = false;
  bool _isInitialized = false;
  int _searchCount = 0;

  // Track when app open ad was loaded (expire after 4 hours per Google policy)
  DateTime? _appOpenAdLoadTime;
  static const Duration _appOpenAdExpiry = Duration(hours: 4);

  // Show interstitial ad every N searches for free users
  static const int _interstitialFrequency = 3;

  // Getters
  bool get isBannerAdLoaded =>
      _isBannerAdLoaded && !_subscriptionService.isPremium;
  bool get isInterstitialAdLoaded =>
      _isInterstitialAdLoaded && !_subscriptionService.isPremium;
  bool get isAppOpenAdLoaded =>
      _isAppOpenAdLoaded && !_subscriptionService.isPremium;
  BannerAd? get bannerAd => _subscriptionService.isPremium ? null : _bannerAd;
  bool get shouldShowAds => _subscriptionService.shouldShowAds;

  /// Get the appropriate banner ad unit ID for the platform
  String get _bannerAdUnitId {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _bannerAdUnitIdIOS
        : _bannerAdUnitIdAndroid;
  }

  /// Get the appropriate interstitial ad unit ID for the platform
  String get _interstitialAdUnitId {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _interstitialAdUnitIdIOS
        : _interstitialAdUnitIdAndroid;
  }

  /// Get the appropriate app open ad unit ID for the platform
  String get _appOpenAdUnitId {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _appOpenAdUnitIdIOS
        : _appOpenAdUnitIdAndroid;
  }

  /// Check if the loaded app open ad has expired
  bool get _isAppOpenAdExpired {
    if (_appOpenAdLoadTime == null) return true;
    return DateTime.now().difference(_appOpenAdLoadTime!) > _appOpenAdExpiry;
  }

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      print('✅ AdService initialized');

      // Load ads if needed
      _checkAndLoadAds();
    } catch (e) {
      print('❌ AdService initialization error: $e');
    }
  }

  void _onSubscriptionChanged() {
    if (_subscriptionService.isPremium) {
      // User upgraded - dispose all ads
      disposeBannerAd();
      disposeInterstitialAd();
      disposeAppOpenAd();
      notifyListeners();
    } else {
      // User is free - load ads if needed
      if (_isInitialized) {
        _checkAndLoadAds();
      }
    }
  }

  Future<void> _checkAndLoadAds() async {
    if (shouldShowAds) {
      if (!_isBannerAdLoaded) await loadBannerAd();
      if (!_isInterstitialAdLoaded) await loadInterstitialAd();
      if (!_isAppOpenAdLoaded) await loadAppOpenAd();
    }
  }

  /// Load a banner ad
  Future<void> loadBannerAd() async {
    if (!shouldShowAds) return;
    if (_isBannerAdLoaded) return;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('📢 Banner ad loaded');
          _isBannerAdLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Banner ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerAdLoaded = false;
          notifyListeners();
        },
      ),
    );

    await _bannerAd!.load();
  }

  /// Load an interstitial ad
  Future<void> loadInterstitialAd() async {
    if (!shouldShowAds) return;
    if (_isInterstitialAdLoaded) return;

    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('📢 Interstitial ad loaded');
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;

          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdLoaded = false;
              // Preload next ad
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdLoaded = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ Interstitial ad failed to load: $error');
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  /// Load an app open ad
  Future<void> loadAppOpenAd() async {
    if (!shouldShowAds) return;
    if (_isAppOpenAdLoaded && !_isAppOpenAdExpired) return;

    await AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          print('📢 App open ad loaded');
          _appOpenAd = ad;
          _isAppOpenAdLoaded = true;
          _appOpenAdLoadTime = DateTime.now();

          _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('📢 App open ad dismissed');
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdLoaded = false;
              _isShowingAppOpenAd = false;
              // Preload next ad
              loadAppOpenAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ App open ad failed to show: $error');
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdLoaded = false;
              _isShowingAppOpenAd = false;
              loadAppOpenAd();
            },
            onAdShowedFullScreenContent: (ad) {
              print('📢 App open ad showing');
              _isShowingAppOpenAd = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ App open ad failed to load: $error');
          _isAppOpenAdLoaded = false;
        },
      ),
    );
  }

  /// Show app open ad if loaded and not expired
  Future<bool> showAppOpenAd() async {
    if (!shouldShowAds) return false;
    if (_isShowingAppOpenAd) return false;

    // If ad is expired, load a fresh one for next time
    if (_isAppOpenAdExpired) {
      disposeAppOpenAd();
      loadAppOpenAd();
      return false;
    }

    if (_appOpenAd != null && _isAppOpenAdLoaded) {
      await _appOpenAd!.show();
      return true;
    } else {
      loadAppOpenAd(); // Try to load for next time
      return false;
    }
  }

  /// Increment search count and potentially show interstitial
  Future<bool> onSearchComplete() async {
    if (!shouldShowAds) return false;

    _searchCount++;
    if (_searchCount >= _interstitialFrequency) {
      _searchCount = 0;
      return await showInterstitialAd();
    }
    return false;
  }

  /// Show interstitial ad if loaded
  Future<bool> showInterstitialAd() async {
    if (!shouldShowAds) return false;

    if (_interstitialAd != null && _isInterstitialAdLoaded) {
      await _interstitialAd!.show();
      return true;
    } else {
      loadInterstitialAd(); // Try to load for next time
      return false;
    }
  }

  /// Dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;
  }

  /// Dispose interstitial ad
  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoaded = false;
  }

  /// Dispose app open ad
  void disposeAppOpenAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isAppOpenAdLoaded = false;
    _appOpenAdLoadTime = null;
  }

  @override
  void dispose() {
    _subscriptionService.removeListener(_onSubscriptionChanged);
    disposeBannerAd();
    disposeInterstitialAd();
    disposeAppOpenAd();
    super.dispose();
  }

  /// Create a banner ad widget container
  Widget? getBannerAdWidget() {
    if (!shouldShowAds || !_isBannerAdLoaded || _bannerAd == null) {
      return null;
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}