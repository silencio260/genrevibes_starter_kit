import 'dart:async';
import 'package:flutter/material.dart';

/// A labeled, local preview of Android's folder confirmation steps.
/// No overlay or interaction with the system permission dialog is required.
class FolderAccessPreview extends StatefulWidget {
  const FolderAccessPreview({
    super.key,
    this.folderName = '.Statuses',
    this.caption = 'Preview · Android may look different on your phone',
    this.useFolderLabel = 'Use this folder',
    this.allowLabel = 'Allow',
  });
  final String folderName;
  final String caption;
  final String useFolderLabel;
  final String allowLabel;

  @override
  State<FolderAccessPreview> createState() => _FolderAccessPreviewState();
}

class _FolderAccessPreviewState extends State<FolderAccessPreview> {
  Timer? _timer;
  int _step = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!MediaQuery.of(context).disableAnimations && TickerMode.of(context)) {
      _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) setState(() => _step = 1 - _step);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label:
          'In the Android picker, choose the folder, tap ${widget.useFolderLabel}, then ${widget.allowLabel}.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.caption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 18),
            Icon(Icons.folder_outlined, size: 42, color: color),
            const SizedBox(height: 6),
            Text(widget.folderName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 18),
            for (var i = 0; i < 2; i++) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _step == i ? color : Colors.transparent,
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                    '${i + 1}. ${i == 0 ? widget.useFolderLabel : widget.allowLabel}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _step == i
                            ? Theme.of(context).colorScheme.onPrimary
                            : color,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
