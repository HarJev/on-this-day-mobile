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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton(
        onPressed: busy ? null : open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(widget.source.displayName)),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new,
                size: 20,
                color: AppColors.archivalCobalt,
              ),
            ],
          ),
        ),
      ),
      if (failed) const Text('Could not open source. Tap the source to retry.'),
    ],
  );
}
