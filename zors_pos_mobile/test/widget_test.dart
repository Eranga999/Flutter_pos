import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zors_pos_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZorsPosApp());

    // Verify that app loads
    await tester.pump();
  });
}
