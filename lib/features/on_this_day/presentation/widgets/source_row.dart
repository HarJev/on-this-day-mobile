import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/event_source.dart';

class SourceRow extends StatelessWidget {
  const SourceRow({
    super.key,
    required this.source,
    required this.onTap,
    this.indent = 0,
  });

  final EventSource source;
  final VoidCallback onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final host = source.url.host.replaceFirst(RegExp(r'^www\.'), '');
    return Semantics(
      button: true,
      label: 'Open source: ${source.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.softWarmGray)),
            ),
            padding: EdgeInsets.fromLTRB(indent, 10, 0, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        textAlign: TextAlign.start,
                        style: textTheme.titleSmall,
                      ),
                      if (host.isNotEmpty)
                        Text(
                          host,
                          style: textTheme.bodySmall?.copyWith(height: 1.3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.open_in_new,
                  color: AppColors.archivalCobalt,
                  size: 18,
                  semanticLabel: 'Opens externally',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One quiet "Sources (n)" row that expands the links in place, so sources
/// never compete with the story (DESIGN.md section 16).
class SourcesDisclosure extends StatefulWidget {
  const SourcesDisclosure({
    super.key,
    required this.sources,
    required this.onSourceSelected,
    this.initiallyExpanded = false,
  });

  final List<EventSource> sources;
  final ValueChanged<EventSource> onSourceSelected;
  final bool initiallyExpanded;

  @override
  State<SourcesDisclosure> createState() => _SourcesDisclosureState();
}

class _SourcesDisclosureState extends State<SourcesDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final label = 'Sources (${widget.sources.length})';
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.paleStone),
          bottom: BorderSide(color: AppColors.paleStone),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('sources-disclosure'),
                onTap: () => setState(() => _expanded = !_expanded),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 19,
                        color: AppColors.mutedGray,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.mutedGray,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final source in widget.sources)
                        SourceRow(
                          source: source,
                          indent: 29,
                          onTap: () => widget.onSourceSelected(source),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
