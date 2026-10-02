import 'package:flutter/material.dart';

import 'airport_transfer_screen.dart';
import 'booking_store.dart';
import 'bookings_screen.dart';
import 'full_day_driver_screen.dart';
import 'home_map.dart';
import 'location_picker_screen.dart';
import 'plan_trip_screen.dart';
import 'profile_screen.dart';
import 'ride_now_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await BookingStore.load();
    runApp(const TripLankaApp());
  } catch (error) {
    debugPrint('Booking load failed: $error');

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
  const TripLankaApp({super.key, this.loadMapTiles = true});

  final bool loadMapTiles;

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
      home: MainScreen(loadMapTiles: loadMapTiles),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.loadMapTiles = true});

  final bool loadMapTiles;

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
        children: [
          HomeScreen(loadMapTiles: widget.loadMapTiles),
          const BookingsScreen(),
          const ProfileScreen(),
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.loadMapTiles = true});

  final bool loadMapTiles;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final pickupController = TextEditingController();
  final destinationController = TextEditingController();

  TripCoordinates? pickupCoordinates;
  TripCoordinates? destinationCoordinates;

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> selectPickupOnMap() async {
    FocusScope.of(context).unfocus();

    final location = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => const LocationPickerScreen(
          title: 'Find pickup',
          confirmLabel: 'Use this pickup',
        ),
      ),
    );

    if (!mounted || location == null) return;

    setState(() {
      pickupController.text = location.name;
      pickupCoordinates = TripCoordinates(
        latitude: location.point.latitude,
        longitude: location.point.longitude,
      );
    });
  }

  Future<void> selectDestinationOnMap() async {
    FocusScope.of(context).unfocus();

    final location = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => const LocationPickerScreen(
          title: 'Find destination',
          confirmLabel: 'Use this destination',
        ),
      ),
    );

    if (!mounted || location == null) return;

    setState(() {
      destinationController.text = location.name;
      destinationCoordinates = TripCoordinates(
        latitude: location.point.latitude,
        longitude: location.point.longitude,
      );
    });
  }

  void openBooking(String service) {
    FocusScope.of(context).unfocus();

    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();

    // Capture the selected coordinates for this booking.
    final selectedPickupCoordinates = pickupCoordinates;
    final selectedDestinationCoordinates = destinationCoordinates;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          if (service == 'Ride now') {
            return RideNowScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
            );
          }

          if (service == 'Plan a trip') {
            return PlanTripScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
            );
          }

          if (service == 'Airport transfer') {
            return AirportTransferScreen(
              pickup: pickup,
              destination: destination,
            );
          }

          if (service == 'Airport transfer') {
            return AirportTransferScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
            );
          }

          if (service == 'Full-day driver') {
            return FullDayDriverScreen(
              pickup: pickup,
              destination: destination,
              pickupCoordinates: selectedPickupCoordinates,
              destinationCoordinates: selectedDestinationCoordinates,
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
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget coordinateLabel(TripCoordinates coordinates) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Map location selected: '
        '${coordinates.latitude.toStringAsFixed(5)}, '
        '${coordinates.longitude.toStringAsFixed(5)}',
        style: const TextStyle(color: Colors.teal, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPickup = pickupCoordinates;
    final selectedDestination = destinationCoordinates;

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
                onChanged: (_) {
                  if (pickupCoordinates == null) return;

                  setState(() {
                    pickupCoordinates = null;
                  });
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: selectPickupOnMap,
                  icon: const Icon(Icons.search),
                  label: const Text('Search pickup'),
                ),
              ),
              if (selectedPickup != null) coordinateLabel(selectedPickup),
              const SizedBox(height: 14),
              locationField(
                label: 'Destination',
                icon: Icons.location_on,
                controller: destinationController,
                onChanged: (_) {
                  if (destinationCoordinates == null) return;

                  setState(() {
                    destinationCoordinates = null;
                  });
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: selectDestinationOnMap,
                  icon: const Icon(Icons.search),
                  label: const Text('Search destination'),
                ),
              ),
              if (selectedDestination != null)
                coordinateLabel(selectedDestination),
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
              const SizedBox(height: 20),
              const Text(
                'Explore the map',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The marker shows Colombo. '
                'Your current location is not connected yet.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              HomeMap(loadTiles: widget.loadMapTiles),
              const SizedBox(height: 16),
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
                  'Choose a travel option from Home '
                  'to create a demo booking.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
