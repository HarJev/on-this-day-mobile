import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';

/// Serif section title with the short copper bar used on Today.
class TodaySectionHeader extends StatelessWidget {
  const TodaySectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(text, style: AppText.sectionHeader),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 32,
            height: 2,
            child: ColoredBox(color: AppColors.mutedCopper),
          ),
        ],
      ),
    );
  }
}

/// A calm ivory card for unavailable or failed content, with one action.
class TodayMessageCard extends StatelessWidget {
  const TodayMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onActionPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = secondaryLabel;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.softIvory,
            border: Border.all(color: AppColors.paleStone),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.copperTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.copperDark, size: 22),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(title, style: textTheme.headlineSmall),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedGray,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onActionPressed,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onSecondaryPressed,
                    child: Text(secondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton blocks that mirror the loaded layout; static under reduced motion.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.6).animate(_controller),
          child: widget.child,
        ),
      ),
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.softWarmGray,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    if (width == null) return block;
    return Align(alignment: Alignment.centerLeft, widthFactor: 1, child: block);
  }
}

class TodayLoadingSkeleton extends StatelessWidget {
  const TodayLoadingSkeleton({super.key});

  static const semanticsLabel = "Loading today's history";

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: semanticsLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const SkeletonBlock(width: 64, height: 12),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.softIvory,
              border: Border.all(color: AppColors.paleStone),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(height: 170),
                  SizedBox(height: 18),
                  SkeletonBlock(width: 96, height: 36),
                  SizedBox(height: 14),
                  SkeletonBlock(height: 1),
                  SizedBox(height: 14),
                  SkeletonBlock(height: 24),
                  SizedBox(height: 8),
                  SkeletonBlock(width: 200, height: 24),
                  SizedBox(height: 14),
                  SkeletonBlock(height: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const SkeletonBlock(width: 160, height: 22),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: 22),
            const Row(
              children: [
                SkeletonBlock(width: 44, height: 16),
                SizedBox(width: 20),
                Expanded(child: SkeletonBlock(height: 16)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
