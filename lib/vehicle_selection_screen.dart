import 'package:flutter/material.dart';

import 'booking_store.dart';
import 'cloud_booking_store.dart';

const _vehicleBlue = Color(0xFF2563EB);
const _vehicleNavy = Color(0xFF14213D);

class VehicleOption {
  const VehicleOption({
    required this.name,
    required this.capacity,
    required this.icon,
    this.imagePath,
  });

  final String name;
  final int capacity;
  final IconData icon;
  final String? imagePath;
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
    VehicleOption(
      name: 'Tuk-tuk',
      capacity: 3,
      icon: Icons.electric_rickshaw,
      imagePath: 'assets/vehicles/tuk_tuk.png',
    ),
    VehicleOption(
      name: 'Car',
      capacity: 4,
      icon: Icons.directions_car,
      imagePath: 'assets/vehicles/car.png',
    ),
    VehicleOption(
      name: 'Van',
      capacity: 8,
      icon: Icons.airport_shuttle,
      imagePath: 'assets/vehicles/van.png',
    ),
    VehicleOption(
      name: 'Minibus',
      capacity: 15,
      icon: Icons.directions_bus,
      imagePath: 'assets/vehicles/minibus.png',
    ),
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

  Widget vehicleIcon(VehicleOption vehicle, bool fits) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        vehicle.icon,
        size: 46,
        color: fits ? _vehicleBlue : Colors.grey,
      ),
    );
  }

  Widget vehicleImage(VehicleOption vehicle, bool fits) {
    final imagePath = vehicle.imagePath;

    return SizedBox(
      width: 80,
      height: 64,
      child: Opacity(
        opacity: fits ? 1 : 0.55,
        child: imagePath == null
            ? vehicleIcon(vehicle, fits)
            : Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return vehicleIcon(vehicle, fits);
                },
              ),
      ),
    );
  }

  Widget buildVehicleCard(VehicleOption vehicle) {
    final fits = vehicle.capacity >= widget.passengers;
    final selected = selectedVehicle == vehicle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? const Color(0xFFEDF4FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? _vehicleBlue : const Color(0xFFE1E7F0),
            width: selected ? 1.8 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: fits
              ? () {
                  setState(() {
                    selectedVehicle = vehicle;
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                vehicleImage(vehicle, fits),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _vehicleNavy,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt,
                            size: 16,
                            color: Color(0xFF738097),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${vehicle.capacity} seats',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF738097),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!fits)
                  SizedBox(
                    width: 78,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Too small',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF68758B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Not enough seats\nfor ${widget.passengers}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF738097),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? _vehicleBlue : const Color(0xFFAAB5C6),
                    size: 26,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = selectedVehicle;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: _vehicleNavy,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Choose vehicle',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _vehicleNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Text(
                          'Select a vehicle for '
                          '${widget.passengers} passengers',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _vehicleNavy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final option in vehicles) buildVehicleCard(option),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6FC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Your selection',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF738097),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Color(0xFF738097),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                vehicle?.name ?? 'Choose a vehicle',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _vehicleBlue,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Fare estimates are not connected yet.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF738097),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Sample seat capacities. Confirm luggage space '
                          'separately. Driver availability is not connected.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF738097),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFEDF0F5))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: vehicle == null ? null : reviewTrip,
                        style: FilledButton.styleFrom(
                          backgroundColor: _vehicleBlue,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Review trip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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

    if (widget.passengers < 1 || widget.passengers > widget.vehicle.capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a vehicle with enough passenger seats.'),
        ),
      );
      return;
    }

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
      await CloudBookingStore.add(
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
          content: Text(
            'Could not save your booking. '
            'Check your connection and try again.',
          ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _vehicleBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF738097),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: _vehicleNavy,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        : '$name\nMap location selected.';

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
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: Text(saved ? 'Booking saved' : 'Review trip')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (saved) ...[
                  const Icon(Icons.check_circle, size: 72, color: _vehicleBlue),
                  const SizedBox(height: 16),
                  const Text(
                    'Demo booking saved!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _vehicleNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Saved to your account. Return to Home '
                    'and open Bookings to see your trip.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Text(
                    'Your journey',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _vehicleNavy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check your details before saving.',
                    style: TextStyle(color: Color(0xFF738097)),
                  ),
                ],
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
                const SizedBox(height: 8),
                const Text(
                  'Demo only. No payment is taken and no driver '
                  'is contacted. Confirmed bookings are saved '
                  'to your signed-in account.',
                  style: TextStyle(color: Color(0xFF738097), fontSize: 12),
                ),
                const SizedBox(height: 24),
                if (!saved) ...[
                  FilledButton(
                    onPressed: saving ? null : confirmBooking,
                    style: FilledButton.styleFrom(
                      backgroundColor: _vehicleBlue,
                      padding: const EdgeInsets.symmetric(vertical: 17),
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
