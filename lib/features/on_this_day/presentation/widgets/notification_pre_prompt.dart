import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/notifications/notification_prompt_coordinator.dart';

/// A quiet invitation to enable notifications, placed at the end of a loaded
/// Event Detail so it is only reached after reading. Only "Turn on
/// notifications" may lead to the system permission prompt.
class NotificationPrePrompt extends StatefulWidget {
  const NotificationPrePrompt({super.key, required this.coordinator});

  final NotificationPromptCoordinator coordinator;

  static const title = 'Get one moment from history each morning.';
  static const enableLabel = 'Turn on notifications';
  static const declineLabel = 'Not now';

  @override
  State<NotificationPrePrompt> createState() => _NotificationPrePromptState();
}

enum _PromptView { hidden, offered, working, outcome }

class _NotificationPrePromptState extends State<NotificationPrePrompt> {
  _PromptView _view = _PromptView.hidden;
  NotificationPromptOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    final offer = await widget.coordinator.shouldOffer();
    if (mounted && offer) {
      setState(() => _view = _PromptView.offered);
    }
  }

  Future<void> _enable() async {
    setState(() => _view = _PromptView.working);
    final outcome = await widget.coordinator.enable();
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _view = _PromptView.outcome;
    });
  }

  Future<void> _decline() async {
    setState(() => _view = _PromptView.hidden);
    await widget.coordinator.decline();
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_view) {
      _PromptView.hidden => const SizedBox.shrink(),
      _PromptView.offered || _PromptView.working => _Invitation(
        busy: _view == _PromptView.working,
        onEnable: _enable,
        onDecline: _decline,
      ),
      _PromptView.outcome => _OutcomeMessage(outcome: _outcome!),
    };
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation({
    required this.busy,
    required this.onEnable,
    required this.onDecline,
  });

  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _PromptFrame(
      key: const Key('notification-pre-prompt'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.notifications_none,
            color: AppColors.archivalCobalt,
            size: 22,
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              NotificationPrePrompt.title,
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.deepInk,
                fontFamily: 'Georgia',
                fontFamilyFallback: const ['Times New Roman', 'serif'],
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A short note about the day’s featured event. You can change '
            'this anytime in your device Settings.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedGray,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : onEnable,
            child: const Text(NotificationPrePrompt.enableLabel),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: busy ? null : onDecline,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text(NotificationPrePrompt.declineLabel),
          ),
        ],
      ),
    );
  }
}

class _OutcomeMessage extends StatelessWidget {
  const _OutcomeMessage({required this.outcome});

  final NotificationPromptOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (outcome) {
      NotificationPromptOutcome.enabled => (
        Icons.notifications_active_outlined,
        'Notifications are on.',
      ),
      NotificationPromptOutcome.blocked => (
        Icons.notifications_off_outlined,
        'Notifications are off for On This Day. You can turn them on '
            'anytime in your device Settings.',
      ),
      NotificationPromptOutcome.undecided => (
        Icons.notifications_none,
        'Notifications weren’t turned on. You can turn them on anytime in '
            'your device Settings.',
      ),
      NotificationPromptOutcome.failed => (
        Icons.notifications_none,
        'Notifications couldn’t be turned on right now. Please try again '
            'later.',
      ),
    };
    return _PromptFrame(
      key: const Key('notification-pre-prompt-outcome'),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.archivalCobalt, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepInk,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptFrame extends StatelessWidget {
  const _PromptFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.softIvory,
          border: Border(
            top: BorderSide(color: AppColors.mutedCopper),
            left: BorderSide(color: AppColors.paleStone),
            right: BorderSide(color: AppColors.paleStone),
            bottom: BorderSide(color: AppColors.paleStone),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: child,
      ),
    );
  }
}
