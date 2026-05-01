import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'models.dart';

class FuelService {
  // NSW FuelCheck API Configuration (OAuth 2.0)
  static const String _nswApiKey = 'mse3ShutX5dIpH8yLhGCR3mUACstrNjk';
  static const String _nswApiSecret = 'OuqYgDfFSPCwQ1FB';
  static const String _nswBaseUrl = 'https://api.onegov.nsw.gov.au';
  static const String _nswTokenUrl = 'https://api.onegov.nsw.gov.au/oauth/client_credential/accesstoken';

  // NSW OAuth token cache — token is valid ~12 hours, cache it to avoid
  // fetching a new one on every search request
  String? _nswAccessToken;
  DateTime? _nswTokenExpiry;

  // QLD Fuel Prices API Configuration (Official)
  static const String _qldApiBaseUrl = 'https://fppdirectapi-prod.fuelpricesqld.com.au';
  static const String _qldApiToken = '618bcfc9-77eb-456b-9a87-e379fdfec2dc';

  static const Duration _apiTimeout = Duration(seconds: 15);

  // Fuel types
  static final List<FuelType> _defaultFuelTypes = [
    FuelType(code: 'E10', name: 'E10'),
    FuelType(code: 'U91', name: 'Unleaded 91'),
    FuelType(code: 'P95', name: 'Premium 95'),
    FuelType(code: 'P98', name: 'Premium 98'),
    FuelType(code: 'DL', name: 'Diesel'),
    FuelType(code: 'PDL', name: 'Premium Diesel'),
    FuelType(code: 'LPG', name: 'LPG'),
  ];

