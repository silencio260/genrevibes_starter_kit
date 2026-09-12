import 'package:flutter/material.dart';

import 'exit_prompt_options.dart';

/// Shows an exit prompt.
abstract final class ExitPrompt {
  /// Shows [config]'s resolved style and returns what the user chose.
  ///
  /// Dismissing a sheet or dialog counts as staying. [ExitPromptStyle.doubleTap]
  /// and [ExitPromptStyle.none] have nothing to show and return exit at once;
  /// `ExitGuard` handles the double tap itself.
  static Future<ExitPromptResult> show(
    BuildContext context,
    ExitPromptConfig config,
  ) async {
    final style = config.resolvedStyle;
    final stay = ExitPromptResult(style: style, action: ExitPromptAction.stay);
    switch (style) {
      case ExitPromptStyle.doubleTap:
      case ExitPromptStyle.none:
        return ExitPromptResult(style: style, action: ExitPromptAction.exit);
      case ExitPromptStyle.adDialog:
      case ExitPromptStyle.confirmDialog:
        final chosen = await showDialog<ExitPromptResult>(
          context: context,
          builder: (dialogContext) {
            void choose(ExitPromptResult result) =>
                Navigator.of(dialogContext).pop(result);
            return style == ExitPromptStyle.adDialog
                ? _AdDialog(config: config, style: style, onChoose: choose)
                : _ConfirmDialog(
                    config: config, style: style, onChoose: choose);
          },
        );
        return chosen ?? stay;
      case ExitPromptStyle.adSheet:
      case ExitPromptStyle.featuresSheet:
      case ExitPromptStyle.offerSheet:
        final chosen = await showModalBottomSheet<ExitPromptResult>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            void choose(ExitPromptResult result) =>
                Navigator.of(sheetContext).pop(result);
            return switch (style) {
              ExitPromptStyle.adSheet =>
                _AdSheet(config: config, style: style, onChoose: choose),
              ExitPromptStyle.featuresSheet =>
                _FeaturesSheet(config: config, style: style, onChoose: choose),
              _ => _OfferSheet(config: config, style: style, onChoose: choose),
            };
          },
        );
        return chosen ?? stay;
    }
  }
}

typedef _Choose = void Function(ExitPromptResult result);

Color _accentOf(BuildContext context, ExitPromptConfig config) =>
    config.theme.accentColor ?? Theme.of(context).colorScheme.primary;

TextStyle? _titleStyle(BuildContext context, ExitPromptConfig config) =>
    config.theme.titleStyle ??
    Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1F1F1F),
        );

TextStyle? _messageStyle(BuildContext context, ExitPromptConfig config) =>
    config.theme.messageStyle ??
    Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF5F6368),
        );

/// The space kept for the ad, with the ad in it.
class _AdSlot extends StatelessWidget {
  const _AdSlot({required this.ad, required this.color});

  final ExitPromptAd ad;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: color,
          child: SizedBox(
            height: ad.height,
            width: double.infinity,
            child: ad.builder(context),
          ),
        ),
      );
}

/// Exit, standard or dimmed.
class _ExitButton extends StatelessWidget {
  const _ExitButton({
    required this.config,
    required this.onPressed,
    this.height,
    this.stadium = false,
  });

  final ExitPromptConfig config;
  final VoidCallback onPressed;
  final double? height;
  final bool stadium;

  @override
  Widget build(BuildContext context) {
    final theme = config.theme;
    final dimmed = config.exitButton == ExitButtonEmphasis.dimmed;
    return SizedBox(
      height: height ?? theme.buttonHeight,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: dimmed
              ? theme.dimmedExitBackground
              : theme.standardExitBackground,
          foregroundColor: dimmed
              ? theme.dimmedExitForeground
              : theme.standardExitForeground,
          shape: stadium
              ? const StadiumBorder()
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        child: Text(config.labels.exit),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({
    required this.config,
    required this.onPressed,
    this.height,
  });

  final ExitPromptConfig config;
  final VoidCallback onPressed;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height ?? config.theme.buttonHeight,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _accentOf(context, config),
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          child: Text(config.labels.cancel),
        ),
      );
}

/// A native ad above a full-width Exit bar.
class _AdSheet extends StatelessWidget {
  const _AdSheet({
    required this.config,
    required this.style,
    required this.onChoose,
  });

