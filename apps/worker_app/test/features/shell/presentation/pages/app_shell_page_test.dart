import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/shell/presentation/pages/app_shell_page.dart';

void main() {
  group('workerShellDestinationIndexForLocation', () {
    test('keeps Profile selected on profile detail routes', () {
      expect(workerShellDestinationIndexForLocation('/profile/kyc'), 4);
      expect(
          workerShellDestinationIndexForLocation('/profile/payout-change'), 4);
    });

    test('selects the matching primary destination', () {
      expect(workerShellDestinationIndexForLocation('/schedule'), 1);
      expect(workerShellDestinationIndexForLocation('/jobs'), 2);
      expect(workerShellDestinationIndexForLocation('/earnings'), 3);
    });

    test('falls back to Dashboard for non-shell locations', () {
      expect(workerShellDestinationIndexForLocation('/support'), 0);
    });
  });
}
