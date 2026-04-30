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

  StationResult({
    required this.station,
    required this.distance,
    required this.fillUpCost,
    required this.drivingCost,
    required this.totalCost,
  });
}