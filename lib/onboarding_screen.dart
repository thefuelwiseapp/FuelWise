import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _primaryFuelType;
  String? _secondaryFuelType;
  double _tankSize = 60.0;
  double _fuelEfficiency = 10.0;
  
  final List<FuelType> _fuelTypes = [
    FuelType(code: 'E10', name: 'E10'),
    FuelType(code: 'U91', name: 'Unleaded 91'),
    FuelType(code: 'P95', name: 'Premium 95'),
    FuelType(code: 'P98', name: 'Premium 98'),
    FuelType(code: 'DL', name: 'Diesel'),
    FuelType(code: 'PDL', name: 'Premium Diesel'),
    FuelType(code: 'LPG', name: 'LPG'),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingSettings();
  }

  Future<void> _loadExistingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _primaryFuelType = prefs.getString('primaryFuelType');
      _secondaryFuelType = prefs.getString('secondaryFuelType');
      _tankSize = prefs.getDouble('tankSize') ?? 60.0;
      _fuelEfficiency = prefs.getDouble('fuelEfficiency') ?? 10.0;
    });
  }

  Future<void> _saveAndContinue() async {
    if (_formKey.currentState!.validate()) {
      if (_primaryFuelType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a primary fuel type')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('primaryFuelType', _primaryFuelType!);
      await prefs.setString('secondaryFuelType', _secondaryFuelType ?? '');
      await prefs.setDouble('tankSize', _tankSize);
      await prefs.setDouble('fuelEfficiency', _fuelEfficiency);
      await prefs.setBool('onboardingComplete', true);

      print('💾 Saved settings: $_primaryFuelType, ${_tankSize}L, ${_fuelEfficiency}L/100km');

      if (mounted) {
        // Pop back to home screen if we came from settings
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditingSettings = Navigator.of(context).canPop();
    
    return Scaffold(
      appBar: isEditingSettings
          ? AppBar(
              title: const Text('Vehicle Settings'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isEditingSettings) ...[
                  const SizedBox(height: 32),
                  // App logo/icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      size: 56,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'FuelWise',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Find the cheapest fuel station near you — instantly.\n'
                    'FuelWise calculates the real cost to fill up, including the drive,\n'
                    'so you always know which station saves you the most money.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Let\'s set up your vehicle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                
                if (isEditingSettings)
                  Text(
                    'Update your vehicle details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Primary Fuel Type
                Text(
                  'Primary Fuel Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _primaryFuelType,
                  decoration: InputDecoration(
                    hintText: 'Select your fuel type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: _fuelTypes.map((fuel) {
                    return DropdownMenuItem(
                      value: fuel.code,
                      child: Text(fuel.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _primaryFuelType = value;
                    });
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Secondary Fuel Type
                Text(
                  'Secondary Fuel Type (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fallback if primary isn\'t available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _secondaryFuelType,
                  decoration: InputDecoration(
                    hintText: 'Select fallback fuel type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    ..._fuelTypes.map((fuel) {
                      return DropdownMenuItem(
                        value: fuel.code,
                        child: Text(fuel.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _secondaryFuelType = value;
                    });
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Tank Size
                Text(
                  'Tank Size',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_tankSize.toStringAsFixed(0)} litres',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (_tankSize > 10) _tankSize -= 5;
                                  });
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (_tankSize < 300) _tankSize += 5;
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Slider(
                        value: _tankSize,
                        min: 20,
                        max: 300,
                        divisions: 56,
                        onChanged: (value) {
                          setState(() {
                            _tankSize = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Fuel Efficiency
                Text(
                  'Fuel Efficiency',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_fuelEfficiency.toStringAsFixed(1)} L/100km',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (_fuelEfficiency > 2) _fuelEfficiency -= 0.5;
                                  });
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _fuelEfficiency += 0.5;
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Slider(
                        value: _fuelEfficiency,
                        min: 4,
                        max: 20,
                        divisions: 32,
                        onChanged: (value) {
                          setState(() {
                            _fuelEfficiency = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Save Button
                ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isEditingSettings ? 'Save Settings' : 'Get Started',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'You can always change this in Settings',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}