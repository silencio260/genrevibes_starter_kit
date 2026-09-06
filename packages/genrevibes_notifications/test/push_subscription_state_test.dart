import 'package:genrevibes_notifications/genrevibes_notifications.dart';
import 'package:test/test.dart';

void main() {
  test('diagnoses each independent reason delivery is unavailable', () {
    const state = PushSubscriptionState(
      providerId: 'test',
      permission: PushPermissionStatus.denied,
      canRequestPermission: false,
      optedIn: false,
    );

    expect(
      state.issues,
      containsAll(<PushDeliveryIssue>{
        PushDeliveryIssue.permissionNotGranted,
        PushDeliveryIssue.providerOptedOut,
        PushDeliveryIssue.missingSubscriptionId,
        PushDeliveryIssue.missingPushToken,
      }),
    );
    expect(state.isDeliverable, isFalse);
  });

  test('safe diagnostics never expose identifiers or tokens', () {
    const state = PushSubscriptionState(
      providerId: 'test',
      permission: PushPermissionStatus.authorized,
      canRequestPermission: false,
      optedIn: true,
      subscriptionId: 'secret-subscription',
      pushToken: 'secret-token',
      externalUserId: 'secret-user',
    );

    final diagnostics = state.toSafeDiagnostics();
    expect(state.isDeliverable, isTrue);
    expect(diagnostics.toString(), isNot(contains('secret-')));
    expect(diagnostics['hasSubscriptionId'], isTrue);
    expect(diagnostics['hasPushToken'], isTrue);
  });
}
