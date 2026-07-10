import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  test('bundled Lottie assets parse', () async {
    for (final name in ['success_check.json', 'confetti_burst.json']) {
      final bytes = await File('assets/lottie/$name').readAsBytes();
      final composition = await LottieComposition.fromBytes(bytes);
      expect(composition.duration.inMilliseconds, greaterThan(0),
          reason: name);
    }
  });
}
