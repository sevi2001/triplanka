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
  bool get inProgress => status == 'in_progress';
  bool get completed => status == 'completed';
  bool get cancelled => status == 'cancelled';

  String get statusLabel => switch (status) {
    'pending' => 'Waiting for driver',
    'accepted' => 'Accepted',
    'in_progress' => 'Trip in progress',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => 'Status unavailable',
  };

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

  static String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Please sign in again.');
    }

    return user.uid;
  }

  static void _validateRequestId(String requestId) {
    if (requestId.trim().isEmpty || requestId.contains('/')) {
      throw ArgumentError('A valid trip request ID is required.');
    }
  }

  static Stream<List<TripRequestEntry>> watchAvailable(String vehicleType) {
    return requests
        .where('status', isEqualTo: 'pending')
        .where('trip.vehicle', isEqualTo: vehicleType)
        .snapshots()
        .map(_readEntries);
  }

  static Stream<List<TripRequestEntry>> watchAssigned(String driverId) {
    if (_requireUserId() != driverId) {
      throw StateError('Sign in with the correct driver account.');
    }

    // Includes accepted, ongoing, completed and cancelled trips.
    return requests
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map(_readEntries);
  }

  static Future<void> accept(String requestId) async {
    _validateRequestId(requestId);

    final userId = _requireUserId();
    final database = FirebaseFirestore.instance;
    final driverDocument = database.collection('drivers').doc(userId);
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

      if (request['ownerId'] == userId) {
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

      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        throw StateError('Your account changed.');
      }

      transaction.update(requestDocument, {
        'status': 'accepted',
        'driverId': userId,
        'driverName': driver['name'],
        'driverPhone': driver['phone'],
        'driverRegistration': driver['registrationNumber'],
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> start(String requestId) {
    return _changeTripStatus(
      requestId: requestId,
      expectedStatus: 'accepted',
      nextStatus: 'in_progress',
      timestampField: 'startedAt',
    );
  }

  static Future<void> complete(String requestId) {
    return _changeTripStatus(
      requestId: requestId,
      expectedStatus: 'in_progress',
      nextStatus: 'completed',
      timestampField: 'completedAt',
    );
  }

  static Future<void> _changeTripStatus({
    required String requestId,
    required String expectedStatus,
    required String nextStatus,
    required String timestampField,
  }) async {
    _validateRequestId(requestId);

    final userId = _requireUserId();
    final database = FirebaseFirestore.instance;
    final driverDocument = database.collection('drivers').doc(userId);
    final requestDocument = requests.doc(requestId);

    await database.runTransaction<void>((transaction) async {
      final driverSnapshot = await transaction.get(driverDocument);
      final requestSnapshot = await transaction.get(requestDocument);

      final driver = driverSnapshot.data();
      final request = requestSnapshot.data();

      if (driver == null || driver['status'] != 'approved') {
        throw StateError('Your driver profile must be approved.');
      }

      if (request == null) {
        throw StateError('This trip request could not be found.');
      }

      if (request['driverId'] != userId) {
        throw StateError('Only the assigned driver can update this trip.');
      }

      if (request['status'] != expectedStatus) {
        throw StateError('The trip status has changed. Refresh your trips.');
      }

      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        throw StateError('Your account changed.');
      }

      transaction.update(requestDocument, {
        'status': nextStatus,
        timestampField: FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
