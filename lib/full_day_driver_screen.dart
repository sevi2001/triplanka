import 'package:flutter/material.dart';
import 'vehicle_selection_screen.dart';

class FullDayDriverScreen extends StatefulWidget {
  const FullDayDriverScreen({
    super.key,
    this.pickup = '',
    this.destination = '',
  });

  final String pickup;
  final String destination;

  @override
  State<FullDayDriverScreen> createState() => _FullDayDriverScreenState();
}

class _FullDayDriverScreenState extends State<FullDayDriverScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController pickupController;
  late final TextEditingController placesController;

  DateTime? travelDate;
  TimeOfDay? startTime;

  int passengers = 1;
  int packageIndex = 0;
  bool returnToPickup = true;

  static const packages = [
    (name: 'Half day', hours: 4, kilometres: 50),
    (name: 'Full day', hours: 8, kilometres: 100),
    (name: 'Extended day', hours: 12, kilometres: 150),
  ];

  @override
  void initState() {
    super.initState();

    pickupController = TextEditingController(text: widget.pickup);

    placesController = TextEditingController(text: widget.destination);
  }

  @override
  void dispose() {
    pickupController.dispose();
    placesController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      initialTime: startTime ?? TimeOfDay.now(),
    );

    if (!mounted || selected == null) return;

    setState(() {
      startTime = selected;
    });
  }

  List<String> readPlaces(String text) {
    return text
        .split('\n')
        .map((place) => place.trim())
        .where((place) => place.isNotEmpty)
        .toList();
  }

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) {
      showMessage('Enter your pickup and places to visit.');
      return;
    }

    if (travelDate == null || startTime == null) {
      showMessage('Choose a date and start time.');
      return;
    }

    final departure = DateTime(
      travelDate!.year,
      travelDate!.month,
      travelDate!.day,
      startTime!.hour,
      startTime!.minute,
    );

    if (!departure.isAfter(DateTime.now())) {
      showMessage('Choose a start time in the future.');
      return;
    }

    final pickup = pickupController.text.trim();
    final places = readPlaces(placesController.text);
    final package = packages[packageIndex];

    // For a return journey, every visited place is a stop.
    // Otherwise, the last place is the final destination.
    final destination = returnToPickup ? pickup : places.last;

    final stops = returnToPickup
        ? places
        : places.take(places.length - 1).toList();

    final notes = [
      'Driver hire: ${package.name}',
      'Sample package: ${package.hours} hours / '
          '${package.kilometres} km',
      'Return to pickup: ${returnToPickup ? 'Yes' : 'No'}',
      'Package pricing and extra charges are not set yet.',
    ].join('\n');

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: pickup,
          destination: destination,
          stops: stops,
          departure: departure,
          passengers: passengers,
          notes: notes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = travelDate == null
        ? 'Choose date'
        : MaterialLocalizations.of(context).formatMediumDate(travelDate!);

    final timeLabel = startTime == null
        ? 'Choose time'
        : startTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Full-day driver')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 64,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Explore at your own pace',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Plan a day out with a vehicle and driver.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: pickupController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup location',
                      prefixIcon: Icon(Icons.my_location, color: Colors.teal),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a pickup location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: placesController,
                    minLines: 3,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Places to visit',
                      hintText: 'Kandy\nPeradeniya\nNuwara Eliya',
                      helperText: 'Enter one place per line, in visit order.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (readPlaces(value ?? '').isEmpty) {
                        return 'Enter at least one place';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Return to pickup'),
                    subtitle: const Text('End the journey where it started.'),
                    value: returnToPickup,
                    onChanged: (value) {
                      setState(() {
                        returnToPickup = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose a sample package',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < packages.length; i++)
                    Card(
                      color: packageIndex == i
                          ? const Color(0xFFE0F2F1)
                          : Colors.white,
                      child: ListTile(
                        title: Text(packages[i].name),
                        subtitle: Text(
                          '${packages[i].hours} hours / '
                          '${packages[i].kilometres} km',
                        ),
                        trailing: Icon(
                          packageIndex == i
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: Colors.teal,
                        ),
                        onTap: () {
                          setState(() {
                            packageIndex = i;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'These are prototype packages. Prices, '
                    'extra-hour rates, and extra-kilometre '
                    'rates will be added later.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Colors.teal,
                      ),
                      title: const Text('Travel date'),
                      subtitle: Text(dateLabel),
                      onTap: chooseDate,
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.teal,
                      ),
                      title: const Text('Start time'),
                      subtitle: Text(timeLabel),
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
                    child: const Text('Choose vehicle'),
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
