import 'package:flutter/material.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/quiz_source.dart';

class QuizSourceRow extends StatefulWidget {
  const QuizSourceRow({
    super.key,
    required this.source,
    required this.launcher,
  });
  final QuizSource source;
  final SourceLauncher launcher;
  @override
  State<QuizSourceRow> createState() => _QuizSourceRowState();
}

class _QuizSourceRowState extends State<QuizSourceRow> {
  bool busy = false, failed = false;
  Future<void> open() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    var success = false;
    try {
      success = await widget.launcher.open(widget.source.url);
    } catch (_) {
      /* Safe inline failure below. */
    }
    if (mounted) {
      setState(() {
        busy = false;
        failed = !success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final host = widget.source.url.host.replaceFirst(RegExp(r'^www\.'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: !busy,
          label: 'Open source: ${widget.source.displayName}',
          excludeSemantics: true,
          child: InkWell(
            onTap: busy ? null : open,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.softWarmGray),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.source.displayName,
                          style: textTheme.titleSmall,
                        ),
                        if (host.isNotEmpty)
                          Text(host, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppColors.archivalCobalt,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Could not open source. Tap the source to retry.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.copperDark),
            ),
          ),
      ],
    );
  }
}
