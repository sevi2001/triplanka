import 'package:flutter/material.dart';

import 'booking_store.dart';
import 'location_picker_screen.dart';
import 'vehicle_selection_screen.dart';

class FullDayDriverScreen extends StatefulWidget {
  const FullDayDriverScreen({
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
  State<FullDayDriverScreen> createState() => _FullDayDriverScreenState();
}

class _FullDayDriverScreenState extends State<FullDayDriverScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const borderColor = Color(0xFFE5EAF2);

  static const packages = [
    (name: 'Half day', hours: 4, kilometres: 50),
    (name: 'Full day', hours: 8, kilometres: 100),
    (name: 'Extended day', hours: 12, kilometres: 150),
  ];

  final formKey = GlobalKey<FormState>();
  final notesController = TextEditingController();

  late final TextEditingController pickupController;

  final placeControllers = <TextEditingController>[];
  final placeCoordinates = <TripCoordinates?>[];

  TripCoordinates? pickupCoordinates;

  DateTime? travelDate;
  TimeOfDay? startTime;

  int passengers = 1;
  int packageIndex = 1;
  bool returnToPickup = true;

  DateTime? get departure {
    final date = travelDate;
    final time = startTime;

    if (date == null || time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime? get estimatedFinish =>
      departure?.add(Duration(hours: packages[packageIndex].hours));

  @override
  void initState() {
    super.initState();

    pickupController = TextEditingController(text: widget.pickup);
    pickupCoordinates = widget.pickupCoordinates;

    final initialPlaces = widget.destination
        .split('\n')
        .map((place) => place.trim())
        .where((place) => place.isNotEmpty)
        .toList();

    if (initialPlaces.isEmpty) {
      placeControllers.add(TextEditingController());
      placeCoordinates.add(null);
    } else {
      for (final place in initialPlaces) {
        placeControllers.add(TextEditingController(text: place));
        placeCoordinates.add(null);
      }

      if (initialPlaces.length == 1) {
        placeCoordinates[0] = widget.destinationCoordinates;
      }
    }
  }

  @override
  void dispose() {
    pickupController.dispose();
    notesController.dispose();

    for (final controller in placeControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void addPlace() {
    setState(() {
      placeControllers.add(TextEditingController());
      placeCoordinates.add(null);
    });
  }

  void removePlace(TextEditingController controller) {
    if (placeControllers.length <= 1) return;

    FocusScope.of(context).unfocus();

    final index = placeControllers.indexOf(controller);
    if (index < 0) return;

    setState(() {
      placeControllers.removeAt(index);
      placeCoordinates.removeAt(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  Future<void> searchLocation({TextEditingController? placeController}) async {
    FocusScope.of(context).unfocus();

    final isPickup = placeController == null;

    final selected = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => LocationPickerScreen(
          title: isPickup ? 'Find pickup' : 'Find place to visit',
          confirmLabel: isPickup ? 'Use this pickup' : 'Use this place',
        ),
      ),
    );

    if (!mounted || selected == null) return;

    final coordinates = TripCoordinates(
      latitude: selected.point.latitude,
      longitude: selected.point.longitude,
    );

    if (isPickup) {
      setState(() {
        pickupController.text = selected.name;
        pickupCoordinates = coordinates;
      });
      return;
    }

    final index = placeControllers.indexOf(placeController);
    if (index < 0) return;

    setState(() {
      placeControllers[index].text = selected.name;
      placeCoordinates[index] = coordinates;
    });
  }

  Future<void> chooseDate() async {
    FocusScope.of(context).unfocus();

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

    setState(() => travelDate = selected);
  }

  Future<void> chooseTime() async {
    FocusScope.of(context).unfocus();

    final selected = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );

    if (!mounted || selected == null) return;

    setState(() => startTime = selected);
  }

  String formatDateTime(DateTime value) {
    final date = MaterialLocalizations.of(context).formatMediumDate(value);
    final time = TimeOfDay.fromDateTime(value).format(context);

    return '$date at $time';
  }

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;

    final start = departure;
    final finish = estimatedFinish;

    if (start == null || finish == null) {
      showMessage('Choose a date and start time.');
      return;
    }

    if (!start.isAfter(DateTime.now())) {
      showMessage('Choose a start time in the future.');
      return;
    }

    final pickup = pickupController.text.trim();
    final places = placeControllers
        .map((controller) => controller.text.trim())
        .toList();

    // A return trip can end at pickup, but it needs another place to visit.
    final hasDifferentPlace = places.asMap().entries.any((entry) {
      final point = placeCoordinates[entry.key];
      final pickupPoint = pickupCoordinates;

      if (point != null && pickupPoint != null) {
        return point.latitude != pickupPoint.latitude ||
            point.longitude != pickupPoint.longitude;
      }

      return entry.value.toLowerCase() != pickup.toLowerCase();
    });

    if (!hasDifferentPlace) {
      showMessage('Add at least one place different from your pickup.');
      return;
    }

    final package = packages[packageIndex];

    final destination = returnToPickup ? pickup : places.last;
    final destinationPoint = returnToPickup
        ? pickupCoordinates
        : placeCoordinates.last;

    final stops = returnToPickup
        ? List<String>.from(places)
        : places.take(places.length - 1).toList();

    final stopPoints = returnToPickup
        ? List<TripCoordinates?>.from(placeCoordinates)
        : placeCoordinates.take(placeCoordinates.length - 1).toList();

    final extraNotes = notesController.text.trim();

    final notes = [
      'Driver hire: ${package.name}',
      'Sample package: ${package.hours} hours / '
          '${package.kilometres} km',
      'Estimated package finish: ${formatDateTime(finish)}',
      'Return to pickup: ${returnToPickup ? 'Yes' : 'No'}',
      if (extraNotes.isNotEmpty) 'Additional notes: $extraNotes',
      'Package prices and extra charges are not set yet.',
    ].join('\n');

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: pickup,
          destination: destination,
          pickupCoordinates: pickupCoordinates,
          destinationCoordinates: destinationPoint,
          stops: List<String>.unmodifiable(stops),
          stopCoordinates: List<TripCoordinates?>.unmodifiable(stopPoints),
          departure: start,
          passengers: passengers,
          notes: notes,
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
        border: Border.all(color: borderColor),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration fieldDecoration({
    required String label,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: muted, fontSize: 13),
      prefixIcon: icon == null ? null : Icon(icon, color: blue, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.all(16),
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
    );
  }

  Widget mapSelected() {
    return const Padding(
      padding: EdgeInsets.only(top: 7, left: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF159A75), size: 15),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Map location selected',
              style: TextStyle(color: Color(0xFF159A75), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget placeField(int index) {
    final controller = placeControllers[index];

    return Padding(
      key: ObjectKey(controller),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: fieldDecoration(
                    label: 'Place ${index + 1}',
                    icon: Icons.location_on_outlined,
                    suffix: IconButton(
                      tooltip: 'Search place ${index + 1}',
                      onPressed: () =>
                          searchLocation(placeController: controller),
                      icon: const Icon(Icons.search, color: blue),
                    ),
                  ),
                  onChanged: (_) {
                    final currentIndex = placeControllers.indexOf(controller);

                    if (currentIndex < 0 ||
                        placeCoordinates[currentIndex] == null) {
                      return;
                    }

                    setState(() {
                      placeCoordinates[currentIndex] = null;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a place to visit';
                    }

                    return null;
                  },
                ),
              ),
              if (placeControllers.length > 1) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Remove place ${index + 1}',
                  onPressed: () => removePlace(controller),
                  icon: const Icon(Icons.close, color: Color(0xFFE85D75)),
                ),
              ],
            ],
          ),
          if (placeCoordinates[index] != null) mapSelected(),
        ],
      ),
    );
  }

  Widget scheduleRow({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: blue, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
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
              const Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget packageCard(int index) {
    final package = packages[index];
    final selected = packageIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFEEF4FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? blue : borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => packageIndex = index),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? blue : muted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${package.hours} hours · '
                        '${package.kilometres} km',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
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
    final dateLabel = travelDate == null
        ? 'Choose date'
        : MaterialLocalizations.of(context).formatMediumDate(travelDate!);

    final timeLabel = startTime?.format(context) ?? 'Choose time';
    final finish = estimatedFinish;

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
                      const Expanded(
                        child: Text(
                          'Full-day driver',
                          style: TextStyle(
                            color: navy,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [blue, Color(0xFF1547B8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.explore_outlined,
                                color: Colors.white,
                                size: 36,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Explore at your own pace',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Plan your places, choose a package, '
                                'and find a vehicle for your group.',
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
                              TextFormField(
                                controller: pickupController,
                                textCapitalization: TextCapitalization.words,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: fieldDecoration(
                                  label: 'Pickup location',
                                  icon: Icons.my_location,
                                  suffix: IconButton(
                                    tooltip: 'Search pickup',
                                    onPressed: () => searchLocation(),
                                    icon: const Icon(Icons.search, color: blue),
                                  ),
                                ),
                                onChanged: (_) {
                                  if (pickupCoordinates == null) return;

                                  setState(() => pickupCoordinates = null);
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter a pickup location';
                                  }

                                  return null;
                                },
                              ),
                              if (pickupCoordinates != null) mapSelected(),
                              const SizedBox(height: 20),
                              const Text(
                                'Places to visit',
                                style: TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Add places in the order you want to visit.',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              for (int i = 0; i < placeControllers.length; i++)
                                placeField(i),
                              TextButton.icon(
                                onPressed: addPlace,
                                icon: const Icon(Icons.add),
                                label: const Text('Add another place'),
                                style: TextButton.styleFrom(
                                  foregroundColor: blue,
                                ),
                              ),
                              const Divider(color: borderColor),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: blue,
                                title: const Text(
                                  'Return to pickup',
                                  style: TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text(
                                  'End your trip where you started.',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                                value: returnToPickup,
                                onChanged: (value) {
                                  setState(() => returnToPickup = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        section(
                          title: 'Choose a sample package',
                          icon: Icons.directions_car_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < packages.length; i++)
                                packageCard(i),
                              const Text(
                                'Prototype packages. Prices and '
                                'extra-hour or distance charges '
                                'have not been set.',
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
                          title: 'Trip schedule',
                          icon: Icons.calendar_month_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              scheduleRow(
                                title: 'Travel date',
                                value: dateLabel,
                                icon: Icons.calendar_today_outlined,
                                onTap: chooseDate,
                              ),
                              const SizedBox(height: 10),
                              scheduleRow(
                                title: 'Start time',
                                value: timeLabel,
                                icon: Icons.access_time,
                                onTap: chooseTime,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                finish == null
                                    ? 'Select a date and start time '
                                          'to see the estimated finish.'
                                    : 'Estimated package finish: '
                                          '${formatDateTime(finish)}',
                                style: const TextStyle(
                                  color: blue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Finish time follows the selected '
                                'package duration. It is not a '
                                'route or traffic estimate.',
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
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Passengers',
                                  style: TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Fewer passengers',
                                onPressed: passengers > 1
                                    ? () => setState(() => passengers--)
                                    : null,
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
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                        section(
                          title: 'Additional notes',
                          icon: Icons.notes_outlined,
                          child: TextFormField(
                            controller: notesController,
                            minLines: 3,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: fieldDecoration(
                              label: 'Requests or details (optional)',
                            ),
                          ),
                        ),
                        const Text(
                          'Search pickup and every place to save '
                          'all map locations. Demo booking: a driver '
                          'has not been assigned.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.5,
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
                    border: Border(top: BorderSide(color: borderColor)),
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
