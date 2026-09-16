import 'package:flutter_test/flutter_test.dart';
import 'package:nile_tropical/core/theme/nile_colors.dart';

void main() {
  test('primary is Nile blue', () {
    // ignore: deprecated_member_use
    expect(NileColors.primary.value, 0xFF233E85);
  });

  test('status colours match contract', () {
    // ignore: deprecated_member_use
    expect(NileColors.success.value, 0xFF1F7A4D);
    // ignore: deprecated_member_use
    expect(NileColors.warning.value, 0xFFB7791F);
    // ignore: deprecated_member_use
    expect(NileColors.error.value, 0xFFB42318);
  });
}
