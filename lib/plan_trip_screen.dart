import 'package:flutter/material.dart';

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
      showMessage('Please choose a travel date and time.');
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

    final stops = stopControllers
        .map((controller) => controller.text.trim())
        .join(', ');

    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(travelDate!);
    final timeLabel = travelTime!.format(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trip details ready'),
        content: SingleChildScrollView(
          child: Text(
            'Pickup: ${pickupController.text.trim()}\n'
            '${stops.isEmpty ? '' : 'Stops: $stops\n'}'
            'Destination: ${destinationController.text.trim()}\n'
            'Date: $dateLabel\n'
            'Time: $timeLabel\n'
            'Passengers: $passengers\n\n'
            'Vehicle selection will be added next.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final dateLabel = travelDate == null
        ? 'Choose date'
        : MaterialLocalizations.of(context).formatMediumDate(travelDate!);

    final timeLabel = travelTime == null
        ? 'Choose time'
        : travelTime!.format(context);

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
                    'Book a one-way trip with optional stops.',
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
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Colors.teal,
                      ),
                      title: const Text('Travel date'),
                      subtitle: Text(dateLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: chooseDate,
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.teal,
                      ),
                      title: const Text('Departure time'),
                      subtitle: Text(timeLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: chooseTime,
                    ),
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
