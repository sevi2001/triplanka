import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:triplanka/booking_store.dart';
import 'package:triplanka/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Use temporary in-memory storage instead of device storage.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    await BookingStore.load();
  });

  testWidgets('Home passes locations to trip planning form', (tester) async {
    await tester.pumpWidget(const TripLankaApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Colombo');

    await tester.enterText(find.byType(TextField).at(1), 'Ella');

    final planTripButton = find.text('Plan a trip');

    await tester.ensureVisible(planTripButton);
    await tester.pumpAndSettle();

    await tester.tap(planTripButton);
    await tester.pumpAndSettle();

    expect(find.text('Plan your journey'), findsOneWidget);

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();

    expect(fields[0].controller!.text, 'Colombo');
    expect(fields[1].controller!.text, 'Ella');
  });
}
