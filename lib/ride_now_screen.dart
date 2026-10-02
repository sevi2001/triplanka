import 'package:flutter/material.dart';
import 'vehicle_selection_screen.dart';

class RideNowScreen extends StatefulWidget {
  const RideNowScreen({super.key, this.pickup = '', this.destination = ''});

  final String pickup;
  final String destination;

  @override
  State<RideNowScreen> createState() => _RideNowScreenState();
}

class _RideNowScreenState extends State<RideNowScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController pickupController;
  late final TextEditingController destinationController;

  int passengers = 1;

  @override
  void initState() {
    super.initState();

    pickupController = TextEditingController(text: widget.pickup);

    destinationController = TextEditingController(text: widget.destination);
  }

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) return;

    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();

    if (pickup.toLowerCase() == destination.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup and destination must be different.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: pickup,
          destination: destination,
          stops: const [],
          departure: DateTime.now(),
          passengers: passengers,
          notes: 'Instant ride demo request',
          isInstantRide: true,
        ),
      ),
    );
  }

  Widget locationField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Enter a location';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride now')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.local_taxi, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'Where would you like to go?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your journey details.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  locationField(
                    label: 'Pickup location',
                    icon: Icons.my_location,
                    controller: pickupController,
                  ),
                  const SizedBox(height: 16),
                  locationField(
                    label: 'Destination',
                    icon: Icons.location_on,
                    controller: destinationController,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.teal),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Passengers')),
                          IconButton(
                            tooltip: 'Fewer passengers',
                            onPressed: passengers > 1
                                ? () {
                                    setState(() {
                                      passengers--;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '$passengers',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            tooltip: 'More passengers',
                            onPressed: passengers < 15
                                ? () {
                                    setState(() {
                                      passengers++;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Demo only. Nearby drivers, live tracking, '
                    'and fare estimates are not connected yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: continueBooking,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text('Choose vehicle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
