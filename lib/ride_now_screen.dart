import 'package:flutter/material.dart';

import 'booking_store.dart';
import 'location_picker_screen.dart';
import 'vehicle_selection_screen.dart';

class RideNowScreen extends StatefulWidget {
  const RideNowScreen({
    super.key,
    this.pickup = '',
    this.destination = '',
    this.pickupCoordinates,
    this.destinationCoordinates,
  });

  final String pickup;
  final String destination;
  final TripCoordinates? pickupCoordinates;
  final TripCoordinates? destinationCoordinates;

  @override
  State<RideNowScreen> createState() => _RideNowScreenState();
}

class _RideNowScreenState extends State<RideNowScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController pickupController;
  late final TextEditingController destinationController;

  TripCoordinates? pickupCoordinates;
  TripCoordinates? destinationCoordinates;

  int passengers = 1;

  @override
  void initState() {
    super.initState();

    pickupController = TextEditingController(text: widget.pickup);
    destinationController = TextEditingController(text: widget.destination);

    pickupCoordinates = widget.pickupCoordinates;
    destinationCoordinates = widget.destinationCoordinates;
  }

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> searchLocation({required bool isPickup}) async {
    FocusScope.of(context).unfocus();

    final location = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => LocationPickerScreen(
          title: isPickup ? 'Find pickup' : 'Find destination',
          confirmLabel: isPickup ? 'Use this pickup' : 'Use this destination',
        ),
      ),
    );

    if (!mounted || location == null) return;

    final coordinates = TripCoordinates(
      latitude: location.point.latitude,
      longitude: location.point.longitude,
    );

    setState(() {
      if (isPickup) {
        pickupController.text = location.name;
        pickupCoordinates = coordinates;
      } else {
        destinationController.text = location.name;
        destinationCoordinates = coordinates;
      }
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) return;

    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();

    final pickupPoint = pickupCoordinates;
    final destinationPoint = destinationCoordinates;

    final sameCoordinates =
        pickupPoint != null &&
        destinationPoint != null &&
        pickupPoint.latitude == destinationPoint.latitude &&
        pickupPoint.longitude == destinationPoint.longitude;

    if (pickup.toLowerCase() == destination.toLowerCase() || sameCoordinates) {
      showMessage('Pickup and destination must be different.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: pickupPoint,
          destinationCoordinates: destinationPoint,
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
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
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

  Widget locationSearch({
    required bool isPickup,
    required TripCoordinates? coordinates,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => searchLocation(isPickup: isPickup),
          icon: const Icon(Icons.search),
          label: Text(isPickup ? 'Search pickup' : 'Search destination'),
        ),
        if (coordinates != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Map location selected: '
              '${coordinates.latitude.toStringAsFixed(5)}, '
              '${coordinates.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.teal, fontSize: 12),
            ),
          ),
      ],
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
                    'Search for places or enter your journey details.',
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
                  locationSearch(
                    isPickup: true,
                    coordinates: pickupCoordinates,
                  ),
                  const SizedBox(height: 16),
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
                  locationSearch(
                    isPickup: false,
                    coordinates: destinationCoordinates,
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
