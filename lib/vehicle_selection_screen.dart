import 'package:flutter/material.dart';

import 'booking_store.dart';

class VehicleOption {
  const VehicleOption({
    required this.name,
    required this.capacity,
    required this.icon,
  });

  final String name;
  final int capacity;
  final IconData icon;
}

class VehicleSelectionScreen extends StatefulWidget {
  const VehicleSelectionScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.stops,
    required this.departure,
    required this.passengers,
    this.notes = '',
    this.isInstantRide = false,
    this.pickupCoordinates,
    this.destinationCoordinates,
    this.stopCoordinates,
  }) : assert(
         stopCoordinates == null || stopCoordinates.length == stops.length,
       );

  final String pickup;
  final String destination;
  final List<String> stops;
  final DateTime departure;
  final int passengers;
  final String notes;
  final bool isInstantRide;

  final TripCoordinates? pickupCoordinates;
  final TripCoordinates? destinationCoordinates;
  final List<TripCoordinates?>? stopCoordinates;

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  static const vehicles = [
    VehicleOption(name: 'Tuk-tuk', capacity: 3, icon: Icons.electric_rickshaw),
    VehicleOption(name: 'Car', capacity: 4, icon: Icons.directions_car),
    VehicleOption(name: 'Van', capacity: 8, icon: Icons.airport_shuttle),
    VehicleOption(name: 'Minibus', capacity: 15, icon: Icons.directions_bus),
  ];

  VehicleOption? selectedVehicle;

  void reviewTrip() {
    final vehicle = selectedVehicle;

    if (vehicle == null || vehicle.capacity < widget.passengers) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripReviewScreen(
          pickup: widget.pickup,
          destination: widget.destination,
          pickupCoordinates: widget.pickupCoordinates,
          destinationCoordinates: widget.destinationCoordinates,
          stops: List<String>.unmodifiable(widget.stops),
          stopCoordinates: widget.stopCoordinates == null
              ? null
              : List<TripCoordinates?>.unmodifiable(widget.stopCoordinates!),
          departure: widget.departure,
          passengers: widget.passengers,
          vehicle: vehicle,
          notes: widget.notes,
          isInstantRide: widget.isInstantRide,
        ),
      ),
    );
  }

  Widget buildVehicleCard(VehicleOption vehicle) {
    final fits = vehicle.capacity >= widget.passengers;
    final selected = selectedVehicle == vehicle;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: selected ? const Color(0xFFE0F2F1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? Colors.teal : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        enabled: fits,
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          vehicle.icon,
          size: 36,
          color: fits ? Colors.teal : Colors.grey,
        ),
        title: Text(
          vehicle.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          fits
              ? '${vehicle.capacity} passenger seats'
              : '${vehicle.capacity} seats — too small for your group',
        ),
        trailing: Icon(
          selected
              ? Icons.check_circle
              : fits
              ? Icons.radio_button_unchecked
              : Icons.block,
          color: fits ? Colors.teal : Colors.grey,
        ),
        onTap: fits
            ? () {
                setState(() {
                  selectedVehicle = vehicle;
                });
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose vehicle')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Travel comfortably',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Choose a vehicle for ${widget.passengers} passengers.'),
                const SizedBox(height: 8),
                const Text(
                  'Sample vehicle capacities. '
                  'Driver availability is not connected yet. '
                  'Luggage capacity must be confirmed separately.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                for (final vehicle in vehicles) buildVehicleCard(vehicle),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: selectedVehicle == null ? null : reviewTrip,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text('Review trip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TripReviewScreen extends StatefulWidget {
  const TripReviewScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.stops,
    required this.departure,
    required this.passengers,
    required this.vehicle,
    this.notes = '',
    this.isInstantRide = false,
    this.pickupCoordinates,
    this.destinationCoordinates,
    this.stopCoordinates,
  }) : assert(
         stopCoordinates == null || stopCoordinates.length == stops.length,
       );

  final String pickup;
  final String destination;
  final List<String> stops;
  final DateTime departure;
  final int passengers;
  final VehicleOption vehicle;
  final String notes;
  final bool isInstantRide;

  final TripCoordinates? pickupCoordinates;
  final TripCoordinates? destinationCoordinates;
  final List<TripCoordinates?>? stopCoordinates;

  @override
  State<TripReviewScreen> createState() => _TripReviewScreenState();
}

class _TripReviewScreenState extends State<TripReviewScreen> {
  bool saved = false;
  bool saving = false;

  Future<void> confirmBooking() async {
    if (saved || saving) return;

    if (!widget.isInstantRide && !widget.departure.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Departure time has passed. '
            'Go back and choose a future time.',
          ),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await BookingStore.add(
        TripBooking(
          pickup: widget.pickup,
          destination: widget.destination,
          pickupCoordinates: widget.pickupCoordinates,
          destinationCoordinates: widget.destinationCoordinates,
          stops: widget.stops,
          stopCoordinates: widget.stopCoordinates,
          departure: widget.isInstantRide ? DateTime.now() : widget.departure,
          passengers: widget.passengers,
          vehicle: widget.vehicle.name,
          notes: widget.notes,
        ),
      );

      if (!mounted) return;

      setState(() {
        saved = true;
      });
    } catch (error) {
      debugPrint('Booking save failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your booking. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Widget detail(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget locationDetail({
    required String title,
    required String name,
    required IconData icon,
    required TripCoordinates? coordinates,
  }) {
    final value = coordinates == null
        ? '$name\nMap location not selected.'
        : '$name\n'
              'Latitude: ${coordinates.latitude.toStringAsFixed(5)}\n'
              'Longitude: ${coordinates.longitude.toStringAsFixed(5)}';

    return detail(title, value, icon);
  }

  TripCoordinates? coordinatesForStop(int index) {
    final coordinates = widget.stopCoordinates;

    if (coordinates == null || index >= coordinates.length) {
      return null;
    }

    return coordinates[index];
  }

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(widget.departure);

    final time = TimeOfDay.fromDateTime(widget.departure).format(context);

    return Scaffold(
      appBar: AppBar(title: Text(saved ? 'Booking saved' : 'Review trip')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (saved) ...[
                  const Icon(Icons.check_circle, size: 72, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'Demo booking saved!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Return to Home and open the Bookings tab '
                    'to see your trip.',
                    textAlign: TextAlign.center,
                  ),
                ] else
                  const Text(
                    'Your journey',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 20),
                locationDetail(
                  title: 'Pickup',
                  name: widget.pickup,
                  icon: Icons.my_location,
                  coordinates: widget.pickupCoordinates,
                ),
                for (int i = 0; i < widget.stops.length; i++)
                  locationDetail(
                    title: 'Stop ${i + 1}',
                    name: widget.stops[i],
                    icon: Icons.place_outlined,
                    coordinates: coordinatesForStop(i),
                  ),
                locationDetail(
                  title: 'Destination',
                  name: widget.destination,
                  icon: Icons.location_on,
                  coordinates: widget.destinationCoordinates,
                ),
                detail(
                  widget.isInstantRide ? 'Pickup request' : 'Departure',
                  widget.isInstantRide ? 'Now' : '$date at $time',
                  widget.isInstantRide
                      ? Icons.local_taxi
                      : Icons.calendar_month,
                ),
                detail('Passengers', '${widget.passengers}', Icons.people),
                detail('Vehicle', widget.vehicle.name, widget.vehicle.icon),
                if (widget.notes.isNotEmpty)
                  detail('Additional details', widget.notes, Icons.notes),
                const SizedBox(height: 20),
                const Text(
                  'Demo only: no payment is taken and no driver '
                  'is contacted. Bookings are saved on this device.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                if (!saved) ...[
                  FilledButton(
                    onPressed: saving ? null : confirmBooking,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: Text(saving ? 'Saving...' : 'Confirm demo booking'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Change vehicle'),
                  ),
                ] else
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('Return to Home'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
