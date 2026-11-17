import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Keeps nested vertical scrolling and verse actions in the gesture arena while
/// a horizontal page is settling. PageController's native position, snapping,
/// velocity estimation, RTL mapping and restoration remain unchanged.
class ReaderPageController extends PageController {
  ReaderPageController({
    super.initialPage,
    super.keepPage,
    super.viewportFraction,
    super.onAttach,
    super.onDetach,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => super.createScrollPosition(
    physics,
    // Physics/theme changes recreate the position for the same Scrollable.
    // ScrollPosition.absorb requires context identity, not just an equivalent
    // delegate; retain the existing proxy along with native page state.
    oldPosition?.context ?? _NestedReaderScrollContext(context),
    oldPosition,
  );
}

/// Default Scrollable hides its children from hit testing during a ballistic
/// activity. The next pointer then sees only the horizontal recognizer, which
/// wins without competing against the vertical list (even for vertical intent).
/// Forward every context operation except that suppression. No pan recognizer,
/// extra slop, timer, or private Flutter PagePosition implementation is needed.
class _NestedReaderScrollContext implements ScrollContext {
  _NestedReaderScrollContext(this.delegate);
  final ScrollContext delegate;

  @override
  BuildContext? get notificationContext => delegate.notificationContext;
  @override
  BuildContext get storageContext => delegate.storageContext;
  @override
  TickerProvider get vsync => delegate.vsync;
  @override
  AxisDirection get axisDirection => delegate.axisDirection;
  @override
  double get devicePixelRatio => delegate.devicePixelRatio;
  @override
  void setIgnorePointer(bool value) => delegate.setIgnorePointer(false);
  @override
  void setCanDrag(bool value) => delegate.setCanDrag(value);
  @override
  void setSemanticsActions(Set<SemanticsAction> actions) =>
      delegate.setSemanticsActions(actions);
  @override
  void saveOffset(double offset) => delegate.saveOffset(offset);
}
