import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genrevibes_developer_access/genrevibes_developer_access.dart';
import 'package:genrevibes_device_identity/genrevibes_device_identity.dart';

import '../widgets/action_row.dart';
import '../widgets/dev_scaffold.dart';

/// Developer access: why this device has it, and every identifier a developer
/// needs from it, shown on screen with a copy button each.
class DevDeveloperAccessPage extends StatelessWidget {
  /// Creates the page.
  const DevDeveloperAccessPage({
    required this.controller,
    super.key,
    this.identity,
    this.advertisingId,
  });

  /// The controller that owns the decision.
  final DeveloperAccessController controller;

  /// The resolved identity, for the unhashed device ID. Null hides the row.
  final DeviceIdentityResolver? identity;

  /// Reads this phone's advertising ID on demand. Null hides the row.
  final AdvertisingIdSource? advertisingId;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Developer access',
      subtitle: describeDeveloperAccess(controller.current.reason),
      builder: (refresh) {
        final access = controller.current;
        final vendorId = identity?.current?.vendorId;
        return <Widget>[
          const DevHeading('This device'),
          DevFact('Access', describeDeveloperAccess(access.reason)),
          DevFact(
            'Ads',
            access.servesTestAds ? 'test inventory' : 'live inventory',
          ),
          DevFact(
            'Listed in',
            access.listedIn.isEmpty
                ? 'no list'
                : access.listedIn.map((list) => list.name).join(', '),
          ),
          const DevHeading('Identifiers'),
          if (identity != null) ...<Widget>[
            DevFact('Device ID (unhashed)', vendorId ?? 'unresolved'),
            ActionRow(
              label: 'Copy device ID',
              subtitle: 'For checking only. A list takes the hash below, '
                  'never this.',
              icon: Icons.copy,
              run: () async {
                if (vendorId == null) {
                  return 'No device identifier was resolved.';
                }
                await Clipboard.setData(ClipboardData(text: vendorId));
                return 'Copied';
              },
            ),
          ],
          DevFact('Device hash', access.deviceHash ?? 'unresolved'),
          ActionRow(
            label: 'Copy device hash',
            subtitle: 'The value to add to a developer device list.',
            icon: Icons.copy,
            run: () async {
              final hash = access.deviceHash;
              if (hash == null) return 'No device identifier was resolved.';
              await Clipboard.setData(ClipboardData(text: hash));
              return 'Copied';
            },
          ),
          const DevNote(
            'List this hash to give this phone the developer tools and test '
            'ads in the store build. Any one list is enough:\n'
            '• hardcoded in the app, for phones that should always have it\n'
            '• developer_device_hashes in the env file, comma separated\n'
            '• developer_device_hashes in remote config, a JSON array — takes '
            'effect on the next fetch, no release\n\n'
            'It is a one-way hash of the device ID above: the Android app set '
            'ID or the iOS identifierForVendor. That ID is shown only here, on '
            'this phone, and is never stored, logged or listed; the hash '
            'cannot be turned back into it.',
          ),
          if (advertisingId case final source?) ...<Widget>[
            FutureBuilder<String>(
              // Read again on every refresh, and never kept.
              future: _describeAdvertisingId(source),
              builder: (context, reading) =>
                  DevFact('Advertising ID', reading.data ?? 'reading…'),
            ),
            ActionRow(
              label: 'Copy advertising ID',
              subtitle: 'To register this phone as a test device in an ad '
                  'network.',
              icon: Icons.copy,
              run: () async {
                final (authorization, id) = await _readAdvertisingId(source);
                if (id == null) {
                  return 'No advertising ID: '
                      '${_unavailableReason(authorization)}.';
                }
                await Clipboard.setData(ClipboardData(text: id));
                return 'Copied';
              },
            ),
            const DevNote(
              'The Google advertising ID on Android, the IDFA on iOS: what ad '
              'networks recognise a test device by. It is read only when this '
              'page asks, and never stored, logged or sent. It is absent when '
              'the user deleted it or turned ad personalisation off (Android), '
              'or has not allowed tracking (iOS: Identity & engagement → '
              'Resolve and prompt for tracking). It plays no part in developer '
              'access.',
            ),
          ],
          const DevHeading('Passcode'),
          DevFact(
            'Entry',
            access.lockedOut
                ? 'locked out'
                : '${access.attemptsRemaining} attempts remaining',
          ),
          ActionRow(
            label: 'Clear passcode lockout',
            subtitle: 'A development build clears it on launch as well.',
            icon: Icons.lock_reset,
            run: () async {
              final result = await controller.resetLockout();
              refresh();
              return result;
            },
          ),
        ];
      },
    );
  }
}

/// A human label for [reason].
String describeDeveloperAccess(DeveloperAccessReason reason) =>
    switch (reason) {
      DeveloperAccessReason.none => 'No access',
      DeveloperAccessReason.developmentBuild => 'Development build',
      DeveloperAccessReason.listedDevice => 'Listed developer device',
      DeveloperAccessReason.passcode => 'Passcode, until the app closes',
    };

/// Reads the advertising ID, asking for it only when tracking is authorized.
Future<(TrackingAuthorization, String?)> _readAdvertisingId(
  AdvertisingIdSource source,
) async {
  final authorization = await source.authorization();
  final id = authorization == TrackingAuthorization.authorized
      ? await source.advertisingId()
      : null;
  return (authorization, id);
}

Future<String> _describeAdvertisingId(AdvertisingIdSource source) async {
  try {
    final (authorization, id) = await _readAdvertisingId(source);
    return id ?? 'none (${_unavailableReason(authorization)})';
  } on Object catch (error) {
    return 'could not be read: $error';
  }
}

String _unavailableReason(TrackingAuthorization authorization) =>
    switch (authorization) {
      TrackingAuthorization.authorized => 'the platform returned none',
      TrackingAuthorization.notDetermined =>
        'tracking permission not asked yet',
      TrackingAuthorization.denied => 'deleted or turned off by the user',
      TrackingAuthorization.restricted => 'restricted by device policy',
      TrackingAuthorization.notSupported => 'not available on this platform',
    };
