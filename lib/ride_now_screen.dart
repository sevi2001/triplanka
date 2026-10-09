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
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);

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

  void swapLocations() {
    FocusScope.of(context).unfocus();

    final previousPickup = pickupController.text;
    final previousPickupCoordinates = pickupCoordinates;

    setState(() {
      pickupController.text = destinationController.text;
      destinationController.text = previousPickup;

      pickupCoordinates = destinationCoordinates;
      destinationCoordinates = previousPickupCoordinates;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;

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

  Widget section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: blue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget locationField({required bool isPickup}) {
    final controller = isPickup ? pickupController : destinationController;

    final coordinates = isPickup ? pickupCoordinates : destinationCoordinates;

    final label = isPickup ? 'Pickup location' : 'Destination';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          textInputAction: isPickup
              ? TextInputAction.next
              : TextInputAction.done,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) {
            if (coordinates == null) return;

            setState(() {
              if (isPickup) {
                pickupCoordinates = null;
              } else {
                destinationCoordinates = null;
              }
            });
          },
          onFieldSubmitted: isPickup
              ? null
              : (_) => FocusScope.of(context).unfocus(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return isPickup
                  ? 'Enter your pickup location'
                  : 'Enter your destination';
            }

            return null;
          },
          style: const TextStyle(color: navy),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: muted),
            prefixIcon: Icon(
              isPickup ? Icons.my_location : Icons.location_on_outlined,
              color: isPickup ? blue : const Color(0xFFE85D75),
            ),
            suffixIcon: IconButton(
              tooltip: isPickup ? 'Search pickup' : 'Search destination',
              onPressed: () => searchLocation(isPickup: isPickup),
              icon: const Icon(Icons.search, color: blue),
            ),
            filled: true,
            fillColor: background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: blue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
        if (coordinates != null)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF159A75), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Map location selected',
                    style: TextStyle(color: Color(0xFF159A75), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget passengerSelector() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Passengers',
                style: TextStyle(
                  color: navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Including you',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Fewer passengers',
          onPressed: passengers > 1 ? () => setState(() => passengers--) : null,
          style: IconButton.styleFrom(
            foregroundColor: blue,
            backgroundColor: const Color(0xFFEEF4FF),
          ),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$passengers',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'More passengers',
          onPressed: passengers < 15
              ? () => setState(() => passengers++)
              : null,
          style: IconButton.styleFrom(
            foregroundColor: blue,
            backgroundColor: const Color(0xFFEEF4FF),
          ),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: navy),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Ride now',
                        style: TextStyle(
                          color: navy,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          margin: const EdgeInsets.only(bottom: 22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1547B8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.local_taxi_outlined,
                                color: Colors.white,
                                size: 36,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Where would you like to go?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Choose your locations and find a vehicle '
                                'that fits your group.',
                                style: TextStyle(
                                  color: Color(0xFFDCE8FF),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        section(
                          title: 'Your journey',
                          icon: Icons.route_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              locationField(isPickup: true),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: swapLocations,
                                  icon: const Icon(Icons.swap_vert, size: 20),
                                  label: const Text('Swap locations'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: blue,
                                  ),
                                ),
                              ),
                              locationField(isPickup: false),
                              const SizedBox(height: 16),
                              const Text(
                                'Tap the search icon to find a place '
                                'and save its map location.',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        section(
                          title: 'Travel group',
                          icon: Icons.groups_outlined,
                          child: passengerSelector(),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: blue, size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Demo booking. Nearby drivers, live '
                                  'tracking, and fare estimates are '
                                  'not connected yet.',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5EAF2))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: continueBooking,
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.directions_car_outlined),
                      label: const Text(
                        'Choose vehicle',
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
    );
  }
}
