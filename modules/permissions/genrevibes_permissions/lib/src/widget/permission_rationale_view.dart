import 'package:flutter/material.dart';

/// Explains why a permission is needed before the system prompt appears.
///
/// Theme-driven and embeddable: no `Scaffold`, no `AppBar`. The host places it
/// in a route, a sheet, or a dialog and supplies the copy; wording is the one
/// part of a permission flow that must be specific to the feature asking.
final class PermissionRationaleView extends StatelessWidget {
  /// Creates a rationale view.
  const PermissionRationaleView({
    required this.title,
    required this.explanation,
    required this.ctaLabel,
    required this.onGrant,
    super.key,
    this.steps = const <String>[],
    this.icon,
    this.isLoading = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Headline.
  final String title;

  /// Why the permission is needed, in the user's terms.
  final String explanation;

  /// Numbered instructions when the OS flow needs the user to do something.
  final List<String> steps;

  /// Optional leading icon.
  final IconData? icon;

  /// Primary action label.
  final String ctaLabel;

  /// Primary action. Disabled while [isLoading].
  final VoidCallback onGrant;

  /// Whether a request is in flight.
  final bool isLoading;

  /// Optional secondary action label, such as "Not now" or "Open settings".
  final String? secondaryLabel;

  /// Optional secondary action.
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              explanation,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (steps.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                            Text(steps[i], style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: isLoading ? null : onGrant,
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(ctaLabel),
            ),
            if (secondaryLabel != null && onSecondary != null)
              TextButton(
                onPressed: isLoading ? null : onSecondary,
                child: Text(secondaryLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
