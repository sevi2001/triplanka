import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triplanka/main.dart';

void main() {
  testWidgets('Home passes journey details to booking page', (tester) async {
    await tester.pumpWidget(const TripLankaApp());

    expect(find.text('TripLanka'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Colombo');

    await tester.enterText(find.byType(TextField).at(1), 'Ella');

    final planTripButton = find.text('Plan a trip');

await tester.ensureVisible(planTripButton);
await tester.pumpAndSettle();

await tester.tap(planTripButton);
await tester.pumpAndSettle();

    expect(find.text('Journey details'), findsOneWidget);
    expect(find.text('Colombo'), findsOneWidget);
    expect(find.text('Ella'), findsOneWidget);
  });
}
