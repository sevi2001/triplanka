import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'booking_store.dart';

class TripRequestEntry {
  const TripRequestEntry({
    required this.id,
    required this.ownerId,
    required this.booking,
    this.status = 'pending',
    this.driverId,
  });

  final String id;
  final String ownerId;
  final TripBooking booking;
  final String status;
  final String? driverId;

  bool get accepted => status == 'accepted';
  bool get cancelled => status == 'cancelled';

  factory TripRequestEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final storedDriverId = data['driverId'];

    return TripRequestEntry(
      id: document.id,
      ownerId: data['ownerId'] as String,
      booking: TripBooking.fromJson(
        Map<String, dynamic>.from(data['trip'] as Map),
      ),
      status: data['status'] as String? ?? 'pending',
      driverId: storedDriverId is String ? storedDriverId : null,
    );
  }
}

class TripRequestStore {
  TripRequestStore._();

  static CollectionReference<Map<String, dynamic>> get requests =>
      FirebaseFirestore.instance.collection('tripRequests');

  static List<TripRequestEntry> _readEntries(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final entries = snapshot.docs.map(TripRequestEntry.fromDocument).toList();

    entries.sort((a, b) => a.booking.departure.compareTo(b.booking.departure));

    return List<TripRequestEntry>.unmodifiable(entries);
  }

  static Stream<List<TripRequestEntry>> watchAvailable(String vehicleType) {
    return requests
        .where('status', isEqualTo: 'pending')
        .where('trip.vehicle', isEqualTo: vehicleType)
        .snapshots()
        .map(_readEntries);
  }

  static Stream<List<TripRequestEntry>> watchAssigned(String driverId) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != driverId) {
      throw StateError('Sign in with the correct driver account.');
    }

    // Keep cancelled trips visible if this driver accepted them earlier.
    return requests
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map(_readEntries);
  }

  static Future<void> accept(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please sign in again.');
    }

    if (requestId.trim().isEmpty) {
      throw ArgumentError('A trip request ID is required.');
    }

    final database = FirebaseFirestore.instance;
    final driverDocument = database.collection('drivers').doc(user.uid);
    final requestDocument = requests.doc(requestId);

    await database.runTransaction<void>((transaction) async {
      final driverSnapshot = await transaction.get(driverDocument);
      final requestSnapshot = await transaction.get(requestDocument);

      final driver = driverSnapshot.data();
      final request = requestSnapshot.data();

      if (driver == null || driver['status'] != 'approved') {
        throw StateError('Your driver profile must be approved.');
      }

      if (request == null || request['status'] != 'pending') {
        throw StateError('This trip is no longer available. Refresh the list.');
      }

      if (request['ownerId'] == user.uid) {
        throw StateError('You cannot accept your own trip.');
      }

      final trip = TripBooking.fromJson(
        Map<String, dynamic>.from(request['trip'] as Map),
      );

      final seats = driver['passengerCapacity'];

      if (trip.vehicle != driver['vehicleType'] ||
          seats is! int ||
          trip.passengers > seats) {
        throw StateError('Your vehicle does not fit this trip.');
      }

      if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw StateError('Your account changed.');
      }

      transaction.update(requestDocument, {
        'status': 'accepted',
        'driverId': user.uid,
        'driverName': driver['name'],
        'driverPhone': driver['phone'],
        'driverRegistration': driver['registrationNumber'],
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
