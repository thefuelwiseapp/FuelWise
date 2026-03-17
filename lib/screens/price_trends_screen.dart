import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';

/// Price trends screen showing historical fuel prices (Premium feature)
class PriceTrendsScreen extends StatefulWidget {
  const PriceTrendsScreen({super.key});

  @override
  State<PriceTrendsScreen> createState() => _PriceTrendsScreenState();
}

class _PriceTrendsScreenState extends State<PriceTrendsScreen> {
  String _selectedFuelType = 'U91';
  int _selectedDays = 7;
  List<Map<String, dynamic>> _priceHistory = [];
  bool _isLoading = true;
  
  final List<String> _fuelTypes = ['E10', 'U91', 'P95', 'P98', 'DL'];
  final Map<String, String> _fuelNames = {
    'E10': 'E10',
    'U91': 'Unleaded 91',
    'P95': 'Premium 95',
    'P98': 'Premium 98',
    'DL': 'Diesel',
  };

  @override
  void initState() {
    super.initState();
    _loadPriceHistory();
  }

  Future<void> _loadPriceHistory() async {
    setState(() => _isLoading = true);
    
    // In a real app, this would fetch from an API
    // For now, we'll generate sample data
    await Future.delayed(const Duration(milliseconds: 500));
    
    _priceHistory = _generateSamplePriceHistory();
    
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _generateSamplePriceHistory() {
    final random = Random();
    final basePrices = {
      'E10': 1.75,
      'U91': 1.82,
      'P95': 1.95,
      'P98': 2.05,
      'DL': 1.88,
    };
    
    final basePrice = basePrices[_selectedFuelType] ?? 1.80;
    final List<Map<String, dynamic>> history = [];
    
    final now = DateTime.now();
    for (int i = _selectedDays; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final variation = (random.nextDouble() - 0.5) * 0.15;
      final price = basePrice + variation;
      
      history.add({
        'date': date,
        'price': price,
        'change': i == _selectedDays ? 0.0 : (random.nextDouble() - 0.5) * 0.05,
      });
    }
    
    return history;
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has premium access via Provider
    final subscriptionService = Provider.of<SubscriptionService>(context);
    
    if (!subscriptionService.isPremium) {
      return _buildPaywall();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Trends'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPriceHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fuel type selector
                  _buildFuelTypeSelector(),
                  
                  const SizedBox(height: 16),
                  
                  // Time period selector
                  _buildTimePeriodSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // Price summary
                  _buildPriceSummary(),
                  
                  const SizedBox(height: 24),
                  
                  // Chart
                  _buildPriceChart(),
                  
                  const SizedBox(height: 24),
                  
                  // Insights
                  _buildInsights(),
                ],
              ),
            ),
    );
  }

  Widget _buildPaywall() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Trends'),
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
                  Icons.trending_up,
                  size: 64,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Price Trends',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'View historical fuel prices and predict the best time to fill up.',
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

  Widget _buildFuelTypeSelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _fuelTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final fuelType = _fuelTypes[index];
          final isSelected = fuelType == _selectedFuelType;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFuelType = fuelType);
              _loadPriceHistory();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                _fuelNames[fuelType] ?? fuelType,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    final periods = [7, 14, 30];
    
    return Row(
      children: periods.map((days) {
        final isSelected = days == _selectedDays;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedDays = days);
              _loadPriceHistory();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.green.shade700 
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected 
                      ? Colors.green.shade700 
                      : Colors.grey.shade300,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$days days',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceSummary() {
    if (_priceHistory.isEmpty) return const SizedBox();
    
    final currentPrice = _priceHistory.last['price'] as double;
    final firstPrice = _priceHistory.first['price'] as double;
    final change = currentPrice - firstPrice;
    final percentChange = (change / firstPrice) * 100;
    
    final minPrice = _priceHistory.map((e) => e['price'] as double).reduce(min);
    final maxPrice = _priceHistory.map((e) => e['price'] as double).reduce(max);
    final avgPrice = _priceHistory.map((e) => e['price'] as double).reduce((a, b) => a + b) / _priceHistory.length;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Price',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      '\$${currentPrice.toStringAsFixed(2)}/L',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: change >= 0 ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: change >= 0 ? Colors.red : Colors.green,
                      ),
                      Text(
                        '${percentChange.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: change >= 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Low', '\$${minPrice.toStringAsFixed(2)}', Colors.green),
                _buildStatItem('Avg', '\$${avgPrice.toStringAsFixed(2)}', Colors.orange),
                _buildStatItem('High', '\$${maxPrice.toStringAsFixed(2)}', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceChart() {
    if (_priceHistory.isEmpty) return const SizedBox();
    
    final prices = _priceHistory.map((e) => e['price'] as double).toList();
    final minY = prices.reduce(min) - 0.05;
    final maxY = prices.reduce(max) + 0.05;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.05,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) => Text(
                          '\$${value.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (_selectedDays / 5).ceil().toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _priceHistory.length) {
                            return const Text('');
                          }
                          final date = _priceHistory[index]['date'] as DateTime;
                          return Text(
                            '${date.day}/${date.month}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: _priceHistory.length.toDouble() - 1,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        _priceHistory.length,
                        (i) => FlSpot(i.toDouble(), prices[i]),
                      ),
                      isCurved: true,
                      color: Colors.green.shade600,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.shade100.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights() {
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
                Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInsightItem(
              icon: Icons.trending_down,
              color: Colors.green,
              title: 'Best day to fill up',
              subtitle: 'Prices tend to be lowest on Tuesdays',
            ),
            const Divider(height: 24),
            _buildInsightItem(
              icon: Icons.schedule,
              color: Colors.blue,
              title: 'Price prediction',
              subtitle: 'Prices expected to remain stable this week',
            ),
            const Divider(height: 24),
            _buildInsightItem(
              icon: Icons.savings,
              color: Colors.orange,
              title: 'Potential savings',
              subtitle: 'You could save up to \$5.40 by waiting until Tuesday',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
