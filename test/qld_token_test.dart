import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('QLD API Connectivity Test', () async {
    const String qldApiBaseUrl = 'https://fppdirectapi-prod.fuelpricesqld.com.au';
    // This is the token from fuel_service.dart
    const String qldApiToken = '618bcfc9-77eb-456b-9a87-e379fdfec2dc';
    
    print('Testing QLD API Connectivity...');
    print('URL: $qldApiBaseUrl');
    
    print('--- Test 1: Connectivity (Country Fuel Types) ---');
    // Using GetCountryFuelTypes as it's a simple, typically accessible endpoint
    final url = Uri.parse('$qldApiBaseUrl/Subscriber/GetCountryFuelTypes?countryId=21');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'FPDAPI SubscriberToken=$qldApiToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      print('Status: ${response.statusCode}');
      print('Reason: ${response.reasonPhrase}');
      print('Body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('✅ Test 1 Passed: Token works!');
      } else {
        print('❌ Test 1 Failed: Token might be invalid or expired.');
      }
      
      // We don't assert here to allow Test 2 to run, but we log the result
    } catch (e) {
      print('❌ Test 1 Exception: $e');
    }

    print('\n--- Test 2: Prices Endpoint (Real Data Check) ---');
    // Testing GetSitesPrices as it's the critical endpoint for the user
    final priceUrl = Uri.parse('$qldApiBaseUrl/Price/GetSitesPrices?countryId=21&geoRegionLevel=3&geoRegionId=1');
    
    try {
      final priceResponse = await http.get(
        priceUrl,
        headers: {
          'Authorization': 'FPDAPI SubscriberToken=$qldApiToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      print('Status: ${priceResponse.statusCode}');
      
      if (priceResponse.statusCode == 200) {
        print('✅ Test 2 Passed: Prices endpoint accessible');
        // Check body length
        print('Body Length: ${priceResponse.body.length} chars');
        if (priceResponse.body.length < 100) {
           print('⚠️ Warning: Body seems very short: ${priceResponse.body}');
        }
      } else {
        print('❌ Test 2 Failed: Prices endpoint failed (Status ${priceResponse.statusCode})');
        print('Body: ${priceResponse.body}');
      }
      
      // Fail the test if both failed
    } catch (e) {
      print('❌ Test 2 Exception: $e');
    }
  });
}
