import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';

/// Price alerts configuration screen (Premium feature)
class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  bool _alertsEnabled = true;
  double _priceThreshold = 1.80;
  List<String> _selectedFuelTypes = ['U91'];
  List<Map<String, dynamic>> _alertHistory = [];
  bool _isLoading = true;
  
  final List<String> _allFuelTypes = ['E10', 'U91', 'P95', 'P98', 'DL', 'LPG'];
  final Map<String, String> _fuelNames = {
    'E10': 'E10',
    'U91': 'Unleaded 91',
    'P95': 'Premium 95',
    'P98': 'Premium 98',
    'DL': 'Diesel',
    'LPG': 'LPG',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _alertsEnabled = prefs.getBool('price_alerts_enabled') ?? true;
      _priceThreshold = prefs.getDouble('price_alert_threshold') ?? 1.80;
      _selectedFuelTypes = prefs.getStringList('price_alert_fuel_types') ?? ['U91'];
      
      // Load alert history
      final historyJson = prefs.getString('price_alert_history') ?? '[]';
      _alertHistory = List<Map<String, dynamic>>.from(
        jsonDecode(historyJson).map((e) => Map<String, dynamic>.from(e)),
      );
      
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('price_alerts_enabled', _alertsEnabled);
    await prefs.setDouble('price_alert_threshold', _priceThreshold);
    await prefs.setStringList('price_alert_fuel_types', _selectedFuelTypes);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert settings saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    // Check if user has premium access
    if (!subscriptionService.isPremium) {
      return _buildPaywall();
    }
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Price Alerts')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Alerts'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable switch
            _buildEnableCard(),
            
            const SizedBox(height: 16),
            
            // Price threshold
            if (_alertsEnabled) ...[
              _buildThresholdCard(),
              
              const SizedBox(height: 16),
              
              // Fuel types
              _buildFuelTypesCard(),
              
              const SizedBox(height: 24),
              
              // Alert history
              _buildAlertHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaywall() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Alerts'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active,
                  size: 64,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Price Alerts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Get notified when fuel prices drop below your target price.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Unlock with Premium',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnableCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _alertsEnabled 
                ? Colors.green.shade100 
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.notifications,
            color: _alertsEnabled ? Colors.green.shade700 : Colors.grey,
          ),
        ),
        title: const Text(
          'Price Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _alertsEnabled 
              ? 'You\'ll be notified when prices drop'
              : 'Alerts are disabled',
        ),
        trailing: Switch(
          value: _alertsEnabled,
          onChanged: (v) => setState(() => _alertsEnabled = v),
          activeThumbColor: Colors.green.shade700,
        ),
      ),
    );
  }

  Widget _buildThresholdCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Alert Threshold',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Notify me when price drops below:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _priceThreshold,
                    min: 1.40,
                    max: 2.50,
                    divisions: 110,
                    activeColor: Colors.green.shade700,
                    onChanged: (v) => setState(() => _priceThreshold = v),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '\$${_priceThreshold.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTypesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_gas_station, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Fuel Types to Monitor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allFuelTypes.map((type) {
                final isSelected = _selectedFuelTypes.contains(type);
                return FilterChip(
                  label: Text(_fuelNames[type] ?? type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedFuelTypes.add(type);
                      } else if (_selectedFuelTypes.length > 1) {
                        _selectedFuelTypes.remove(type);
                      }
                    });
                  },
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green.shade700,
                  labelStyle: TextStyle(
                    color: isSelected 
                        ? Colors.green.shade800 
                        : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Alerts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.grey.shade800,
              ),
            ),
            if (_alertHistory.isNotEmpty)
              TextButton(
                onPressed: _clearHistory,
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_alertHistory.isEmpty)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No alerts yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'You\'ll see price drop notifications here',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...(_alertHistory.take(10).map((alert) => _buildAlertItem(alert))),
      ],
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final date = DateTime.tryParse(alert['date'] ?? '') ?? DateTime.now();
    final fuelType = alert['fuelType'] ?? 'U91';
    final price = alert['price'] ?? 0.0;
    final station = alert['station'] ?? 'Unknown Station';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.trending_down,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(
          '\$${price.toStringAsFixed(2)}/L for ${_fuelNames[fuelType] ?? fuelType}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$station\n${_formatDate(date)}'),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all alert history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('price_alert_history', '[]');
      setState(() => _alertHistory = []);
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }
}
