import 'package:flutter/material.dart';

import 'booking_store.dart';
import 'location_picker_screen.dart';
import 'vehicle_selection_screen.dart';

class PlanTripScreen extends StatefulWidget {
  const PlanTripScreen({
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
  State<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);

  final formKey = GlobalKey<FormState>();

  late final TextEditingController pickupController;
  late final TextEditingController destinationController;

  final List<TextEditingController> stopControllers = [];
  final List<TripCoordinates?> stopCoordinates = [];

  TripCoordinates? pickupCoordinates;
  TripCoordinates? destinationCoordinates;

  DateTime? travelDate;
  TimeOfDay? travelTime;

  bool returnTrip = false;
  DateTime? returnDate;
  TimeOfDay? returnTime;

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

    for (final controller in stopControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  String? validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a location';
    }

    return null;
  }

  TripCoordinates coordinatesFor(SelectedLocation location) {
    return TripCoordinates(
      latitude: location.point.latitude,
      longitude: location.point.longitude,
    );
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

    setState(() {
      if (isPickup) {
        pickupController.text = location.name;
        pickupCoordinates = coordinatesFor(location);
      } else {
        destinationController.text = location.name;
        destinationCoordinates = coordinatesFor(location);
      }
    });
  }

  Future<void> searchStop(TextEditingController controller) async {
    final originalIndex = stopControllers.indexOf(controller);
    if (originalIndex == -1) return;

    FocusScope.of(context).unfocus();

    final location = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => LocationPickerScreen(
          title: 'Find stop ${originalIndex + 1}',
          confirmLabel: 'Use this stop',
        ),
      ),
    );

    if (!mounted || location == null) return;

    final currentIndex = stopControllers.indexOf(controller);
    if (currentIndex == -1) return;

    setState(() {
      controller.text = location.name;
      stopCoordinates[currentIndex] = coordinatesFor(location);
    });
  }

  void addStop() {
    setState(() {
      stopControllers.add(TextEditingController());
      stopCoordinates.add(null);
    });
  }

  void removeStop(TextEditingController controller) {
    final index = stopControllers.indexOf(controller);
    if (index == -1) return;

    FocusScope.of(context).unfocus();

    setState(() {
      stopControllers.removeAt(index);
      stopCoordinates.removeAt(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  void clearStopCoordinates(TextEditingController controller) {
    final index = stopControllers.indexOf(controller);

    if (index == -1 || stopCoordinates[index] == null) return;

    setState(() {
      stopCoordinates[index] = null;
    });
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selected = await showDatePicker(
      context: context,
      initialDate: travelDate != null && !travelDate!.isBefore(today)
          ? travelDate!
          : today,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );

    if (!mounted || selected == null) return;

    setState(() {
      travelDate = selected;

      if (returnDate != null && returnDate!.isBefore(selected)) {
        returnDate = null;
        returnTime = null;
      }
    });
  }

  Future<void> chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: travelTime ?? TimeOfDay.now(),
    );

    if (!mounted || selected == null) return;

    setState(() {
      travelTime = selected;
    });
  }

  Future<void> chooseReturnDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDate = travelDate != null && travelDate!.isAfter(today)
        ? travelDate!
        : today;

    final selected = await showDatePicker(
      context: context,
      initialDate: returnDate != null && !returnDate!.isBefore(firstDate)
          ? returnDate!
          : firstDate,
      firstDate: firstDate,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );

    if (!mounted || selected == null) return;

    setState(() {
      returnDate = selected;
    });
  }

  Future<void> chooseReturnTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: returnTime ?? TimeOfDay.now(),
    );

    if (!mounted || selected == null) return;

    setState(() {
      returnTime = selected;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) {
      showMessage('Fill in pickup, destination, and every added stop.');
      return;
    }

    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();

    if (pickup.toLowerCase() == destination.toLowerCase()) {
      showMessage('Choose different pickup and destination locations.');
      return;
    }

    if (travelDate == null || travelTime == null) {
      showMessage('Choose a departure date and time.');
      return;
    }

    final departure = DateTime(
      travelDate!.year,
      travelDate!.month,
      travelDate!.day,
      travelTime!.hour,
      travelTime!.minute,
    );

    if (!departure.isAfter(DateTime.now())) {
      showMessage('Choose a departure time in the future.');
      return;
    }

    String notes = 'One-way trip';

    if (returnTrip) {
      if (returnDate == null || returnTime == null) {
        showMessage('Choose a return date and time.');
        return;
      }

      final returnDeparture = DateTime(
        returnDate!.year,
        returnDate!.month,
        returnDate!.day,
        returnTime!.hour,
        returnTime!.minute,
      );

      if (!returnDeparture.isAfter(departure)) {
        showMessage('Return departure must be after the outbound departure.');
        return;
      }

      final dateLabel = MaterialLocalizations.of(
        context,
      ).formatMediumDate(returnDeparture);

      final timeLabel = TimeOfDay.fromDateTime(returnDeparture).format(context);

      notes = [
        'Return trip',
        'Return from: $destination',
        'Return to: $pickup',
        'Return departure: $dateLabel at $timeLabel',
        'Return stops are not specified.',
      ].join('\n');
    }

    final stops = List<String>.unmodifiable(
      stopControllers.map((controller) => controller.text.trim()),
    );

    final selectedStopCoordinates = List<TripCoordinates?>.unmodifiable(
      stopCoordinates,
    );

    final selectedPickup = pickupCoordinates;
    final selectedDestination = destinationCoordinates;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: selectedPickup,
          destinationCoordinates: selectedDestination,
          stops: stops,
          stopCoordinates: selectedStopCoordinates,
          departure: departure,
          passengers: passengers,
          notes: notes,
        ),
      ),
    );
  }

  Widget section({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget locationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onSearch,
    required String searchLabel,
    required TripCoordinates? coordinates,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          validator: validateLocation,
          onChanged: onChanged,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: color),
            suffixIcon: IconButton(
              tooltip: searchLabel,
              onPressed: onSearch,
              icon: const Icon(Icons.search, color: blue),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (coordinates != null) ...[
          const SizedBox(height: 7),
          const Row(
            children: [
              Icon(Icons.check_circle, size: 15, color: Color(0xFF0D9488)),
              SizedBox(width: 5),
              Text(
                'Map location selected',
                style: TextStyle(fontSize: 11, color: Color(0xFF0D9488)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget stopField(int index) {
    final controller = stopControllers[index];

    return Padding(
      key: ObjectKey(controller),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: locationField(
              controller: controller,
              label: 'Stop ${index + 1}',
              icon: Icons.place_outlined,
              color: blue,
              onSearch: () => searchStop(controller),
              searchLabel: 'Search stop ${index + 1}',
              coordinates: stopCoordinates[index],
              onChanged: (_) => clearStopCoordinates(controller),
            ),
          ),
          IconButton(
            tooltip: 'Remove stop ${index + 1}',
            onPressed: () => removeStop(controller),
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget dateTimeCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: blue, size: 23),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget dateTimePair({
    required String dateTitle,
    required String dateValue,
    required VoidCallback onDate,
    required String timeTitle,
    required String timeValue,
    required VoidCallback onTime,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dateCard = dateTimeCard(
          title: dateTitle,
          value: dateValue,
          icon: Icons.calendar_month_outlined,
          onTap: onDate,
        );

        final timeCard = dateTimeCard(
          title: timeTitle,
          value: timeValue,
          icon: Icons.schedule,
          onTap: onTime,
        );

        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [dateCard, const SizedBox(height: 12), timeCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: dateCard),
            const SizedBox(width: 12),
            Expanded(child: timeCard),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    final dateLabel = travelDate == null
        ? 'Choose date'
        : localizations.formatMediumDate(travelDate!);

    final timeLabel = travelTime == null
        ? 'Choose time'
        : travelTime!.format(context);

    final returnDateLabel = returnDate == null
        ? 'Choose date'
        : localizations.formatMediumDate(returnDate!);

    final returnTimeLabel = returnTime == null
        ? 'Choose time'
        : returnTime!.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: navy),
                      ),
                      const Expanded(
                        child: Text(
                          'Plan a trip',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Plan your journey',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose your places, schedule, and travel group.',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 22),
                        section(
                          title: 'Your route',
                          icon: Icons.route,
                          children: [
                            locationField(
                              controller: pickupController,
                              label: 'Pickup location',
                              icon: Icons.my_location,
                              color: const Color(0xFF0D9488),
                              onSearch: () => searchLocation(isPickup: true),
                              searchLabel: 'Search pickup',
                              coordinates: pickupCoordinates,
                              onChanged: (_) {
                                if (pickupCoordinates == null) return;

                                setState(() {
                                  pickupCoordinates = null;
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            for (int i = 0; i < stopControllers.length; i++)
                              stopField(i),
                            locationField(
                              controller: destinationController,
                              label: 'Destination',
                              icon: Icons.location_on,
                              color: const Color(0xFFF43F5E),
                              onSearch: () => searchLocation(isPickup: false),
                              searchLabel: 'Search destination',
                              coordinates: destinationCoordinates,
                              onChanged: (_) {
                                if (destinationCoordinates == null) {
                                  return;
                                }

                                setState(() {
                                  destinationCoordinates = null;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: addStop,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add stop'),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use the search icons to save map locations '
                              'for pickup, destination, and every stop.',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                        section(
                          title: 'Departure',
                          icon: Icons.calendar_month_outlined,
                          children: [
                            dateTimePair(
                              dateTitle: 'Travel date',
                              dateValue: dateLabel,
                              onDate: chooseDate,
                              timeTitle: 'Departure time',
                              timeValue: timeLabel,
                              onTime: chooseTime,
                            ),
                          ],
                        ),
                        section(
                          title: 'Travel group',
                          icon: Icons.people_outline,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Passengers',
                                    style: TextStyle(color: navy),
                                  ),
                                ),
                                IconButton.filledTonal(
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    '$passengers',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: navy,
                                    ),
                                  ),
                                ),
                                IconButton.filledTonal(
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
                            const SizedBox(height: 8),
                            const Text(
                              'Choose from 1 to 15 passengers.',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                        section(
                          title: 'Return journey',
                          icon: Icons.sync_alt,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Return trip',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: navy,
                                ),
                              ),
                              subtitle: const Text(
                                'Travel back to your pickup location.',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                              value: returnTrip,
                              onChanged: (value) {
                                setState(() {
                                  returnTrip = value;
                                });
                              },
                            ),
                            if (returnTrip) ...[
                              const SizedBox(height: 12),
                              dateTimePair(
                                dateTitle: 'Return date',
                                dateValue: returnDateLabel,
                                onDate: chooseReturnDate,
                                timeTitle: 'Return departure',
                                timeValue: returnTimeLabel,
                                onTime: chooseReturnTime,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Allow time for your outward journey '
                                'and activities. Return details are '
                                'saved in the booking notes; the map '
                                'shows the outbound route.',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Demo booking. No driver is contacted '
                            'and no payment is taken.',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        padding: const EdgeInsets.symmetric(vertical: 17),
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
