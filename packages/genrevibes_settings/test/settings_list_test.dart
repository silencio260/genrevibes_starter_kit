import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_settings/genrevibes_settings.dart';

void main() {
  group('SettingsList layout', () {
    testWidgets('renders sections, headings, and rows', (tester) async {
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            title: 'General',
            items: <SettingsItem>[
              SettingsAction(title: 'Account', onTap: () {}),
            ],
          ),
        ],
      );

      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('is embeddable and builds no Scaffold of its own',
        (tester) async {
      // A widget that owns the whole screen cannot be reused by an app whose
      // settings live inside a larger page.
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            items: const <SettingsItem>[
              SettingsInfo(title: 'Version', value: '1.0'),
            ],
          ),
        ],
      );

      expect(
        find.descendant(
          of: find.byType(SettingsList),
          matching: find.byType(Scaffold),
        ),
        findsNothing,
      );
    });

    testWidgets('skips empty sections', (tester) async {
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(title: 'Empty', items: const <SettingsItem>[]),
          SettingsSection(
            title: 'Visible',
            items: const <SettingsItem>[
              SettingsInfo(title: 'Version', value: '1'),
            ],
          ),
        ],
      );

      expect(find.text('EMPTY'), findsNothing);
      expect(find.text('VISIBLE'), findsOneWidget);
    });

    testWidgets('renders a section footer when supplied', (tester) async {
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            footer: 'Saves media automatically.',
            items: <SettingsItem>[
              SettingsToggle(
                  title: 'Auto save', value: true, onChanged: (_) {}),
            ],
          ),
        ],
      );

      expect(find.text('Saves media automatically.'), findsOneWidget);
    });

    testWidgets('the plain style does not uppercase headings', (tester) async {
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            title: 'General',
            items: const <SettingsItem>[
              SettingsInfo(title: 'x', value: 'y'),
            ],
          ),
        ],
        style: SettingsListStyle.plain,
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.text('GENERAL'), findsNothing);
    });
  });

  group('SettingsTile behavior', () {
    testWidgets('an action reports taps', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            items: <SettingsItem>[
              SettingsAction(title: 'Rate us', onTap: () => tapped = true),
            ],
          ),
        ],
      );

      await tester.tap(find.text('Rate us'));

      expect(tapped, isTrue);
    });

    testWidgets('an action with no callback is disabled', (tester) async {
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            items: const <SettingsItem>[
              SettingsAction(title: 'Unavailable', onTap: null),
            ],
          ),
        ],
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);
    });

    testWidgets('a toggle reports changes', (tester) async {
      bool? changed;
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            items: <SettingsItem>[
              SettingsToggle(
                title: 'Auto save',
                value: false,
                onChanged: (value) => changed = value,
              ),
            ],
          ),
        ],
      );

      await tester.tap(find.byType(SwitchListTile));

      expect(changed, isTrue);
    });

    testWidgets('an info row shows its value and stays inert', (tester) async {
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            items: const <SettingsItem>[
              SettingsInfo(title: 'Version', value: '1.5.1'),
            ],
          ),
        ],
      );

      expect(find.text('1.5.1'), findsOneWidget);
      expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
    });

    testWidgets('a custom row renders caller content', (tester) async {
      await _pump(
        tester,
        <SettingsSection>[
          SettingsSection(
            items: <SettingsItem>[
              SettingsCustom(
                title: 'Promo',
                builder: (context) => const Text('upgrade banner'),
              ),
            ],
          ),
        ],
      );

      expect(find.text('upgrade banner'), findsOneWidget);
    });
  });

  group('models', () {
    test('items report whether they are interactive', () {
      expect(const SettingsAction(title: 'x', onTap: null).isEnabled, isFalse);
      expect(SettingsAction(title: 'x', onTap: () {}).isEnabled, isTrue);
      expect(
        const SettingsToggle(title: 'x', value: true, onChanged: null)
            .isEnabled,
        isFalse,
      );
      expect(const SettingsInfo(title: 'x', value: 'y').isEnabled, isFalse);
    });

    test('a section copies its items so a list cannot change after build', () {
      final items = <SettingsItem>[const SettingsInfo(title: 'x', value: 'y')];
      final section = SettingsSection(items: items);

      expect(() => section.items.clear(), throwsUnsupportedError);
      expect(section.isEmpty, isFalse);
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<SettingsSection> sections, {
  SettingsListStyle style = SettingsListStyle.grouped,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsList(sections: sections, style: style),
      ),
    ),
  );
}
