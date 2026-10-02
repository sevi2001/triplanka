import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripCoordinates {
  const TripCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  factory TripCoordinates.fromJson(Map<String, dynamic> json) {
    return TripCoordinates(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class TripBooking {
  TripBooking({
    required this.pickup,
    required this.destination,
    required List<String> stops,
    required this.departure,
    required this.passengers,
    required this.vehicle,
    this.notes = '',
    this.pickupCoordinates,
    this.destinationCoordinates,
  }) : stops = List.unmodifiable(stops);

  final String pickup;
  final String destination;
  final List<String> stops;
  final DateTime departure;
  final int passengers;
  final String vehicle;
  final String notes;

  final TripCoordinates? pickupCoordinates;
  final TripCoordinates? destinationCoordinates;

  Map<String, dynamic> toJson() {
    return {
      'pickup': pickup,
      'destination': destination,
      'stops': stops,
      'departure': departure.toIso8601String(),
      'passengers': passengers,
      'vehicle': vehicle,
      'notes': notes,
      'pickupCoordinates': pickupCoordinates?.toJson(),
      'destinationCoordinates': destinationCoordinates?.toJson(),
    };
  }

  factory TripBooking.fromJson(Map<String, dynamic> json) {
    final pickupData = json['pickupCoordinates'];
    final destinationData = json['destinationCoordinates'];

    return TripBooking(
      pickup: json['pickup'] as String,
      destination: json['destination'] as String,
      stops: List<String>.from(json['stops'] as List),
      departure: DateTime.parse(json['departure'] as String),
      passengers: json['passengers'] as int,
      vehicle: json['vehicle'] as String,
      notes: json['notes'] as String? ?? '',
      pickupCoordinates: pickupData == null
          ? null
          : TripCoordinates.fromJson(
              Map<String, dynamic>.from(pickupData as Map),
            ),
      destinationCoordinates: destinationData == null
          ? null
          : TripCoordinates.fromJson(
              Map<String, dynamic>.from(destinationData as Map),
            ),
    );
  }
}

class BookingStore {
  static const storageKey = 'triplanka_demo_bookings_v1';

  static final preferences = SharedPreferencesAsync();

  static final bookings = ValueNotifier<List<TripBooking>>(const []);

  static Future<void> load() async {
    final stored = await preferences.getString(storageKey);

    if (stored == null) {
      bookings.value = const [];
      return;
    }

    final decoded = jsonDecode(stored) as List<dynamic>;

    final loaded = decoded.map((item) {
      return TripBooking.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();

    bookings.value = List.unmodifiable(loaded);
  }

  static Future<void> add(TripBooking booking) async {
    final updated = [booking, ...bookings.value];

    final encoded = jsonEncode(updated.map((item) => item.toJson()).toList());

    // Update the screen only after storage succeeds.
    await preferences.setString(storageKey, encoded);

    bookings.value = List.unmodifiable(updated);
  }
}
