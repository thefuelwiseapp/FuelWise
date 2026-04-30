import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Welcome screen shown once on first launch before onboarding.
/// Explains the app concept in 4 swipeable cards.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_WelcomeCard> _cards = [
    _WelcomeCard(
      icon: Icons.local_gas_station,
      title: 'Find the Cheapest Fuel Near You',
      description:
          'FuelWise searches real-time government fuel price data to find the cheapest station in your area — instantly.',
      color: Colors.green.shade700,
    ),
    _WelcomeCard(
      icon: Icons.calculate_outlined,
      title: 'We Calculate the Real Cost',
      description:
          'It\'s not just about price per litre. FuelWise factors in the cost of driving to each station, so you always know the true total cost.',
      color: Colors.teal.shade600,
    ),
    _WelcomeCard(
      icon: Icons.savings_outlined,
      title: 'Track Every Dollar You Save',
      description:
          'Every time you navigate to a station through FuelWise, your savings are recorded automatically so you can see how much you\'ve saved over time.',
      color: Colors.green.shade800,
    ),
    _WelcomeCard(
      icon: Icons.directions_car,
      title: 'Let\'s Set Up Your Vehicle',
      description:
          'Tell us your fuel type, tank size and fuel efficiency so FuelWise can calculate accurate costs just for your car.',
      color: Colors.teal.shade700,
    ),
  ];

  Future<void> _onGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcomeShown', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _cards[_currentPage].color,
              _cards[_currentPage].color.withOpacity(0.85),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _onGetStarted,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _cards.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              card.icon,
                              size: 72,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            card.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            card.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _cards.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Next / Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _cards.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _onGetStarted();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _cards[_currentPage].color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < _cards.length - 1
                          ? 'Next'
                          : 'Set Up My Vehicle',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _WelcomeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}