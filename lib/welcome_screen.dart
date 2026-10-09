import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.explore, color: blue, size: 30),
                    SizedBox(width: 10),
                    Text(
                      'TripLanka',
                      style: TextStyle(
                        color: navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                AspectRatio(
                  aspectRatio: 1.12,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE4EEFF), Color(0xFFD5E8E4)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          top: 24,
                          right: 24,
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            size: 56,
                            color: Color(0xFFF1BC55),
                          ),
                        ),
                        const Align(
                          alignment: Alignment(0, 0.1),
                          child: Icon(
                            Icons.landscape_rounded,
                            size: 220,
                            color: Color(0xFF8FB8A7),
                          ),
                        ),
                        const Align(
                          alignment: Alignment(0, 0.62),
                          child: Icon(
                            Icons.directions_car_filled_rounded,
                            size: 128,
                            color: blue,
                          ),
                        ),
                        Positioned(
                          top: 24,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: blue,
                              size: 32,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.route_rounded, color: blue),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Every trip, a new story.',
                                    style: TextStyle(
                                      color: navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Your journey\nstarts here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: navy,
                    fontSize: 36,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Plan trips, find your ride, and explore Sri Lanka.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF738097),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Feature(icon: Icons.local_taxi_outlined, label: 'Rides'),
                    _Feature(icon: Icons.route_outlined, label: 'Day trips'),
                    _Feature(icon: Icons.flight_takeoff, label: 'Airports'),
                  ],
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onGetStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Get started',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onSignIn,
                  child: const Text(
                    'Already have an account? Sign in',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: WelcomeScreen.blue),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: WelcomeScreen.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
