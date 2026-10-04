import 'package:flutter/material.dart';

import 'booking_store.dart';
import 'location_picker_screen.dart';
import 'vehicle_selection_screen.dart';

class AirportTransferScreen extends StatefulWidget {
  const AirportTransferScreen({
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
  State<AirportTransferScreen> createState() => _AirportTransferScreenState();
}

class _AirportTransferScreenState extends State<AirportTransferScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const borderColor = Color(0xFFE5EAF2);

  final formKey = GlobalKey<FormState>();
  final flightController = TextEditingController();

  late final TextEditingController locationController;

  bool airportPickup = true;
  String airport = 'Bandaranaike Airport (CMB)';

  TripCoordinates? airportCoordinates;
  String? airportMeetingPoint;

  String pickupLocation = '';
  String dropoffLocation = '';
  TripCoordinates? pickupLocationCoordinates;
  TripCoordinates? dropoffLocationCoordinates;

  DateTime? travelDate;
  TimeOfDay? travelTime;

  int passengers = 1;
  int bags = 0;

  TripCoordinates? get locationCoordinates =>
      airportPickup ? dropoffLocationCoordinates : pickupLocationCoordinates;

  @override
  void initState() {
    super.initState();

    pickupLocation = widget.pickup;
    dropoffLocation = widget.destination;

    pickupLocationCoordinates = widget.pickupCoordinates;
    dropoffLocationCoordinates = widget.destinationCoordinates;

    locationController = TextEditingController(text: dropoffLocation);
  }

  @override
  void dispose() {
    locationController.dispose();
    flightController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void changeDirection(bool fromAirport) {
    if (fromAirport == airportPickup) return;

    FocusScope.of(context).unfocus();

    setState(() {
      airportPickup = fromAirport;
      locationController.text = airportPickup
          ? dropoffLocation
          : pickupLocation;
    });
  }

  void editLocation(String value) {
    setState(() {
      if (airportPickup) {
        dropoffLocation = value;
        dropoffLocationCoordinates = null;
      } else {
        pickupLocation = value;
        pickupLocationCoordinates = null;
      }
    });
  }

  Future<void> searchLocation({required bool airportPoint}) async {
    FocusScope.of(context).unfocus();

    final fromAirport = airportPickup;
    final selectedAirport = airport;

    final selected = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute<SelectedLocation>(
        builder: (_) => LocationPickerScreen(
          title: airportPoint
              ? 'Find $selectedAirport'
              : fromAirport
              ? 'Find drop-off'
              : 'Find pickup',
          confirmLabel: airportPoint
              ? 'Use airport meeting point'
              : fromAirport
              ? 'Use this drop-off'
              : 'Use this pickup',
        ),
      ),
    );

    if (!mounted || selected == null) return;
    if (airportPoint && airport != selectedAirport) return;

    final coordinates = TripCoordinates(
      latitude: selected.point.latitude,
      longitude: selected.point.longitude,
    );

    setState(() {
      if (airportPoint) {
        airportMeetingPoint = selected.name;
        airportCoordinates = coordinates;
      } else if (fromAirport) {
        dropoffLocation = selected.name;
        dropoffLocationCoordinates = coordinates;

        if (airportPickup) {
          locationController.text = selected.name;
        }
      } else {
        pickupLocation = selected.name;
        pickupLocationCoordinates = coordinates;

        if (!airportPickup) {
          locationController.text = selected.name;
        }
      }
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
      initialTime: travelTime ?? TimeOfDay.now(),
    );

    if (!mounted || selected == null) return;

    setState(() => travelTime = selected);
  }

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;

    if (travelDate == null || travelTime == null) {
      showMessage('Choose a pickup date and time.');
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
      showMessage('Choose a pickup time in the future.');
      return;
    }

    final location = locationController.text.trim();
    final otherCoordinates = locationCoordinates;
    final airportPoint = airportCoordinates;

    final samePoint =
        airportPoint != null &&
        otherCoordinates != null &&
        airportPoint.latitude == otherCoordinates.latitude &&
        airportPoint.longitude == otherCoordinates.longitude;

    final sameName =
        location.toLowerCase() == airport.toLowerCase() ||
        (airportMeetingPoint != null &&
            location.toLowerCase() ==
                airportMeetingPoint!.trim().toLowerCase());

    if (samePoint || sameName) {
      showMessage('Pickup and destination must be different.');
      return;
    }

    final flight = flightController.text.trim();

    final notes = [
      'Airport transfer',
      airportPickup ? 'From airport' : 'To airport',
      if (airportMeetingPoint != null)
        'Airport meeting point: $airportMeetingPoint',
      'Luggage: $bags bags',
      if (flight.isNotEmpty) 'Flight: $flight',
    ].join('\n');

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: airportPickup ? airport : location,
          destination: airportPickup ? location : airport,
          pickupCoordinates: airportPickup ? airportPoint : otherCoordinates,
          destinationCoordinates: airportPickup
              ? otherCoordinates
              : airportPoint,
          stops: const [],
          departure: departure,
          passengers: passengers,
          notes: notes,
        ),
      ),
    );
  }

  InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    Color iconColor = blue,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: muted, fontSize: 13),
      hintStyle: const TextStyle(color: muted),
      prefixIcon: Icon(icon, color: iconColor, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
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

  Widget selectedLocationLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF159A75), size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF159A75), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget scheduleRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: blue, size: 23),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget counter({
    required String title,
    required IconData icon,
    required int value,
    required int minimum,
    required int maximum,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: blue, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              counterButton(
                icon: Icons.remove,
                tooltip: 'Decrease $title',
                onPressed: value > minimum ? () => onChanged(value - 1) : null,
              ),
              Text(
                '$value',
                style: const TextStyle(
                  color: navy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              counterButton(
                icon: Icons.add,
                tooltip: 'Increase $title',
                onPressed: value < maximum ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget counterButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFEEF4FF),
        foregroundColor: blue,
        disabledBackgroundColor: const Color(0xFFF5F7FB),
        disabledForegroundColor: const Color(0xFFBCC5D4),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 19),
    );
  }

  Widget airportBanner() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F3FF), Color(0xFFD6E9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Stack(
        children: [
          Positioned(
            top: 15,
            left: 18,
            child: Icon(Icons.cloud, color: Colors.white, size: 45),
          ),
          Positioned(
            top: 8,
            right: 62,
            child: Icon(Icons.cloud, color: Color(0xFFF4F9FF), size: 52),
          ),
          Positioned(
            right: 12,
            bottom: -9,
            child: Icon(
              Icons.location_city,
              color: Color(0xFF8EBCEB),
              size: 85,
            ),
          ),
          Positioned(
            left: 36,
            bottom: 9,
            child: Icon(Icons.flight_takeoff, color: blue, size: 77),
          ),
          Positioned(
            right: 108,
            bottom: 13,
            child: Icon(
              Icons.airplanemode_active,
              color: Color(0xFF6B9FD8),
              size: 29,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = travelDate == null
        ? 'Choose date'
        : MaterialLocalizations.of(context).formatMediumDate(travelDate!);

    final timeLabel = travelTime == null
        ? 'Choose time'
        : travelTime!.format(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: navy),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Airport transfer',
                        style: TextStyle(
                          color: navy,
                          fontSize: 19,
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        airportBanner(),
                        const SizedBox(height: 14),
                        const Text(
                          'Your airport journey',
                          style: TextStyle(
                            color: navy,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Plan your ride to or from the airport.',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              foregroundColor: muted,
                              selectedForegroundColor: blue,
                              selectedBackgroundColor: const Color(0xFFEEF4FF),
                              side: const BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text('From airport'),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text('To airport'),
                              ),
                            ],
                            selected: {airportPickup},
                            onSelectionChanged: (selection) {
                              changeDirection(selection.first);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: airport,
                          isExpanded: true,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: fieldDecoration(
                            label: airportPickup
                                ? 'Pickup airport'
                                : 'Drop-off airport',
                            icon: Icons.local_airport,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Bandaranaike Airport (CMB)',
                              child: Text(
                                'Bandaranaike Airport (CMB)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Mattala Airport (HRI)',
                              child: Text('Mattala Airport (HRI)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null || value == airport) {
                              return;
                            }

                            setState(() {
                              airport = value;
                              airportCoordinates = null;
                              airportMeetingPoint = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        scheduleRow(
                          label: 'Airport terminal / meeting point',
                          value:
                              airportMeetingPoint ?? 'Search airport location',
                          icon: Icons.pin_drop_outlined,
                          onTap: () => searchLocation(airportPoint: true),
                        ),
                        if (airportCoordinates != null)
                          selectedLocationLabel(
                            'Airport map location selected',
                          ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: locationController,
                          onChanged: editLocation,
                          textCapitalization: TextCapitalization.words,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: fieldDecoration(
                            label: airportPickup
                                ? 'Drop-off location'
                                : 'Pickup location',
                            icon: Icons.location_on,
                            iconColor: const Color(0xFFE85D75),
                            suffix: IconButton(
                              tooltip: airportPickup
                                  ? 'Search drop-off'
                                  : 'Search pickup',
                              onPressed: () =>
                                  searchLocation(airportPoint: false),
                              icon: const Icon(
                                Icons.search,
                                color: blue,
                                size: 22,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return airportPickup
                                  ? 'Enter a drop-off location'
                                  : 'Enter a pickup location';
                            }

                            return null;
                          },
                        ),
                        if (locationCoordinates != null)
                          selectedLocationLabel('Map location selected'),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: flightController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: fieldDecoration(
                            label: 'Flight number (optional)',
                            hint: 'For example: UL308',
                            icon: Icons.flight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        scheduleRow(
                          label: 'Pickup date',
                          value: dateLabel,
                          icon: Icons.calendar_month_outlined,
                          onTap: chooseDate,
                        ),
                        const SizedBox(height: 10),
                        scheduleRow(
                          label: 'Pickup time',
                          value: timeLabel,
                          icon: Icons.access_time,
                          onTap: chooseTime,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final passengerCounter = counter(
                              title: 'Passengers',
                              icon: Icons.person_outline,
                              value: passengers,
                              minimum: 1,
                              maximum: 15,
                              onChanged: (value) {
                                setState(() => passengers = value);
                              },
                            );

                            final luggageCounter = counter(
                              title: 'Luggage',
                              icon: Icons.luggage_outlined,
                              value: bags,
                              minimum: 0,
                              maximum: 20,
                              onChanged: (value) {
                                setState(() => bags = value);
                              },
                            );

                            if (constraints.maxWidth < 300) {
                              return Column(
                                children: [
                                  passengerCounter,
                                  const SizedBox(height: 10),
                                  luggageCounter,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: passengerCounter),
                                const SizedBox(width: 10),
                                Expanded(child: luggageCounter),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          airportPickup
                              ? 'Choose a pickup time that allows for '
                                    'immigration and baggage collection.'
                              : 'Choose a pickup time that allows enough '
                                    'time to reach the airport before '
                                    'your flight.',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Search both map locations to view the trip '
                          'map later. Confirm the correct airport '
                          'terminal when selecting its meeting point.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Demo booking. Vehicle selection checks '
                          'passenger seats; luggage space must be '
                          'confirmed separately.',
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
                    child: FilledButton(
                      onPressed: continueBooking,
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
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
