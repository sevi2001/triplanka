import 'package:flutter/foundation.dart';

class TripBooking {
  TripBooking({
    required this.pickup,
    required this.destination,
    required List<String> stops,
    required this.departure,
    required this.passengers,
    required this.vehicle,
  }) : stops = List.unmodifiable(stops);

  final String pickup;
  final String destination;
  final List<String> stops;
  final DateTime departure;
  final int passengers;
  final String vehicle;
}

class BookingStore {
  static final bookings = ValueNotifier<List<TripBooking>>(const []);

  static void add(TripBooking booking) {
    bookings.value = List.unmodifiable([booking, ...bookings.value]);
  }
}
