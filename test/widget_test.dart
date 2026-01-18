import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_item_tracker_client/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusLostAndFoundApp());

    expect(find.text('Campus Lost & Found'), findsOneWidget);
  });
}
