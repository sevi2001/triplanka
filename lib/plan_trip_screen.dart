import 'package:flutter/material.dart';
import 'vehicle_selection_screen.dart';

class PlanTripScreen extends StatefulWidget {
  const PlanTripScreen({super.key, this.pickup = '', this.destination = ''});

  final String pickup;
  final String destination;

  @override
  State<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController pickupController;
  late final TextEditingController destinationController;

  final List<TextEditingController> stopControllers = [];

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

      // Clear a return date that precedes the new outbound date.
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
        'Return from: ${destinationController.text.trim()}',
        'Return to: ${pickupController.text.trim()}',
        'Return departure: $dateLabel at $timeLabel',
        'Return stops are not specified.',
      ].join('\n');
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: pickupController.text.trim(),
          destination: destinationController.text.trim(),
          stops: stopControllers
              .map((controller) => controller.text.trim())
              .toList(),
          departure: departure,
          passengers: passengers,
          notes: notes,
        ),
      ),
    );
  }

  void addStop() {
    setState(() {
      stopControllers.add(TextEditingController());
    });
  }

  void removeStop(int index) {
    final removed = stopControllers[index];

    setState(() {
      stopControllers.removeAt(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      removed.dispose();
    });
  }

  Widget locationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validateLocation,
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
                  ),
                  const SizedBox(height: 14),

                  for (int i = 0; i < stopControllers.length; i++)
                    Padding(
                      key: ObjectKey(stopControllers[i]),
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: locationField(
                              controller: stopControllers[i],
                              label: 'Stop ${i + 1}',
                              icon: Icons.place_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove stop',
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => removeStop(i),
                          ),
                        ],
                      ),
                    ),

                  locationField(
                    controller: destinationController,
                    label: 'Destination',
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: addStop,
                    icon: const Icon(Icons.add),
                    label: const Text('Add stop'),
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
