/// Subscription tier enum for FuelWise
enum SubscriptionTier {
  free,
  premiumMonthly,
  premiumAnnual,
}

/// Extension to provide helper methods for subscription tiers
extension SubscriptionTierExtension on SubscriptionTier {
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premiumMonthly:
        return 'Premium Monthly';
      case SubscriptionTier.premiumAnnual:
        return 'Premium Annual';
    }
  }

  String get productId {
    switch (this) {
      case SubscriptionTier.free:
        return '';
      case SubscriptionTier.premiumMonthly:
        return 'fuelwise_premium_monthly';
      case SubscriptionTier.premiumAnnual:
        return 'fuelwise_premium_annual';
    }
  }

  double get price {
    switch (this) {
      case SubscriptionTier.free:
        return 0.0;
      case SubscriptionTier.premiumMonthly:
        return 4.99;
      case SubscriptionTier.premiumAnnual:
        return 49.99;
    }
  }

  String get priceDisplay {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premiumMonthly:
        return '\$4.99/month';
      case SubscriptionTier.premiumAnnual:
        return '\$49.99/year';
    }
  }

  bool get isPremium => this != SubscriptionTier.free;
}

/// User subscription details
class UserSubscription {
  final SubscriptionTier tier;
  final DateTime? expiryDate;
  final bool isActive;
  final String? entitlementId;

  UserSubscription({
    required this.tier,
    this.expiryDate,
    this.isActive = false,
    this.entitlementId,
  });

  /// Check if user has premium access
  bool get hasPremiumAccess {
    if (tier == SubscriptionTier.free) return false;
    if (!isActive) return false;
    if (expiryDate != null && expiryDate!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  /// Feature access checks
  bool get canAccessPriceTrends => hasPremiumAccess;
  bool get canAccessPriceAlerts => hasPremiumAccess;
  bool get canAccessCloudSync => hasPremiumAccess;
  bool get canAccessDetailedReports => hasPremiumAccess;
  int get maxVehicles => hasPremiumAccess ? 5 : 1;
  bool get hasAds => !hasPremiumAccess;

  /// Create a free subscription
  factory UserSubscription.free() {
    return UserSubscription(
      tier: SubscriptionTier.free,
      isActive: true,
    );
  }

  /// Create from RevenueCat entitlement
  factory UserSubscription.fromEntitlement({
    required String entitlementId,
    required bool isActive,
    DateTime? expiryDate,
  }) {
    SubscriptionTier tier;
    
    // Determine tier from entitlement
    if (entitlementId.contains('annual')) {
      tier = SubscriptionTier.premiumAnnual;
    } else if (entitlementId.contains('monthly') || entitlementId.contains('premium')) {
      tier = SubscriptionTier.premiumMonthly;
    } else {
      tier = SubscriptionTier.free;
    }

    return UserSubscription(
      tier: tier,
      isActive: isActive,
      expiryDate: expiryDate,
      entitlementId: entitlementId,
    );
  }

  @override
  String toString() {
    return 'UserSubscription(tier: ${tier.displayName}, active: $isActive, expires: $expiryDate)';
  }
}

/// Available subscription offering
class SubscriptionOffering {
  final String id;
  final String title;
  final String description;
  final SubscriptionTier tier;
  final String priceString;
  final double price;
  final String? introOfferDetails;

  SubscriptionOffering({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.priceString,
    required this.price,
    this.introOfferDetails,
  });
}

/// Premium feature definition
class PremiumFeature {
  final String title;
  final String description;
  final String icon;
  final bool availableInFree;

  const PremiumFeature({
    required this.title,
    required this.description,
    required this.icon,
    this.availableInFree = false,
  });

  static const List<PremiumFeature> allFeatures = [
    PremiumFeature(
      title: 'Find Cheapest Fuel',
      description: 'Search nearby stations and find the best price',
      icon: '⛽',
      availableInFree: true,
    ),
    PremiumFeature(
      title: 'Savings Tracker',
      description: 'Track how much you save with FuelWise',
      icon: '💰',
      availableInFree: true,
    ),
    PremiumFeature(
      title: 'Google Maps Navigation',
      description: 'Navigate directly to your chosen station',
      icon: '🗺️',
      availableInFree: true,
    ),
    PremiumFeature(
      title: 'Ad-Free Experience',
      description: 'No banner or interstitial ads',
      icon: '🚫',
    ),
    PremiumFeature(
      title: 'Price Trends & History',
      description: 'View 30-day price trends and predictions',
      icon: '📈',
    ),
    PremiumFeature(
      title: 'Price Drop Alerts',
      description: 'Get notified when fuel prices drop',
      icon: '🔔',
    ),
    PremiumFeature(
      title: 'Multi-Vehicle Profiles',
      description: 'Manage up to 5 different vehicles',
      icon: '🚗',
    ),
    PremiumFeature(
      title: 'Detailed Reports',
      description: 'Monthly and yearly savings analysis',
      icon: '📊',
    ),
    PremiumFeature(
      title: 'Cloud Backup & Sync',
      description: 'Sync data across all your devices',
      icon: '☁️',
    ),
    PremiumFeature(
      title: 'Priority Support',
      description: 'Get help faster via email support',
      icon: '⭐',
    ),
  ];
}
