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
  });

  final String pickup;
  final String destination;
  final List<String> stops;
  final DateTime departure;
  final int passengers;

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
    if (vehicle == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripReviewScreen(
          pickup: widget.pickup,
          destination: widget.destination,
          stops: widget.stops,
          departure: widget.departure,
          passengers: widget.passengers,
          vehicle: vehicle,
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
                Text(
                  'Choose a vehicle for '
                  '${widget.passengers} passengers.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sample vehicle capacities. '
                  'Driver availability is not connected yet.',
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
  });

  final String pickup;
  final String destination;
  final List<String> stops;
  final DateTime departure;
  final int passengers;
  final VehicleOption vehicle;

  @override
  State<TripReviewScreen> createState() => _TripReviewScreenState();
}

class _TripReviewScreenState extends State<TripReviewScreen> {
  bool saved = false;

  void confirmBooking() {
    if (saved) return;

    if (!widget.departure.isAfter(DateTime.now())) {
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

    BookingStore.add(
      TripBooking(
        pickup: widget.pickup,
        destination: widget.destination,
        stops: widget.stops,
        departure: widget.departure,
        passengers: widget.passengers,
        vehicle: widget.vehicle.name,
      ),
    );

    setState(() {
      saved = true;
    });
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
                detail('Pickup', widget.pickup, Icons.my_location),
                if (widget.stops.isNotEmpty)
                  detail('Stops', widget.stops.join(' → '), Icons.route),
                detail('Destination', widget.destination, Icons.location_on),
                detail('Departure', '$date at $time', Icons.calendar_month),
                detail('Passengers', '${widget.passengers}', Icons.people),
                detail('Vehicle', widget.vehicle.name, widget.vehicle.icon),
                const SizedBox(height: 20),
                const Text(
                  'Demo only: no payment is taken and no '
                  'driver is contacted. This booking clears '
                  'when the app restarts.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                if (!saved) ...[
                  FilledButton(
                    onPressed: confirmBooking,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text('Confirm demo booking'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
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
