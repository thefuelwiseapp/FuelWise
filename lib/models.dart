import 'package:flutter/material.dart';

// Model for Fuel Type
class FuelType {
  final String code;
  final String name;

  FuelType({
    required this.code,
    required this.name,
  });

  factory FuelType.fromJson(Map<String, dynamic> json) {
    return FuelType(
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

// Model for Fuel Station (API response)
class Station {
  final String siteId;
  final String name;
  final String address;
  final double price;
  final double latitude;
  final double longitude;
  final String? brand;
  final DateTime? lastUpdated;

  Station({
    this.siteId = '',
    required this.name,
    required this.address,
    required this.price,
    required this.latitude,
    required this.longitude,
    this.brand,
    this.lastUpdated,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      siteId: json['siteId']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Station',
      address: json['address'] as String? ?? 'Address not available',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      brand: json['brand'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
    );
  }
}

// Model for Calculation Result (UI display)
class StationResult {
  final Station station;
  final double distance;
  final double fillUpCost;
  final double drivingCost;
  final double totalCost;
  final double discountedPrice;       // price per litre after loyalty discount
  final double loyaltyDiscount;       // discount applied in dollars/L (0 if none)
  final LoyaltyCard? applicableCard;  // which card earned the discount (for badge)

  StationResult({
    required this.station,
    required this.distance,
    required this.fillUpCost,
    required this.drivingCost,
    required this.totalCost,
    this.discountedPrice = 0.0,
    this.loyaltyDiscount = 0.0,
    this.applicableCard,
  });
}

// ─────────────────────────────────────────────
// LOYALTY CARD MODEL
// ─────────────────────────────────────────────

/// Represents an Australian fuel loyalty card / discount program.
class LoyaltyCard {
  final String id;
  final String name;
  final double discountCentsPerLitre;
  final List<String> validBrands; // empty = valid everywhere
  final String description;
  final String emoji;        // fallback for result tile badge
  final Color badgeColor;    // brand-representative colour
  final String badgeLabel;   // short text shown in the badge (2-3 chars)

  const LoyaltyCard({
    required this.id,
    required this.name,
    required this.discountCentsPerLitre,
    required this.validBrands,
    required this.description,
    required this.emoji,
    required this.badgeColor,
    required this.badgeLabel,
  });

  /// Whether this card applies to a given station, checking both the brand
  /// field and the station name (fallback for APIs that return numeric brand IDs).
  /// Pass [stationName] so QLD API results can match on name when brand is unusable.
  bool appliesTo(String? brand, {String? stationName}) {
    if (validBrands.isEmpty) return false;

    // Build a combined string to match against — prefer brand, fall back to name
    // Ignore brand if it looks like a numeric ID (QLD API returns brand as a number)
    final brandIsNumeric = brand != null &&
        brand.trim().isNotEmpty &&
        double.tryParse(brand.trim()) != null;

    final candidates = <String>[];
    if (brand != null && brand.trim().isNotEmpty && !brandIsNumeric) {
      candidates.add(brand.toLowerCase().trim());
    }
    if (stationName != null && stationName.trim().isNotEmpty) {
      candidates.add(stationName.toLowerCase().trim());
    }

    if (candidates.isEmpty) return false;

    return validBrands.any((v) {
      final keyword = v.toLowerCase().trim();
      return candidates.any((c) => c.contains(keyword) || keyword.contains(c));
    });
  }

  /// Discount as dollars per litre (e.g. 0.04).
  double get discountPerLitre => discountCentsPerLitre / 100;

  static const List<LoyaltyCard> all = [
    LoyaltyCard(
      id: 'flybuys',
      name: 'Flybuys (Coles/Viva)',
      discountCentsPerLitre: 4,
      validBrands: ['coles express', 'shell coles', 'reddy express', 'shell reddy', 'viva'],
      description: '4c/L off at Coles Express, Reddy Express & Viva sites',
      emoji: '🔴',
      badgeColor: Color(0xFFE31837), // Flybuys/Coles red
      badgeLabel: 'FLY',
    ),
    LoyaltyCard(
      id: 'everyday_rewards',
      name: 'Everyday Rewards',
      discountCentsPerLitre: 4,
      validBrands: ['eg ampol', 'eg ', ' eg', 'foodary', 'woolworths metrogo'],
      description: '4c/L off at EG Ampol & Ampol Foodary sites',
      emoji: '🟢',
      badgeColor: Color(0xFF007B40), // Woolworths green
      badgeLabel: 'EDR',
    ),
    LoyaltyCard(
      id: 'racq',
      name: 'RACQ',
      discountCentsPerLitre: 4,
      validBrands: ['united', 'puma', '7-eleven', '7 eleven', 'caltex'],
      description: '4c/L off at United, Puma, 7-Eleven & Caltex (QLD)',
      emoji: '🔵',
      badgeColor: Color(0xFF003DA5), // RACQ blue
      badgeLabel: 'RACQ',
    ),
    LoyaltyCard(
      id: 'nrma',
      name: 'NRMA',
      discountCentsPerLitre: 4,
      validBrands: ['united', 'puma', 'liberty', 'ampol foodary', 'foodary'],
      description: '4c/L off at United, Puma, Liberty & Ampol Foodary (NSW)',
      emoji: '🟡',
      badgeColor: Color(0xFFFFCC00), // NRMA yellow
      badgeLabel: 'NRMA',
    ),
    LoyaltyCard(
      id: 'ampol_app',
      name: 'Ampol App',
      discountCentsPerLitre: 6,
      validBrands: ['ampol', 'eg ampol', 'foodary'],
      description: '6c/L off at Ampol stations via the Ampol app',
      emoji: '🟠',
      badgeColor: Color(0xFFE8612C), // Ampol orange
      badgeLabel: 'AMP',
    ),
  ];

  /// Get all cards matching a list of IDs.
  static List<LoyaltyCard> fromIds(List<String> ids) {
    return all.where((c) => ids.contains(c.id)).toList();
  }

  static LoyaltyCard fromId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => all.first);
  }
}