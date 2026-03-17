import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'fuel_service.dart';
import 'models.dart';
import 'onboarding_screen.dart';
import 'savings_tracker_screen.dart';

// Monetization & Screens
import 'services/ad_service.dart';
import 'services/subscription_service.dart';
import 'screens/settings_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/price_trends_screen.dart';
import 'screens/price_alerts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Mobile Ads SDK
  await MobileAds.instance.initialize();
  
  // Load subscription status
  await SubscriptionService().loadCachedStatus();
  
  runApp(const FuelWiseApp());
}

class FuelWiseApp extends StatelessWidget {
  const FuelWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        ChangeNotifierProvider(create: (_) => AdService()),
      ],
      child: MaterialApp(
        title: 'FuelWise',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/subscription': (context) => const SubscriptionScreen(),
          '/price_trends': (context) => const PriceTrendsScreen(),
          '/price_alerts': (context) => const PriceAlertsScreen(),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    try {
      await SubscriptionService().initialize();
      await AdService().initialize();
    } catch (e) {
      debugPrint('Service initialization error: $e');
    }
    
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    
    if (mounted) {
      if (onboardingComplete) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade700, Colors.green.shade900],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_gas_station,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'FuelWise',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Save money on every fill',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FuelService _fuelService = FuelService();
  GoogleMapController? _mapController;
  
  String _primaryFuelType = 'U91';
  String _secondaryFuelType = '';
  double _tankSize = 60.0;
  double _fuelEfficiency = 10.0;
  
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _showMapView = false;

  // Results — now shows ALL stations, not just top 3
  List<StationResult> _allResults = [];
  StationResult? _nearestStation;
  double _savingsVsNearest = 0.0;
  
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getCurrentLocation();
  }

  // Reload settings when returning from Settings screen
  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (result == true) {
      await _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _primaryFuelType = prefs.getString('primaryFuelType') ?? 'U91';
        _secondaryFuelType = prefs.getString('secondaryFuelType') ?? '';
        _tankSize = prefs.getDouble('tankSize') ?? 60.0;
        _fuelEfficiency = prefs.getDouble('fuelEfficiency') ?? 10.0;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Please enable location services');
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied. Enable in settings.');
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        _updateMapCamera();
      }
    } catch (e) {
      debugPrint('Location error: $e');
      _showError('Could not get location');
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _updateMapCamera() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  Future<void> _findCheapestFuelWithAd() async {
    final adService = Provider.of<AdService>(context, listen: false);
    await _findCheapestFuel();
    if (_allResults.isNotEmpty) {
      await adService.onSearchComplete();
    }
  }

  Future<void> _findCheapestFuel() async {
    if (_currentPosition == null) {
      if (_isLoadingLocation) {
        _showError('Getting your location…');
        return;
      }
      _showError('Location not available');
      await _getCurrentLocation();
      if (_currentPosition == null) return;
    }

    final fuelLevel = await _showFuelLevelDialog();
    if (fuelLevel == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _allResults = [];
        _nearestStation = null;
        _savingsVsNearest = 0.0;
        _markers = {};
      });
    }

    try {
      final stations = await _fuelService.getNearbyPrices(
        fuelType: _primaryFuelType,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radius: 25,
      );

      if (stations.isEmpty && _secondaryFuelType.isNotEmpty) {
        final secondaryStations = await _fuelService.getNearbyPrices(
          fuelType: _secondaryFuelType,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radius: 25,
        );
        stations.addAll(secondaryStations);
      }

      if (stations.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _showError('No stations found within 25km.');
        return;
      }

      final currentFuelLitres = (fuelLevel / 100) * _tankSize;
      final fuelNeeded = _tankSize - currentFuelLitres;

      List<StationResult> results = [];

      for (var station in stations) {
        final distanceKm = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          station.latitude,
          station.longitude,
        );

        final fuelUsedForTrip = (distanceKm * _fuelEfficiency) / 100;
        final drivingCost = fuelUsedForTrip * station.price;
        final fillUpCost = fuelNeeded * station.price;
        final totalCost = fillUpCost + drivingCost;

        results.add(StationResult(
          station: station,
          distance: distanceKm,
          fillUpCost: fillUpCost,
          drivingCost: drivingCost,
          totalCost: totalCost,
        ));
      }

      // Keep all within 20km, sorted by total cost
      results = results.where((r) => r.distance <= 20).toList();

      if (results.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        _showError('No stations found within 20km.');
        return;
      }

      // Find nearest station (for comparison baseline)
      results.sort((a, b) => a.distance.compareTo(b.distance));
      final nearest = results.first;

      // Sort by total cost
      results.sort((a, b) => a.totalCost.compareTo(b.totalCost));
      final savings = nearest.totalCost - results.first.totalCost;

      // Build map markers
      final newMarkers = <Marker>{};

      // User location marker (blue)
      newMarkers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));

      // Station markers
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        final isNearest = r.station.name == nearest.station.name &&
            r.station.address == nearest.station.address;
        final isCheapest = i < 3;

        // Orange = nearest (if not also cheapest), Green = top 3 cheapest, Red = others
        double hue;
        if (isNearest && !isCheapest) {
          hue = BitmapDescriptor.hueOrange;
        } else if (isCheapest) {
          hue = BitmapDescriptor.hueGreen;
        } else {
          hue = BitmapDescriptor.hueRed;
        }

        final int rank = i;
        final StationResult stationResult = r;
        newMarkers.add(Marker(
          markerId: MarkerId('station_$i'),
          position: LatLng(r.station.latitude, r.station.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: r.station.name,
            snippet: '\$${r.station.price.toStringAsFixed(2)}/L · ${r.distance.toStringAsFixed(1)}km',
          ),
          onTap: () => _showStationDetails(context, stationResult, rank),
        ));
      }

      if (mounted) {
        setState(() {
          _allResults = results;
          _nearestStation = nearest;
          _savingsVsNearest = savings < 0 ? 0 : savings;
          _markers = newMarkers;
          _isLoading = false;
          _showMapView = false; // Default to list view
        });

        // Zoom map to show results
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              13,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Failed to find stations: ${e.toString()}');
    }
  }

  Future<double?> _showFuelLevelDialog() async {
    double fuelLevel = 25.0;

    return showDialog<double>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildFuelButton(String label, double value) {
              final isSelected = (value - fuelLevel).abs() < 1;
              return InkWell(
                onTap: () => setDialogState(() => fuelLevel = value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade700 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Current Fuel Level'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(fuelLevel / 100).toStringAsFixed(2)} tank',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildFuelButton('Empty', 0),
                      buildFuelButton('1/4', 25),
                      buildFuelButton('1/2', 50),
                      buildFuelButton('3/4', 75),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: fuelLevel,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${fuelLevel.toInt()}%',
                    activeColor: Colors.green,
                    onChanged: (value) => setDialogState(() => fuelLevel = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(fuelLevel),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  child: const Text('Find Fuel', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows popup with station details + navigate button
  void _showStationDetails(BuildContext context, StationResult result, int rank) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: rank == 0 ? Colors.green.shade700 : Colors.green.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (rank < 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            rank == 0 ? '🏆 Best Value' : '#${rank + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '\$${result.station.price.toStringAsFixed(2)}/L',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.station.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    result.station.address,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _detailRow(Icons.speed, 'Distance', '${result.distance.toStringAsFixed(1)} km away'),
                  const Divider(),
                  _detailRow(Icons.local_gas_station, 'Fill-up cost', '\$${result.fillUpCost.toStringAsFixed(2)}'),
                  const Divider(),
                  _detailRow(Icons.directions_car, 'Driving cost', '\$${result.drivingCost.toStringAsFixed(2)}'),
                  const Divider(),
                  _detailRow(Icons.attach_money, 'Total cost', '\$${result.totalCost.toStringAsFixed(2)}',
                      highlight: true),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _navigateToStation(result);
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate There',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              fontSize: highlight ? 17 : 15,
              color: highlight ? Colors.green.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToStation(StationResult result) async {
    final lat = result.station.latitude;
    final lng = result.station.longitude;
    final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng');
    final webMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        await launchUrl(webMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showError('Could not open navigation');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  String _getFuelTypeName(String code) {
    const fuelNames = {
      'E10': 'E10', 'U91': 'Unleaded 91', 'P95': 'Premium 95',
      'P98': 'Premium 98', 'DL': 'Diesel', 'PDL': 'Premium Diesel', 'LPG': 'LPG',
    };
    return fuelNames[code] ?? code;
  }

  bool get _hasResults => _allResults.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final adService = Provider.of<AdService>(context);
    final isPremium = subscriptionService.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('FuelWise', style: TextStyle(fontWeight: FontWeight.bold)),
            if (isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('PRO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.green.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'Price Trends',
            onPressed: () => Navigator.pushNamed(context, '/price_trends'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Price Alerts',
            onPressed: () => Navigator.pushNamed(context, '/price_alerts'),
          ),
          IconButton(
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Savings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SavingsTrackerScreen()),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                _openSettings();
              } else if (value == 'subscription') {
                Navigator.pushNamed(context, '/subscription');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(leading: Icon(Icons.settings), title: Text('Settings')),
              ),
              PopupMenuItem<String>(
                value: 'subscription',
                child: ListTile(
                  leading: Icon(isPremium ? Icons.star : Icons.star_border, color: Colors.amber),
                  title: Text(isPremium ? 'Manage Subscription' : 'Upgrade to PRO'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Ad (free users only)
            if (adService.shouldShowAds && adService.isBannerAdLoaded)
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 50,
                color: Colors.grey.shade100,
                child: adService.getBannerAdWidget(),
              ),

            // ── RESULTS STATE: compact header ──
            if (_hasResults)
              _buildResultsHeader(),

            // ── NO RESULTS: vehicle info card ──
            if (!_hasResults)
              _buildVehicleInfoCard(),

            // ── Loading location indicator ──
            if (_isLoadingLocation && !_hasResults)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text('Getting your location…',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),

            // ── Find Fuel Button (only when no results) ──
            if (!_hasResults)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _findCheapestFuelWithAd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 60),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_gas_station, size: 26),
                            SizedBox(width: 12),
                            Text('Find Cheapest Fuel',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),

            // ── Main content area ──
            Expanded(
              child: _hasResults
                  ? _buildResultsContent() // List or Map toggle
                  : _buildHomeMapPreview(), // Map preview with location
            ),
          ],
        ),
      ),
    );
  }

  // ── Vehicle info card (shown when no results) ──
  Widget _buildVehicleInfoCard() {
    return GestureDetector(
      onTap: _openSettings,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.directions_car, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_getFuelTypeName(_primaryFuelType)} · ${_tankSize.toInt()}L · ${_fuelEfficiency.toStringAsFixed(1)}L/100km',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.edit_outlined, color: Colors.grey[500], size: 16),
          ],
        ),
      ),
    );
  }

  // ── Compact header shown after search ──
  Widget _buildResultsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.local_gas_station, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_allResults.length} station${_allResults.length == 1 ? '' : 's'} found',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green.shade900),
                ),
                if (_savingsVsNearest > 0.01)
                  Text(
                    'Save \$${_savingsVsNearest.toStringAsFixed(2)} vs nearest',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _allResults = [];
                _nearestStation = null;
                _savingsVsNearest = 0.0;
                _markers = {};
                _showMapView = false;
              });
            },
            icon: const Icon(Icons.search, size: 16),
            label: const Text('New Search'),
            style: TextButton.styleFrom(foregroundColor: Colors.green.shade800),
          ),
        ],
      ),
    );
  }

  // ── Map preview on home (before search) — shows user location ──
  Widget _buildHomeMapPreview() {
    if (_currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_searching, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Waiting for location…',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final userPos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.zero),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: userPos, zoom: 14),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        mapType: MapType.normal,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        markers: {
          Marker(
            markerId: const MarkerId('user_location'),
            position: userPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        },
      ),
    );
  }

  // ── Results content: List/Map toggle ──
  Widget _buildResultsContent() {
    return Column(
      children: [
        // List / Map tab toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showMapView = false),
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text('List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_showMapView ? Colors.green.shade700 : Colors.grey[200],
                    foregroundColor: !_showMapView ? Colors.white : Colors.grey[700],
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showMapView = true),
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showMapView ? Colors.green.shade700 : Colors.grey[200],
                    foregroundColor: _showMapView ? Colors.white : Colors.grey[700],
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _showMapView ? _buildMapResults() : _buildListResults(),
        ),
      ],
    );
  }

  // ── List of all results — tap to see details popup ──
  Widget _buildListResults() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _allResults.length,
      itemBuilder: (context, index) {
        final result = _allResults[index];
        final isNearest = _nearestStation != null &&
            result.station.name == _nearestStation!.station.name &&
            result.station.address == _nearestStation!.station.address;
        final isBestValue = index == 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: isBestValue ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isBestValue
                ? BorderSide(color: Colors.green.shade400, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showStationDetails(context, result, index),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isBestValue ? Colors.green.shade700 : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isBestValue
                        ? const Icon(Icons.star, color: Colors.white, size: 20)
                        : Text(
                            '#${index + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                fontSize: 12),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Station info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                result.station.name,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isNearest)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Nearest',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        Text(
                          '${result.distance.toStringAsFixed(1)} km · '
                          '\$${result.station.price.toStringAsFixed(2)}/L',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  // Total cost
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${result.totalCost.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800),
                      ),
                      Text('total',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Map with markers + legend ──
  Widget _buildMapResults() {
    if (_currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 13,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            _updateMapCamera();
          },
        ),
        // Map legend overlay
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendItem(Colors.blue, 'You'),
                const SizedBox(height: 4),
                _legendItem(Colors.green, 'Cheapest (top 3)'),
                const SizedBox(height: 4),
                _legendItem(Colors.orange, 'Nearest station'),
                const SizedBox(height: 4),
                _legendItem(Colors.red, 'Other stations'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}