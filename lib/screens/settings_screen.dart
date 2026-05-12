import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';
import '../models.dart';

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

  List<String> _selectedCardIds = [];

  // Preferences
  bool _notificationsEnabled = true;
  String _distanceUnit = 'km';
  String _volumeUnit = 'L';

  bool _isLoading = true;
  String _appVersion = '';

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
    // Load app version from pubspec
    final packageInfo = await PackageInfo.fromPlatform();

    if (mounted) {
      setState(() {
        // Use same keys as onboarding and HomeScreen
        _primaryFuelType = prefs.getString('primaryFuelType') ?? 'U91';
        _secondaryFuelType = prefs.getString('secondaryFuelType') ?? '';
        _tankSize = prefs.getDouble('tankSize') ?? 60.0;
        _fuelEfficiency = prefs.getDouble('fuelEfficiency') ?? 10.0;
        _selectedCardIds = prefs.getStringList('loyaltyCardIds') ?? [];
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _distanceUnit = prefs.getString('distance_unit') ?? 'km';
        _volumeUnit = prefs.getString('volume_unit') ?? 'L';
        _appVersion = packageInfo.version;
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
    await prefs.setStringList('loyaltyCardIds', _selectedCardIds);
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
            max: 300,
            unit: 'L',
            displayValue: '${_tankSize.toStringAsFixed(0)} L',
            divisions: 56,
            onDecrement: () => setState(() { if (_tankSize > 20) _tankSize -= 5; }),
            onIncrement: () => setState(() { if (_tankSize < 300) _tankSize += 5; }),
            onChanged: (v) => setState(() => _tankSize = v),
          ),
          _buildSliderSetting(
            title: 'Fuel Efficiency',
            value: _fuelEfficiency,
            min: 3,
            max: 20,
            unit: 'L/100km',
            displayValue: '${_fuelEfficiency.toStringAsFixed(1)} L/100km',
            divisions: 34,
            onDecrement: () => setState(() { if (_fuelEfficiency > 3) _fuelEfficiency -= 0.5; }),
            onIncrement: () => setState(() { if (_fuelEfficiency < 20) _fuelEfficiency += 0.5; }),
            onChanged: (v) => setState(() => _fuelEfficiency = v),
          ),

          const Divider(height: 32),

          // ── Loyalty Card ──
          _buildSectionHeader('Loyalty Card'),
          _buildLoyaltyCardSelector(),

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
            subtitle: Text(_appVersion.isNotEmpty ? _appVersion : '—'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            onTap: () => _launchUrl(
              'https://thefuelwiseapp.github.io/FuelWise/privacy-policy.html',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.orange),
            title: const Text('Disclaimer'),
            subtitle: const Text(
              'FuelWise is an independent app and is not affiliated with, '
              'endorsed by, or representing any government entity. '
              'Fuel price data is sourced from official government APIs.',
            ),
            isThreeLine: true,
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

  Widget _buildLoyaltyCardSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select all cards you carry — discounts apply automatically at eligible stations.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ...LoyaltyCard.all.map((card) {
            final isSelected = _selectedCardIds.contains(card.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedCardIds.add(card.id);
                    } else {
                      _selectedCardIds.remove(card.id);
                    }
                  });
                },
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: card.badgeColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        card.badgeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: card.id == 'nrma'
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        card.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  card.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                activeColor: Colors.green.shade700,
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }),
          if (_selectedCardIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_selectedCardIds.length} card${_selectedCardIds.length == 1 ? '' : 's'} selected — best discount applied per station',
                style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontStyle: FontStyle.italic),
              ),
            ),
        ],
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
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    int? divisions,
    String? displayValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayValue ?? '${value.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: onDecrement,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.green.shade700,
                    ),
                    IconButton(
                      onPressed: onIncrement,
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ?? ((max - min) * 2).toInt(),
              activeColor: Colors.green.shade700,
              onChanged: onChanged,
            ),
          ],
        ),
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