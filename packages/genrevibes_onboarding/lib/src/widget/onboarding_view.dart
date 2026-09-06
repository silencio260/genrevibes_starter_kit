import 'package:flutter/material.dart';

import '../model/onboarding_page.dart';

/// Paged onboarding presentation.
///
/// Theme-driven and embeddable: it renders no `Scaffold` and no `AppBar`, so a
/// host can place it inside its own route, a sheet, or a dialog. Colors come
/// from the ambient `ThemeData`.
final class OnboardingView extends StatefulWidget {
  /// Creates an onboarding view.
  const OnboardingView({
    required this.pages,
    required this.onCompleted,
    super.key,
    this.onSkipped,
    this.onPageChanged,
    this.nextLabel = 'Next',
    this.skipLabel = 'Skip',
    this.completeLabel = 'Get started',
  });

  /// Pages in display order. Must not be empty.
  final List<OnboardingPage> pages;

  /// Called when the user finishes the final page.
  final VoidCallback onCompleted;

  /// Called when the user skips. Omit to hide the skip control.
  final VoidCallback? onSkipped;

  /// Called whenever the visible page changes.
  final ValueChanged<int>? onPageChanged;

  /// Label advancing to the next page.
  final String nextLabel;

  /// Label for the skip control.
  final String skipLabel;

  /// Label finishing the flow.
  final String completeLabel;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPage => _index == widget.pages.length - 1;

  void _onPageChanged(int index) {
    setState(() => _index = index);
    widget.onPageChanged?.call(index);
  }

  void _advance() {
    if (_isLastPage) {
      widget.onCompleted();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.pages.isNotEmpty, 'Onboarding requires at least one page.');
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: <Widget>[
          if (widget.onSkipped != null)
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onSkipped,
                child: Text(widget.skipLabel),
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: _onPageChanged,
              itemCount: widget.pages.length,
              itemBuilder: (context, index) =>
                  _OnboardingPageView(page: widget.pages[index]),
            ),
          ),
          _PageIndicator(count: widget.pages.length, activeIndex: _index),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _advance,
                child: Text(
                  _isLastPage ? widget.completeLabel : widget.nextLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    ).withTextStyle(theme);
  }
}

extension on Widget {
  Widget withTextStyle(ThemeData theme) => DefaultTextStyle.merge(
        style: TextStyle(color: theme.colorScheme.onSurface),
        child: this,
      );
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artwork = page.artwork;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (page.template == OnboardingTemplate.custom && artwork != null)
            Expanded(child: artwork(context))
          else ...<Widget>[
            if (page.template == OnboardingTemplate.standard && artwork != null)
              Expanded(child: artwork(context)),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              page.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 8,
            width: index == activeIndex ? 24 : 8,
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
