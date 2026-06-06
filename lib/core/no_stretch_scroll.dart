import 'package:flutter/material.dart';

/// App-wide scroll behaviour that removes the Material "stretch" overscroll
/// effect (which warps the whole page when you fling past the edge) and uses
/// clamping physics instead. Applied via MaterialApp.scrollBehavior.
class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child; // no glow, no stretch

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
