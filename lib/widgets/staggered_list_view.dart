import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A list view that animates its children with staggered delays
/// Each item fades and slides in with a configurable delay interval
class StaggeredListView extends StatelessWidget {
  const StaggeredListView({
    super.key,
    this.children,
    this.itemCount,
    this.itemBuilder,
    this.delay = const Duration(milliseconds: 50),
    this.fadeDuration = const Duration(milliseconds: 300),
    this.slideOffset = const Offset(0, 0.3),
    this.fadeCurve = Curves.easeOut,
    this.slideCurve = Curves.easeOutCubic,
    this.physics,
    this.padding,
    this.shrinkWrap = false,
  }) : assert(
          (children != null && itemCount == null && itemBuilder == null) ||
          (children == null && itemCount != null && itemBuilder != null),
          'Either provide children OR both itemCount and itemBuilder'
        );

  /// The children to display in the list (for small lists)
  final List<Widget>? children;

  /// Number of items for builder pattern (for large lists)
  final int? itemCount;

  /// Builder function for large lists
  final Widget Function(BuildContext, int)? itemBuilder;

  /// Delay between each item's animation start
  final Duration delay;

  /// Duration of the fade animation
  final Duration fadeDuration;

  /// Offset for the slide animation (relative to item position)
  final Offset slideOffset;

  /// Curve for the fade animation
  final Curve fadeCurve;

  /// Curve for the slide animation
  final Curve slideCurve;

  /// Scroll physics for the list
  final ScrollPhysics? physics;

  /// Padding around the list
  final EdgeInsetsGeometry? padding;

  /// Whether the list should shrink-wrap its contents
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    // Handle small lists with children directly
    if (children != null) {
      return ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
        padding: padding,
        itemCount: children!.length,
        itemBuilder: (context, index) {
          final itemDelay = delay * index;

          return Animate(
            delay: itemDelay,
            child: children![index],
          )
              .fade(
                duration: fadeDuration,
                curve: fadeCurve,
              )
              .slide(
                begin: slideOffset,
                end: Offset.zero,
                duration: fadeDuration,
                curve: slideCurve,
              );
        },
      );
    }

    // Handle large lists with builder pattern
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final itemDelay = delay * index;

        return Animate(
          delay: itemDelay,
          child: itemBuilder!(context, index),
        )
            .fade(
              duration: fadeDuration,
              curve: fadeCurve,
            )
            .slide(
              begin: slideOffset,
              end: Offset.zero,
              duration: fadeDuration,
              curve: slideCurve,
            );
      },
    );
  }
}
