library test_power;

import 'package:unittest/unittest.dart';

import 'package:chrome/app.dart';

void main() {
  group('chrome.power', () {
    test('requestKeepAwake', () {
      // test that calling these methods do not throw
      power.requestKeepAwake(ChromePower.SYSTEM);
      power.requestKeepAwake(ChromePower.SYSTEM);

      // call release to ensure that we don't keep the display on after the
      // tests run
      power.releaseKeepAwake();
    });

    test('releaseKeepAwake', () {
      // test that calling this method does not throw
      power.releaseKeepAwake();
    });
  });
}

