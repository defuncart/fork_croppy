import 'dart:math';

import 'package:croppy/src/src.dart';

/// Provides methods for rotating the image.
mixin RotateTransformation on BaseCroppableImageController {
  /// Rotates the image counter-clockwise by 90 degrees.
  void onRotateCCW() {
    final newBaseTransformations = data.baseTransformations.copyWith(
      rotationZ: data.baseTransformations.rotationZ - pi / 2,
    );

    final transformation = getMatrixForBaseTransformations(
      newBaseTransformations,
    );

    final cropRect = data.cropRect.transform(transformation);

    onBaseTransformation(data.copyWith(
      cropRect: cropRect,
      baseTransformations: newBaseTransformations,
    ));
  }
}
