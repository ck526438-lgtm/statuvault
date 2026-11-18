import 'package:flutter_test/flutter_test.dart';
import 'package:statuvault/status_service.dart';

void main() {
  test('libellés des applis', () {
    expect(WaApp.whatsapp.package, 'com.whatsapp');
    expect(WaApp.business.package, 'com.whatsapp.w4b');
  });
}