  final ExitPromptConfig config;
  final ExitPromptStyle style;
  final _Choose onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = config.theme;
    return Material(
      color: theme.surfaceColor,
      clipBehavior: Clip.antiAlias,
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(theme.cornerRadius)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _AdSlot(ad: config.ad!, color: theme.adBackgroundColor),
              const SizedBox(height: 12),
              _ExitButton(
                config: config,
                onPressed: () => onChoose(
                  ExitPromptResult(style: style, action: ExitPromptAction.exit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The exit question, a native ad, and Exit and Cancel.
class _AdDialog extends StatelessWidget {
  const _AdDialog({
    required this.config,
    required this.style,
    required this.onChoose,
  });

  final ExitPromptConfig config;
  final ExitPromptStyle style;
  final _Choose onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = config.theme;
    return Dialog(
      backgroundColor: theme.surfaceColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              config.labels.title,
              textAlign: TextAlign.center,
              style: _titleStyle(context, config),
            ),
            const SizedBox(height: 16),
            _AdSlot(ad: config.ad!, color: theme.adBackgroundColor),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ExitButton(
                    config: config,
                    height: 48,
                    stadium: true,
                    onPressed: () => onChoose(
                      ExitPromptResult(
                        style: style,
                        action: ExitPromptAction.exit,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CancelButton(
                    config: config,
                    height: 48,
                    onPressed: () => onChoose(
                      ExitPromptResult(
                        style: style,
                        action: ExitPromptAction.stay,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The exit question and a message, with Exit and Cancel.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.config,
    required this.style,
    required this.onChoose,
  });

  final ExitPromptConfig config;
  final ExitPromptStyle style;
  final _Choose onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = config.theme;
    return AlertDialog(
      backgroundColor: theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
      ),
      title: Text(config.labels.title, style: _titleStyle(context, config)),
      content: Text(
        config.labels.message,
        style: _messageStyle(context, config),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ExitButton(
                config: config,
                height: 48,
                stadium: true,
                onPressed: () => onChoose(
                  ExitPromptResult(style: style, action: ExitPromptAction.exit),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CancelButton(
                config: config,
                height: 48,
                onPressed: () => onChoose(
                  ExitPromptResult(style: style, action: ExitPromptAction.stay),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Features in a carousel, the ad when given, and the exit question.
class _FeaturesSheet extends StatelessWidget {
  const _FeaturesSheet({
    required this.config,
    required this.style,
    required this.onChoose,
  });

  final ExitPromptConfig config;
  final ExitPromptStyle style;
  final _Choose onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = config.theme;
    final accent = _accentOf(context, config);
    final ad = config.ad;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Material(
        color: theme.surfaceColor,
        clipBehavior: Clip.antiAlias,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.cornerRadius)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  config.labels.featuresTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _FeatureCarousel(
                  features: config.features,
                  accent: accent,
                  surface: theme.surfaceColor,
                  onSelected: (feature) => onChoose(
                    ExitPromptResult(
                      style: style,
                      action: ExitPromptAction.feature,
                      targetId: feature.id,
                    ),
                  ),
                ),
                if (ad != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _AdSlot(ad: ad, color: theme.adBackgroundColor),
                ],
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.exit_to_app, color: accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        config.labels.title,
                        style: _titleStyle(context, config),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  config.labels.message,
                  textAlign: TextAlign.center,
                  style: _messageStyle(context, config),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ExitButton(
                        config: config,
                        height: 52,
                        stadium: true,
                        onPressed: () => onChoose(
                          ExitPromptResult(
                            style: style,
                            action: ExitPromptAction.exit,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CancelButton(
                        config: config,
                        height: 52,
                        onPressed: () => onChoose(
                          ExitPromptResult(
                            style: style,
                            action: ExitPromptAction.stay,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCarousel extends StatefulWidget {
  const _FeatureCarousel({
    required this.features,
    required this.accent,
    required this.surface,
    required this.onSelected,
  });

  final List<ExitPromptFeature> features;
  final Color accent;
  final Color surface;
  final ValueChanged<ExitPromptFeature> onSelected;

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.94);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final features = widget.features;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: _controller,
            itemCount: features.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final feature = features[index];
              final icon = feature.icon;
              final subtitle = feature.subtitle;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x14000000)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          if (icon != null) ...<Widget>[
                            icon,
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  feature.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (subtitle != null)
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF5F6368),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          onPressed: () => widget.onSelected(feature),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.accent,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(feature.actionLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (features.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (var i = 0; i < features.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? widget.accent
                        : widget.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One offer, with Exit under it.
class _OfferSheet extends StatelessWidget {
  const _OfferSheet({
    required this.config,
    required this.style,
    required this.onChoose,
  });

  final ExitPromptConfig config;
  final ExitPromptStyle style;
  final _Choose onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = config.theme;
    final offer = config.offer!;
    final artwork = offer.artwork;
    final message = offer.message;
    final text = theme.offerTextColor;
    final dimmed = config.exitButton == ExitButtonEmphasis.dimmed;
    return Material(
      color: theme.offerBackgroundColor,
      clipBehavior: Clip.antiAlias,
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(theme.cornerRadius)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.close, color: text.withValues(alpha: 0.6)),
                  onPressed: () => onChoose(
                    ExitPromptResult(
                        style: style, action: ExitPromptAction.stay),
                  ),
                ),
              ),
              if (artwork != null)
                SizedBox(height: 180, child: artwork(context)),
              const SizedBox(height: 16),
              Text(
                offer.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: text,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: text.withValues(alpha: 0.7),
                      ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: theme.buttonHeight,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onChoose(
                    ExitPromptResult(
                      style: style,
                      action: ExitPromptAction.offer,
                      targetId: offer.id,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentOf(context, config),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(offer.actionLabel),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => onChoose(
                  ExitPromptResult(style: style, action: ExitPromptAction.exit),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: text.withValues(alpha: dimmed ? 0.35 : 0.85),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(config.labels.exit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
