import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Vehicle settings — keys match onboarding and HomeScreen
  String _primaryFuelType = 'U91';
  String _secondaryFuelType = '';
  double _tankSize = 60.0;
  double _fuelEfficiency = 10.0;

  // Preferences
  bool _notificationsEnabled = true;
  String _distanceUnit = 'km';
  String _volumeUnit = 'L';

  bool _isLoading = true;

  final List<Map<String, String>> _fuelTypes = [
    {'code': 'E10', 'name': 'E10'},
    {'code': 'U91', 'name': 'Unleaded 91'},
    {'code': 'P95', 'name': 'Premium 95'},
    {'code': 'P98', 'name': 'Premium 98'},
    {'code': 'DL', 'name': 'Diesel'},
    {'code': 'PDL', 'name': 'Premium Diesel'},
    {'code': 'LPG', 'name': 'LPG'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // Use same keys as onboarding and HomeScreen
        _primaryFuelType = prefs.getString('primaryFuelType') ?? 'U91';
        _secondaryFuelType = prefs.getString('secondaryFuelType') ?? '';
        _tankSize = prefs.getDouble('tankSize') ?? 60.0;
        _fuelEfficiency = prefs.getDouble('fuelEfficiency') ?? 10.0;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _distanceUnit = prefs.getString('distance_unit') ?? 'km';
        _volumeUnit = prefs.getString('volume_unit') ?? 'L';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Use same keys as onboarding and HomeScreen
    await prefs.setString('primaryFuelType', _primaryFuelType);
    await prefs.setString('secondaryFuelType', _secondaryFuelType);
    await prefs.setDouble('tankSize', _tankSize);
    await prefs.setDouble('fuelEfficiency', _fuelEfficiency);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('distance_unit', _distanceUnit);
    await prefs.setString('volume_unit', _volumeUnit);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      // Return true so HomeScreen can refresh
      Navigator.of(context).pop(true);
    }
  }

  void _showSubscriptionScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Subscription status
          _buildSubscriptionCard(subscriptionService),

          const SizedBox(height: 8),

          // Vehicle settings
          _buildSectionHeader('Vehicle Settings'),
          _buildFuelTypeSelector(
            title: 'Primary Fuel Type',
            value: _primaryFuelType,
            includeNone: false,
            onChanged: (v) => setState(() => _primaryFuelType = v ?? 'U91'),
          ),
          _buildFuelTypeSelector(
            title: 'Secondary Fuel Type (fallback)',
            value: _secondaryFuelType.isEmpty ? null : _secondaryFuelType,
            includeNone: true,
            onChanged: (v) => setState(() => _secondaryFuelType = v ?? ''),
          ),
          _buildSliderSetting(
            title: 'Tank Size',
            value: _tankSize,
            min: 20,
            max: 150,
            unit: 'L',
            onChanged: (v) => setState(() => _tankSize = v),
          ),
          _buildSliderSetting(
            title: 'Fuel Efficiency',
            value: _fuelEfficiency,
            min: 3,
            max: 20,
            unit: 'L/100km',
            onChanged: (v) => setState(() => _fuelEfficiency = v),
          ),

          const Divider(height: 32),

          // Preferences
          _buildSectionHeader('Preferences'),
          _buildSwitchSetting(
            title: 'Price Drop Notifications',
            subtitle: subscriptionService.isPremium
                ? 'Get alerts when fuel prices drop'
                : 'Premium feature',
            value: _notificationsEnabled,
            enabled: subscriptionService.isPremium,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),
          _buildUnitSelector(
            title: 'Distance Unit',
            value: _distanceUnit,
            options: const ['km', 'miles'],
            onChanged: (v) => setState(() => _distanceUnit = v!),
          ),
          _buildUnitSelector(
            title: 'Volume Unit',
            value: _volumeUnit,
            options: const ['L', 'gal'],
            onChanged: (v) => setState(() => _volumeUnit = v!),
          ),

          const Divider(height: 32),

          // About
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            onTap: () => _launchUrl(
              'https://app.termly.io/dashboard/website/4a2a4676-fc53-4807-af71-13e4b89d6834/privacy-policy',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Data Sources'),
            subtitle: const Text('NSW FuelCheck & QLD Fuel Prices'),
            trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            onTap: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Data Sources'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fuel price data is sourced from official government APIs:',
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _launchUrl('https://www.fuelcheck.nsw.gov.au'),
                      child: const Text(
                        'NSW FuelCheck\nhttps://www.fuelcheck.nsw.gov.au',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _launchUrl('https://www.fuelpricesqld.com.au'),
                      child: const Text(
                        'QLD Fuel Prices\nhttps://www.fuelpricesqld.com.au',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact Support'),
            subtitle: Text(
              subscriptionService.isPremium
                  ? 'Priority support for Premium users'
                  : 'thefuelwiseapp@gmail.com',
            ),
            onTap: () => _launchUrl('mailto:thefuelwiseapp@gmail.com'),
          ),

          const SizedBox(height: 20),

          // Save button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionService subscriptionService) {
    final isPremium = subscriptionService.isPremium;
    final subscription = subscriptionService.subscription;

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isPremium
                ? [Colors.amber.shade600, Colors.orange.shade700]
                : [Colors.grey.shade400, Colors.grey.shade600],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.star : Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium ? 'Premium Member' : 'Free Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPremium && subscription.expiryDate != null)
                        Text(
                          'Renews ${_formatDate(subscription.expiryDate!)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isPremium)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showSubscriptionScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Upgrade to Premium',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () {},
                child: Text(
                  'Manage Subscription',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.green.shade800,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildFuelTypeSelector({
    required String title,
    required String? value,
    required bool includeNone,
    required ValueChanged<String?> onChanged,
  }) {
    final fuelNames = {
      'E10': 'E10',
      'U91': 'Unleaded 91',
      'P95': 'Premium 95',
      'P98': 'Premium 98',
      'DL': 'Diesel',
      'PDL': 'Premium Diesel',
      'LPG': 'LPG',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: title,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        items: [
          if (includeNone)
            const DropdownMenuItem<String>(
              value: null,
              child: Text('None'),
            ),
          ..._fuelTypes.map((fuel) => DropdownMenuItem<String>(
                value: fuel['code'],
                child: Text(fuelNames[fuel['code']] ?? fuel['code']!),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 2).toInt(),
            activeColor: Colors.green.shade700,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(
        Icons.notifications_outlined,
        color: enabled ? null : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(color: enabled ? null : Colors.grey),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? null : Colors.grey,
          fontStyle: enabled ? FontStyle.normal : FontStyle.italic,
        ),
      ),
      trailing: Switch(
        value: value && enabled,
        onChanged: enabled ? onChanged : null,
        activeColor: Colors.green.shade700,
      ),
    );
  }

  Widget _buildUnitSelector({
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: const Icon(Icons.straighten),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: options
            .map((opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(opt),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}