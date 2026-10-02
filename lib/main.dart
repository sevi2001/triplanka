import 'package:flutter/material.dart';
import 'plan_trip_screen.dart';
import 'bookings_screen.dart';
import 'booking_store.dart';
import 'airport_transfer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await BookingStore.load();
    runApp(const TripLankaApp());
  } catch (_) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load saved bookings. '
                  'Please restart the app and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TripLankaApp extends StatelessWidget {
  const TripLankaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripLanka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          HomeScreen(),
          BookingsScreen(),
          SafeArea(child: Center(child: Text('Your profile'))),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final pickupController = TextEditingController();
  final destinationController = TextEditingController();

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  void openBooking(String service) {
    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          if (service == 'Plan a trip') {
            return PlanTripScreen(pickup: pickup, destination: destination);
          }

          if (service == 'Airport transfer') {
            return AirportTransferScreen(
              pickup: pickup,
              destination: destination,
            );
          }

          return BookingScreen(
            service: service,
            pickup: pickup,
            destination: destination,
          );
        },
      ),
    );
  }

  Widget locationField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Row(
                children: [
                  Icon(Icons.explore, size: 32, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'TripLanka',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Where are you going?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Plan your next journey with us.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              locationField(
                label: 'Pickup location',
                icon: Icons.my_location,
                controller: pickupController,
              ),
              const SizedBox(height: 14),
              locationField(
                label: 'Destination',
                icon: Icons.location_on,
                controller: destinationController,
              ),
              const SizedBox(height: 24),
              const Text(
                'Travel options',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ServiceCard(
                title: 'Ride now',
                subtitle: 'Book a nearby driver',
                icon: Icons.local_taxi,
                onTap: () => openBooking('Ride now'),
              ),
              ServiceCard(
                title: 'Plan a trip',
                subtitle: 'Choose your date and stops',
                icon: Icons.calendar_month,
                onTap: () => openBooking('Plan a trip'),
              ),
              ServiceCard(
                title: 'Airport transfer',
                subtitle: 'Book an airport pickup or drop-off',
                icon: Icons.flight,
                onTap: () => openBooking('Airport transfer'),
              ),
              ServiceCard(
                title: 'Full-day driver',
                subtitle: 'Explore with a driver for the day',
                icon: Icons.directions_car,
                onTap: () => openBooking('Full-day driver'),
              ),
              const SizedBox(height: 16),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 56, color: Colors.teal),
                    SizedBox(height: 10),
                    Text('Map placeholder'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Icon(icon, size: 30, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class BookingScreen extends StatelessWidget {
  const BookingScreen({
    super.key,
    required this.service,
    required this.pickup,
    required this.destination,
  });

  final String service;
  final String pickup;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(service)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Journey details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.my_location),
                  title: const Text('Pickup'),
                  subtitle: Text(pickup.isEmpty ? 'Not selected' : pickup),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Destination'),
                  subtitle: Text(
                    destination.isEmpty ? 'Not selected' : destination,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'This service form will be added later. '
                  'Use Plan a trip on Home to create '
                  'a demo booking now.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
