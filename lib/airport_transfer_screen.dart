import 'package:flutter/material.dart';
import 'vehicle_selection_screen.dart';

class AirportTransferScreen extends StatefulWidget {
  const AirportTransferScreen({
    super.key,
    this.pickup = '',
    this.destination = '',
  });

  final String pickup;
  final String destination;

  @override
  State<AirportTransferScreen> createState() => _AirportTransferScreenState();
}

class _AirportTransferScreenState extends State<AirportTransferScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController locationController;
  final flightController = TextEditingController();

  bool airportPickup = true;
  String airport = 'Bandaranaike Airport (CMB)';
  DateTime? travelDate;
  TimeOfDay? travelTime;
  int passengers = 1;
  int bags = 0;

  @override
  void initState() {
    super.initState();

    locationController = TextEditingController(text: widget.destination);
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

  void continueBooking() {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) {
      showMessage('Enter your pickup or drop-off location.');
      return;
    }

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
    final flight = flightController.text.trim();

    final notes = [
      'Airport transfer',
      'Luggage: $bags bags',
      if (flight.isNotEmpty) 'Flight: $flight',
    ].join('\n');

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleSelectionScreen(
          pickup: airportPickup ? airport : location,
          destination: airportPickup ? location : airport,
          stops: const [],
          departure: departure,
          passengers: passengers,
          notes: notes,
        ),
      ),
    );
  }

  Widget counter({
    required String title,
    required int value,
    required int minimum,
    required int maximum,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text(title)),
            IconButton(
              tooltip: 'Decrease $title',
              onPressed: value > minimum ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Text(
              '$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'Increase $title',
              onPressed: value < maximum ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
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
      appBar: AppBar(title: const Text('Airport transfer')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.flight, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'Your airport journey',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('From airport')),
                      ButtonSegment(value: false, label: Text('To airport')),
                    ],
                    selected: {airportPickup},
                    onSelectionChanged: (selection) {
                      setState(() {
                        airportPickup = selection.first;
                        locationController.text = airportPickup
                            ? widget.destination
                            : widget.pickup;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: airport,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Airport',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Bandaranaike Airport (CMB)',
                        child: Text('Bandaranaike Airport (CMB)'),
                      ),
                      DropdownMenuItem(
                        value: 'Mattala Airport (HRI)',
                        child: Text('Mattala Airport (HRI)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        airport = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: airportPickup
                          ? 'Drop-off location'
                          : 'Pickup location',
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: Colors.teal,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: flightController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Flight number (optional)',
                      hintText: 'For example: UL308',
                      prefixIcon: Icon(Icons.flight),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Colors.teal,
                      ),
                      title: const Text('Pickup date'),
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
                      title: const Text('Pickup time'),
                      subtitle: Text(timeLabel),
                      onTap: chooseTime,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For airport pickup, allow time for '
                    'immigration and baggage collection.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  counter(
                    title: 'Passengers',
                    value: passengers,
                    minimum: 1,
                    maximum: 15,
                    onChanged: (value) {
                      setState(() {
                        passengers = value;
                      });
                    },
                  ),
                  counter(
                    title: 'Bags',
                    value: bags,
                    minimum: 0,
                    maximum: 20,
                    onChanged: (value) {
                      setState(() {
                        bags = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vehicle selection currently checks '
                    'passenger seats only. Luggage capacity '
                    'must be confirmed separately.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: continueBooking,
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
