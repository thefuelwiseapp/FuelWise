import 'package:flutter_test/flutter_test.dart';
import 'package:fuelwise/fuel_service.dart';

void main() {
  test('FuelService QLD Integration Test', () async {
    final fuelService = FuelService();
    
    print('Testing FuelService with QLD coordinates...');
    
    // Coordinates for Brisbane CBD
    const double lat = -27.4705;
    const double lng = 153.0260;
    
    try {
      // Test Unleaded 91
      print('\n--- Fetching U91 prices for Brisbane ---');
      final stations = await fuelService.getNearbyPrices(
        fuelType: 'U91',
        latitude: lat,
        longitude: lng,
        radius: 5,
      );
      
      print('Found ${stations.length} stations');
      
      if (stations.isNotEmpty) {
        print('✅ Success! First result:');
        print('  Name: ${stations.first.name}');
        print('  Price: \$${stations.first.price}');
        print('  Address: ${stations.first.address}');
        
        expect(stations.first.price, greaterThan(1.0));
        expect(stations.first.price, lessThan(3.0));
      } else {
        print('⚠️ No stations found. This might be valid if no stations are nearby, but unexpected for CBD.');
      }
      
      // Test E10 (previously broken)
      print('\n--- Fetching E10 prices for Brisbane ---');
      final e10Stations = await fuelService.getNearbyPrices(
        fuelType: 'E10',
        latitude: lat,
        longitude: lng,
        radius: 5,
      );
      
      print('Found ${e10Stations.length} E10 stations');
       if (e10Stations.isNotEmpty) {
        print('✅ Success! First E10 result:');
        print('  Name: ${e10Stations.first.name}');
        print('  Price: \$${e10Stations.first.price}');
      }

    } catch (e) {
      print('❌ Error: $e');
      fail('FuelService failed: $e');
    }
  });
}
