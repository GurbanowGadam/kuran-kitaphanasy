import 'package:flutter/material.dart';

/// A horizontal page owns its controller, so discarded pages release resources.
/// Only the small LRU of numeric offsets is retained by the reader.
class ReaderPageScroll extends StatefulWidget {
  const ReaderPageScroll({
    super.key,
    this.generation = 0,
    required this.pageId,
    required this.initialOffset,
    required this.onOffset,
    required this.child,
  });
  final int pageId;
  final int generation;
  final double initialOffset;
  final ValueChanged<double> onOffset;
  final Widget child;
  @override
  State<ReaderPageScroll> createState() => _ReaderPageScrollState();
}

class _ReaderPageScrollState extends State<ReaderPageScroll> {
  late final controller = ScrollController(
    initialScrollOffset: widget.initialOffset,
    keepScrollOffset: false,
  );
  @override
  void initState() {
    super.initState();
    controller.addListener(
      () => widget.onOffset(controller.offset.clamp(0, double.infinity)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          controller.hasClients &&
          controller.offset > controller.position.maxScrollExtent) {
        controller.jumpTo(controller.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ReaderPageScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      // Only mounted pages update. Keep the subtree (and its GlobalKeys) stable;
      // pages built later obtain their cleared offset from the bounded cache.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) {
          controller.jumpTo(
            widget.initialOffset.clamp(
              0.0,
              controller.position.maxScrollExtent,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: Key('page-scroll-${widget.pageId}'),
    controller: controller,
    // Even a short page must compete for vertical intent. Otherwise the parent
    // pager is the only drag recognizer and accepts tiny horizontal jitter.
    // Clamp the empty range rather than stretching/bouncing short surah pages.
    physics: const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    ),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    children: [widget.child],
  );
}
