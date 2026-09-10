import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genrevibes_developer_access/genrevibes_developer_access.dart';

import '../widgets/action_row.dart';
import '../widgets/dev_scaffold.dart';

/// Developer access: why this device has it, and the hash to list it under.
class DevDeveloperAccessPage extends StatelessWidget {
  /// Creates the page.
  const DevDeveloperAccessPage({required this.controller, super.key});

  /// The controller that owns the decision.
  final DeveloperAccessController controller;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Developer access',
      subtitle: describeDeveloperAccess(controller.current.reason),
      builder: (refresh) {
        final access = controller.current;
        return <Widget>[
          const DevHeading('This device'),
          DevFact('Access', describeDeveloperAccess(access.reason)),
          DevFact(
            'Ads',
            access.servesTestAds ? 'test inventory' : 'live inventory',
          ),
          DevFact('Device hash', access.deviceHash ?? 'unresolved'),
          DevFact(
            'Listed in',
            access.listedIn.isEmpty
                ? 'no list'
                : access.listedIn.map((list) => list.name).join(', '),
          ),
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
            'It is a one-way hash of the Android app set ID or the iOS '
            'identifierForVendor. The identifier itself is never stored, '
            'logged or listed, and the hash cannot be turned back into it.',
          ),
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