  Future<List<FuelType>> getFuelTypes() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _defaultFuelTypes;
  }

  String _determineState(double latitude, double longitude) {
    // QLD is roughly between -10 and -29 latitude
    if (latitude > -29 && latitude < -10) {
      return 'QLD';
    }
    // NSW is roughly between -28 and -37 latitude
    else if (latitude >= -37 && latitude <= -28) {
      return 'NSW';
    }
    return 'NSW';
  }

  Future<List<Station>> getNearbyPrices({
    required String fuelType,
    required double latitude,
    required double longitude,
    int radius = 25,
  }) async {
    try {
      final state = _determineState(latitude, longitude);
      print('📍 Location: ($latitude, $longitude)');
      print('📍 Detected state: $state');
      List<Station> stations = [];

      if (state == 'NSW') {
        print('🌐 Fetching from NSW FuelCheck API...');
        stations = await _fetchFromNSWApi(
          fuelType: fuelType,
          latitude: latitude,
          longitude: longitude,
          radius: radius,
        );
      } else if (state == 'QLD') {
        print('🌐 Fetching from QLD Fuel Prices API...');
        stations = await _fetchFromQLDApi(
          fuelType: fuelType,
          latitude: latitude,
          longitude: longitude,
          radius: radius,
        );
      }

      if (stations.isNotEmpty) {
        print('✅ Found ${stations.length} stations within ${radius}km');
      } else {
        print('⚠️ No stations found within ${radius}km');
      }

      return stations;
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // NSW API — OAuth 2.0 + correct endpoints
  // ─────────────────────────────────────────────

  /// Fetch (or return cached) NSW OAuth Bearer token.
  /// Token is valid for ~12 hours; we cache it and only refresh when expired.
  Future<String> _getNSWAccessToken() async {
    // Return cached token if still valid (with 5 min buffer)
    if (_nswAccessToken != null &&
        _nswTokenExpiry != null &&
        DateTime.now().isBefore(_nswTokenExpiry!.subtract(const Duration(minutes: 5)))) {
      print('🔑 Using cached NSW token');
      return _nswAccessToken!;
    }

    print('🔑 Fetching new NSW OAuth token...');

    // Base64 encode "apikey:apisecret" for Basic auth header
    final credentials = base64Encode(utf8.encode('$_nswApiKey:$_nswApiSecret'));

    final response = await http.get(
      Uri.parse('$_nswTokenUrl?grant_type=client_credentials'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/json',
      },
    ).timeout(_apiTimeout);

    print('📡 NSW Token Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('NSW token request failed: ${response.statusCode} — ${response.body}');
    }

    final data = jsonDecode(response.body);
    _nswAccessToken = data['access_token'] as String;

    // expires_in is in seconds (typically 43199 = ~12 hours)
    final expiresIn = int.tryParse(data['expires_in'].toString()) ?? 43199;
    _nswTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

    print('✅ NSW token obtained, expires in ${expiresIn}s');
    return _nswAccessToken!;
  }

  /// Fetch nearby stations from NSW FuelCheck API using correct OAuth flow,
  /// correct base URL, correct endpoint, and correct POST body format.
  Future<List<Station>> _fetchFromNSWApi({
    required String fuelType,
    required double latitude,
    required double longitude,
    int radius = 25,
  }) async {
    // Step 1 — get Bearer token
    final token = await _getNSWAccessToken();

    // Step 2 — build timestamp in required format
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');

    // Step 3 — POST to the nearby endpoint with JSON body
    final url = Uri.parse('$_nswBaseUrl/FuelPriceCheck/v1/fuel/prices/nearby');

    final requestBody = jsonEncode({
      'fueltype': fuelType,
      'latitude': '$latitude',
      'longitude': '$longitude',
      'radius': '$radius',
      'sortby': 'price',
      'ascending': 'true',
    });

    print('📡 NSW API URL: $url');
    print('📡 NSW API Body: $requestBody');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': _nswApiKey,
        'transactionid': DateTime.now().millisecondsSinceEpoch.toString(),
        'requesttimestamp': timestamp,
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: requestBody,
    ).timeout(_apiTimeout);

    print('📡 NSW API Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return _parseNSWResponse(response.body);
    } else {
      throw Exception('NSW API failed: ${response.statusCode} — ${response.body}');
    }
  }

  // ─────────────────────────────────────────────
  // NSW response parser
  // ─────────────────────────────────────────────

  /// Parse the /prices/nearby response.
  /// The API returns: { "stations": [...], "prices": [...] }
  /// Stations hold name/address/location, prices hold the fuel price per station.
  List<Station> _parseNSWResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      print('📦 NSW API Response keys: ${data is Map ? data.keys : "List"}');

      // The /nearby endpoint returns a combined stations+prices structure
      List<dynamic> stationsJson = [];
      List<dynamic> pricesJson = [];

      if (data is Map) {
        // Preferred format: { "stations": [...], "prices": [...] }
        if (data['stations'] != null && data['prices'] != null) {
          stationsJson = data['stations'] as List<dynamic>;
          pricesJson = data['prices'] as List<dynamic>;
          print('📊 NSW: ${stationsJson.length} stations, ${pricesJson.length} prices');
          return _mergeNSWStationsAndPrices(stationsJson, pricesJson);
        }

        // Fallback: flat list under common keys
        final flatList = data['stations'] ??
            data['prices'] ??
            data['results'] ??
            data['data'] ??
            [];
        stationsJson = flatList as List<dynamic>;
      } else if (data is List) {
        stationsJson = data;
      }

      if (stationsJson.isEmpty) {
        print('⚠️ No stations in NSW API response');
        return [];
      }

      // Flat response — each item contains both station and price info
      return _parseNSWFlatList(stationsJson);
    } catch (e) {
      print('❌ Error parsing NSW response: $e');
      return [];
    }
  }

  /// Handle the standard { stations: [...], prices: [...] } response format.
  /// Joins on stationcode.
  List<Station> _mergeNSWStationsAndPrices(
    List<dynamic> stations,
    List<dynamic> prices,
  ) {
    // Build a price lookup map keyed by stationcode
    final priceMap = <String, double>{};
    for (var p in prices) {
      final code = p['stationcode']?.toString() ?? p['servicestationcode']?.toString();
      final price = _parsePrice(p['price']);
      if (code != null && price > 0) {
        priceMap[code] = price;
      }
    }

    List<Station> result = [];
    for (var s in stations) {
      try {
        final code = s['code']?.toString() ?? s['stationcode']?.toString();
        final price = code != null ? (priceMap[code] ?? 0.0) : 0.0;
        if (price <= 0) continue;

        final name = s['name'] ?? s['stationname'] ?? s['tradingname'] ?? 'Unknown Station';
        final address = s['address'] ?? s['location']?['address'] ?? 'Address not available';
        final brand = s['brand'] ?? s['brandname'];

        double lat = 0.0;
        double lng = 0.0;
        if (s['location'] != null) {
          lat = (s['location']['latitude'] ?? 0.0).toDouble();
          lng = (s['location']['longitude'] ?? 0.0).toDouble();
        } else {
          lat = (s['latitude'] ?? s['lat'] ?? 0.0).toDouble();
          lng = (s['longitude'] ?? s['lng'] ?? s['lon'] ?? 0.0).toDouble();
        }

        if (lat == 0.0 || lng == 0.0) continue;

        result.add(Station(
          name: name,
          address: address,
          price: price,
          latitude: lat,
          longitude: lng,
          brand: brand?.toString(),
        ));
      } catch (e) {
        print('⚠️ Error parsing NSW station: $e');
      }
    }

    result.sort((a, b) => a.price.compareTo(b.price));
    print('✅ NSW: parsed ${result.length} valid stations');
    return result;
  }

  /// Handle a flat response where each item has both station + price info.
  List<Station> _parseNSWFlatList(List<dynamic> items) {
    List<Station> result = [];
    for (var json in items) {
      try {
        final station = _parseStation(json);
        if (station.price > 0) result.add(station);
      } catch (e) {
        print('⚠️ Error parsing NSW station (flat): $e');
      }
    }
    result.sort((a, b) => a.price.compareTo(b.price));
    print('✅ NSW: parsed ${result.length} valid stations (flat format)');
    return result;
  }

  Station _parseStation(Map<String, dynamic> json) {
    final name = json['name'] ??
        json['stationname'] ??
        json['tradingname'] ??
        'Unknown Station';

    final address = json['address'] ??
        json['location']?['address'] ??
        'Address not available';

    final brand = json['brand'] ??
        json['brandname'] ??
        json['brandid'];

    double lat = 0.0;
    double lng = 0.0;

    if (json['location'] != null) {
      lat = (json['location']['latitude'] ?? 0.0).toDouble();
      lng = (json['location']['longitude'] ?? 0.0).toDouble();
    } else {
      lat = (json['latitude'] ?? json['lat'] ?? 0.0).toDouble();
      lng = (json['longitude'] ?? json['lng'] ?? json['lon'] ?? 0.0).toDouble();
    }

    final price = _parsePrice(json['price']);
    return Station(
      name: name,
      address: address,
      price: price,
      latitude: lat,
      longitude: lng,
      brand: brand,
    );
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;

    final priceValue = (price is num)
        ? price.toDouble()
        : double.tryParse(price.toString()) ?? 0.0;

    if (priceValue > 100) {
      return priceValue / 100;
    }

    return priceValue;
  }

  // ─────────────────────────────────────────────
  // QLD API — unchanged
  // ─────────────────────────────────────────────

  Future<List<Station>> _fetchFromQLDApi({
    required String fuelType,
    required double latitude,
    required double longitude,
    int radius = 25,
  }) async {
    // QLD API uses a two-step process:
    // 1. Get all sites
    // 2. Get prices for those sites

    print('📡 Step 1: Fetching QLD sites...');
    final sites = await _fetchQLDSites();

    if (sites.isEmpty) {
      print('⚠️ No sites returned from QLD API');
      return [];
    }

    print('📊 Retrieved ${sites.length} QLD sites');

    // Filter sites by distance
    final nearbySites = sites.where((site) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        site['latitude'],
        site['longitude'],
      );
      return distance <= radius;
    }).toList();

    print('📊 Found ${nearbySites.length} sites within ${radius}km');

    if (nearbySites.isEmpty) {
      return [];
    }

    // Get prices for nearby sites
    print('📡 Step 2: Fetching prices...');
    final prices = await _fetchQLDPrices();

    print('📊 Retrieved ${prices.length} price records');

    // Map fuel type to QLD fuel type ID
    final qldFuelTypeId = _mapToQLDFuelTypeId(fuelType);
    print('🔍 Looking for fuel type ID: $qldFuelTypeId');

    // Combine sites with prices
    List<Station> stations = [];

    for (var site in nearbySites) {
      final siteId = site['siteId'];

      // Find price for this site and fuel type
      final priceData = prices.firstWhere(
        (p) => p['siteId'] == siteId && p['fuelId'] == qldFuelTypeId,
        orElse: () => {},
      );

      if (priceData.isEmpty || priceData['price'] == null) {
        continue;
      }

      final priceValue = priceData['price'];

      // Handle price = 9999 (unavailable)
      if (priceValue == 9999 || priceValue == 9999.0) {
        print('  ⚠️ ${site['name']}: Fuel unavailable (price=9999)');
        continue;
      }

      // QLD API returns prices in cents as a decimal (e.g., 1899.0 = 189.9 cents)
      final priceInCents = (priceValue as num).toDouble();

      double price;
      if (priceInCents >= 100) {
        price = priceInCents / 10 / 100;
      } else {
        price = priceInCents / 100;
      }

      print('  💰 Raw price: $priceInCents → Converted: \$${price.toStringAsFixed(3)}/L');

      if (price <= 0 || price > 10) {
        print('  ⚠️ ${site['name']}: Invalid price ${price.toStringAsFixed(2)}');
        continue;
      }

      final distance = _calculateDistance(
        latitude,
        longitude,
        site['latitude'],
        site['longitude'],
      );

      stations.add(Station(
        name: site['name'],
        address: site['address'],
        price: price,
        latitude: site['latitude'],
        longitude: site['longitude'],
        brand: site['brand']?.toString(),
      ));

      print('  ✓ ${site['name']}: ${distance.toStringAsFixed(1)}km - \$${price.toStringAsFixed(2)}/L');
    }

    stations.sort((a, b) => a.price.compareTo(b.price));

    print('✅ Returning ${stations.length} QLD stations with prices');
    print('📊 Price range: ${stations.isNotEmpty ? "\$${stations.first.price.toStringAsFixed(2)} - \$${stations.last.price.toStringAsFixed(2)}/L" : "N/A"}');

    return stations;
  }

  Future<List<Map<String, dynamic>>> _fetchQLDSites() async {
    final url = Uri.parse('$_qldApiBaseUrl/Subscriber/GetFullSiteDetails?countryId=21&geoRegionLevel=3&geoRegionId=1');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'FPDAPI SubscriberToken=$_qldApiToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(_apiTimeout);

    print('📡 QLD Sites API Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('QLD Sites API failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    List<dynamic> sitesList = [];
    if (data is Map && data['S'] != null) {
      sitesList = data['S'] as List<dynamic>;
    } else if (data is List) {
      sitesList = data;
    }

    print('📊 Processing ${sitesList.length} QLD sites');

    List<Map<String, dynamic>> sites = [];

    for (var site in sitesList) {
      try {
        final lat = double.tryParse(site['Lat']?.toString() ?? '0');
        final lng = double.tryParse(site['Lng']?.toString() ?? '0');

        if (lat == null || lng == null || lat == 0 || lng == 0) {
          print('⚠️ Skipping site - no coordinates: ${site['N']}');
          continue;
        }

        sites.add({
          'siteId': site['S'],
          'name': site['N'] ?? 'Unknown Station',
          'address': site['A'] ?? 'Address not available',
          'brand': site['B'],
          'latitude': lat,
          'longitude': lng,
        });

        print('  ✓ Added site: ${site['N']} at ($lat, $lng)');
      } catch (e) {
        print('⚠️ Error parsing site: $e - Site data: $site');
        continue;
      }
    }

    print('📊 Successfully parsed ${sites.length} sites with coordinates');

    return sites;
  }

  Future<List<Map<String, dynamic>>> _fetchQLDPrices() async {
    final url = Uri.parse('$_qldApiBaseUrl/Price/GetSitesPrices?countryId=21&geoRegionLevel=3&geoRegionId=1');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'FPDAPI SubscriberToken=$_qldApiToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(_apiTimeout);

    print('📡 QLD Prices API Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('QLD Prices API failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    print('📊 QLD Prices response type: ${data.runtimeType}');
    print('📦 QLD Prices response keys: ${data is Map ? data.keys : "Not a map"}');

    List<dynamic> pricesList = [];

    if (data is Map && data['SitePrices'] != null) {
      if (data['SitePrices'] is List) {
        pricesList = data['SitePrices'] as List<dynamic>;
      } else {
        pricesList = [data['SitePrices']];
      }
    } else if (data is List) {
      pricesList = data;
    }

    print('📊 Processing ${pricesList.length} price records');

    if (pricesList.isNotEmpty) {
      print('📋 Sample price record: ${pricesList.first}');
    }

    List<Map<String, dynamic>> prices = [];

    for (var priceRecord in pricesList) {
      try {
        prices.add({
          'siteId': priceRecord['SiteId'],
          'fuelId': priceRecord['FuelId'],
          'price': priceRecord['Price'],
        });
      } catch (e) {
        print('⚠️ Error parsing price: $e - Price data: $priceRecord');
        continue;
      }
    }

    print('📊 Successfully parsed ${prices.length} price records');

    return prices;
  }

  int _mapToQLDFuelTypeId(String fuelType) {
    final Map<String, int> fuelMapping = {
      'E10': 12,
      'U91': 2,
      'P95': 5,
      'P98': 8,
      'DL': 3,
      'PDL': 14,
      'LPG': 4,
    };
    return fuelMapping[fuelType] ?? 2;
  }

  Future<Map<int, String>> _fetchQLDFuelTypes() async {
    final url = Uri.parse('$_qldApiBaseUrl/Subscriber/GetCountryFuelTypes?countryId=21');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'FPDAPI SubscriberToken=$_qldApiToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        Map<int, String> fuelTypes = {};

        for (var fuel in data) {
          fuelTypes[fuel['FuelId']] = fuel['Name'];
        }

        print('📋 QLD Fuel Types: $fuelTypes');
        return fuelTypes;
      }
    } catch (e) {
      print('⚠️ Could not fetch QLD fuel types: $e');
    }

    return {};
  }

  // ─────────────────────────────────────────────
  // Shared utilities
  // ─────────────────────────────────────────────

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}