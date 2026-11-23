import 'package:flutter/widgets.dart';

/// Fits the complete video and its annotations in one centered coordinate space.
class ReviewVideoViewport extends StatelessWidget {
  const ReviewVideoViewport({
    super.key,
    required this.frameSize,
    required this.child,
  });

  final Size frameSize;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final aspect = frameSize.width > 0 && frameSize.height > 0
          ? frameSize.width / frameSize.height
          : 16 / 9;
      var width = constraints.maxWidth;
      var height = width / aspect;
      if (height > constraints.maxHeight) {
        height = constraints.maxHeight;
        width = height * aspect;
      }
      return Center(
        child: SizedBox(width: width, height: height, child: child),
      );
    },
  );
}
