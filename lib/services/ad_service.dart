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
  static const String _bannerAdUnitIdAndroid = 'ca-app-pub-9562773239981411/8021291631';
  static const String _bannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716'; // TODO: Add iOS banner ID
  static const String _interstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712'; // TODO: Add production interstitial ID
  static const String _interstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910'; // TODO: Add iOS interstitial ID

  final SubscriptionService _subscriptionService = SubscriptionService();
  
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  bool _isInitialized = false;
  int _searchCount = 0;
  
  // Show interstitial ad every N searches for free users
  static const int _interstitialFrequency = 3;

  // Getters
  bool get isBannerAdLoaded => _isBannerAdLoaded && !_subscriptionService.isPremium;
  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded && !_subscriptionService.isPremium;
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
      // User upgraded - dispose ads
      disposeBannerAd();
      disposeInterstitialAd();
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
          // Retry logic handled by UI or next init attempt
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
          
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
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

  @override
  void dispose() {
    _subscriptionService.removeListener(_onSubscriptionChanged);
    disposeBannerAd();
    disposeInterstitialAd();
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
