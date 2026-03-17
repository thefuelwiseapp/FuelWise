import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_models.dart';

/// Service for managing subscriptions using RevenueCat
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // RevenueCat API keys - Replace with your actual keys
  // Get these from https://app.revenuecat.com
  static const String _androidApiKey = 'test_ngnsIWrKWVzncHExpNrAfRaarkB';
  static const String _iosApiKey = 'YOUR_REVENUECAT_IOS_API_KEY';
  
  // Entitlement identifier
  static const String _entitlementId = 'premium';
  
  // Current subscription state
  UserSubscription _currentSubscription = UserSubscription.free();
  List<SubscriptionOffering> _availableOfferings = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserSubscription get subscription => _currentSubscription;
  List<SubscriptionOffering> get offerings => _availableOfferings;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isPremium => _currentSubscription.hasPremiumAccess;
  String? get error => _error;

  /// Initialize RevenueCat SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Configure RevenueCat
      final configuration = PurchasesConfiguration(
        defaultTargetPlatform == TargetPlatform.iOS 
            ? _iosApiKey 
            : _androidApiKey,
      );
      
      await Purchases.configure(configuration);
      
      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      
      // Get initial customer info
      await _refreshSubscriptionStatus();
      
      // Get available offerings
      await _loadOfferings();
      
      _isInitialized = true;
      print('✅ SubscriptionService initialized');
    } catch (e) {
      _error = 'Failed to initialize subscriptions: $e';
      print('❌ SubscriptionService error: $e');
      
      // Fall back to free tier
      _currentSubscription = UserSubscription.free();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handle customer info updates from RevenueCat
  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    _updateSubscriptionFromCustomerInfo(customerInfo);
    notifyListeners();
  }

  /// Refresh subscription status from RevenueCat
  Future<void> _refreshSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateSubscriptionFromCustomerInfo(customerInfo);
    } catch (e) {
      print('⚠️ Error refreshing subscription: $e');
    }
  }

  /// Update local subscription state from CustomerInfo
  void _updateSubscriptionFromCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[_entitlementId];
    
    if (entitlement != null && entitlement.isActive) {
      _currentSubscription = UserSubscription.fromEntitlement(
        entitlementId: entitlement.productIdentifier,
        isActive: entitlement.isActive,
        expiryDate: entitlement.expirationDate != null 
            ? DateTime.parse(entitlement.expirationDate!) 
            : null,
      );
      print('👑 Premium subscription active: ${_currentSubscription.tier.displayName}');
    } else {
      _currentSubscription = UserSubscription.free();
      print('📱 Free tier active');
    }
    
    // Cache subscription status locally
    _cacheSubscriptionStatus();
  }

  /// Load available subscription offerings
  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current != null) {
        _availableOfferings = offerings.current!.availablePackages.map((package) {
          return SubscriptionOffering(
            id: package.identifier,
            title: package.storeProduct.title,
            description: package.storeProduct.description,
            tier: _tierFromPackage(package),
            priceString: package.storeProduct.priceString,
            price: package.storeProduct.price,
            introOfferDetails: package.storeProduct.introductoryPrice?.priceString,
          );
        }).toList();
        
        print('📦 Loaded ${_availableOfferings.length} subscription offerings');
      }
    } catch (e) {
      print('⚠️ Error loading offerings: $e');
      
      // Provide fallback offerings for display purposes
      _availableOfferings = [
        SubscriptionOffering(
          id: 'monthly',
          title: 'FuelWise Premium Monthly',
          description: 'Full access to all premium features',
          tier: SubscriptionTier.premiumMonthly,
          priceString: '\$4.99',
          price: 4.99,
        ),
        SubscriptionOffering(
          id: 'annual',
          title: 'FuelWise Premium Annual',
          description: 'Full access + 2 months free',
          tier: SubscriptionTier.premiumAnnual,
          priceString: '\$49.99',
          price: 49.99,
        ),
      ];
    }
  }

  /// Determine subscription tier from package
  SubscriptionTier _tierFromPackage(Package package) {
    final id = package.identifier.toLowerCase();
    if (id.contains('annual') || id.contains('yearly')) {
      return SubscriptionTier.premiumAnnual;
    }
    return SubscriptionTier.premiumMonthly;
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(String offeringId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        throw Exception('No offerings available');
      }
      
      final package = offerings.current!.availablePackages.firstWhere(
        (p) => p.identifier == offeringId,
        orElse: () => throw Exception('Package not found: $offeringId'),
      );
      
      final customerInfo = await Purchases.purchasePackage(package);
      _updateSubscriptionFromCustomerInfo(customerInfo);
      
      print('✅ Purchase successful!');
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        print('ℹ️ Purchase cancelled by user');
        _error = null;
      } else {
        _error = 'Purchase failed: ${e.name}';
        print('❌ Purchase error: $e');
      }
      return false;
    } catch (e) {
      _error = 'Purchase failed: $e';
      print('❌ Purchase error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateSubscriptionFromCustomerInfo(customerInfo);
      
      if (_currentSubscription.hasPremiumAccess) {
        print('✅ Purchases restored!');
        return true;
      } else {
        print('ℹ️ No previous purchases found');
        return false;
      }
    } catch (e) {
      _error = 'Restore failed: $e';
      print('❌ Restore error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cache subscription status for offline access
  Future<void> _cacheSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', _currentSubscription.hasPremiumAccess);
      await prefs.setString('subscription_tier', _currentSubscription.tier.name);
      if (_currentSubscription.expiryDate != null) {
        await prefs.setString(
          'subscription_expiry', 
          _currentSubscription.expiryDate!.toIso8601String(),
        );
      }
    } catch (e) {
      print('⚠️ Error caching subscription: $e');
    }
  }

  /// Load cached subscription status (for offline access)
  Future<void> loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_premium') ?? false;
      
      if (isPremium) {
        final tierName = prefs.getString('subscription_tier');
        final expiryString = prefs.getString('subscription_expiry');
        
        DateTime? expiry;
        if (expiryString != null) {
          expiry = DateTime.tryParse(expiryString);
        }
        
        // Only use cache if not expired
        if (expiry == null || expiry.isAfter(DateTime.now())) {
          _currentSubscription = UserSubscription(
            tier: SubscriptionTier.values.firstWhere(
              (t) => t.name == tierName,
              orElse: () => SubscriptionTier.premiumMonthly,
            ),
            isActive: true,
            expiryDate: expiry,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      print('⚠️ Error loading cached subscription: $e');
    }
  }

  /// Check if a specific feature is available
  bool canAccess(String feature) {
    switch (feature) {
      case 'price_trends':
        return _currentSubscription.canAccessPriceTrends;
      case 'price_alerts':
        return _currentSubscription.canAccessPriceAlerts;
      case 'cloud_sync':
        return _currentSubscription.canAccessCloudSync;
      case 'detailed_reports':
        return _currentSubscription.canAccessDetailedReports;
      case 'ad_free':
        return !_currentSubscription.hasAds;
      default:
        return true; // Default to allowing access
    }
  }

  /// Get max vehicles allowed
  int get maxVehicles => _currentSubscription.maxVehicles;

  /// Check if ads should be shown
  bool get shouldShowAds => _currentSubscription.hasAds;
}
