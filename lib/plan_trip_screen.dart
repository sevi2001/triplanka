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

    // Locate the same stop again instead of relying on an old index.
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

    if (!formKey.currentState!.validate()) {
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

    // Capture names and coordinates together in the same order.
    final stops = stopControllers
        .map((controller) => controller.text.trim())
        .toList();

    final selectedStopCoordinates = List<TripCoordinates?>.unmodifiable(
      stopCoordinates,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: pickupCoordinates,
          destinationCoordinates: destinationCoordinates,
          stops: stops,
          stopCoordinates: selectedStopCoordinates,
          departure: departure,
          passengers: passengers,
          notes: notes,
        ),
      ),
    );
  }

  Widget locationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validateLocation,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
        if (coordinates != null) coordinateLabel(coordinates),
      ],
    );
  }

  Widget stopField(int index) {
    final controller = stopControllers[index];
    final coordinates = stopCoordinates[index];

    return Padding(
      key: ObjectKey(controller),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: locationField(
                  controller: controller,
                  label: 'Stop ${index + 1}',
                  icon: Icons.place_outlined,
                  onChanged: (_) => clearStopCoordinates(controller),
                ),
              ),
              IconButton(
                tooltip: 'Remove stop ${index + 1}',
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
                onPressed: () => removeStop(controller),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => searchStop(controller),
            icon: const Icon(Icons.search),
            label: Text('Search stop ${index + 1}'),
          ),
          if (coordinates != null) coordinateLabel(coordinates),
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
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
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
        ? 'Choose return date'
        : localizations.formatMediumDate(returnDate!);

    final returnTimeLabel = returnTime == null
        ? 'Choose return time'
        : returnTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan a trip')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Plan your journey',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Plan a one-way or return trip '
                    'with optional outbound stops.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  locationField(
                    controller: pickupController,
                    label: 'Pickup location',
                    icon: Icons.my_location,
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
                  const SizedBox(height: 14),
                  for (int i = 0; i < stopControllers.length; i++) stopField(i),
                  locationField(
                    controller: destinationController,
                    label: 'Destination',
                    icon: Icons.location_on,
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: addStop,
                    icon: const Icon(Icons.add),
                    label: const Text('Add stop'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use Search for each stop you want to show on the map.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  dateTimeCard(
                    title: 'Travel date',
                    value: dateLabel,
                    icon: Icons.calendar_month,
                    onTap: chooseDate,
                  ),
                  dateTimeCard(
                    title: 'Departure time',
                    value: timeLabel,
                    icon: Icons.access_time,
                    onTap: chooseTime,
                  ),
                  const SizedBox(height: 16),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Return trip'),
                    subtitle: const Text(
                      'Arrange travel back to your pickup location.',
                    ),
                    value: returnTrip,
                    onChanged: (value) {
                      setState(() {
                        returnTrip = value;
                      });
                    },
                  ),
                  if (returnTrip) ...[
                    dateTimeCard(
                      title: 'Return date',
                      value: returnDateLabel,
                      icon: Icons.calendar_month,
                      onTap: chooseReturnDate,
                    ),
                    dateTimeCard(
                      title: 'Return departure time',
                      value: returnTimeLabel,
                      icon: Icons.access_time,
                      onTap: chooseReturnTime,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Allow enough time for the outbound journey '
                      'and your activities before returning.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: continueBooking,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text('Continue'),
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
