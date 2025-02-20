import 'dart:typed_data';

import 'package:croppy/src/src.dart';
import 'package:flutter/widgets.dart';

typedef CroppableImagePostProcessFn = Future<CropImageResult> Function(
  CropImageResult result,
);

/// A base class for controllers that can be used with this package.
abstract class BaseCroppableImageController extends ChangeNotifier {
  BaseCroppableImageController({
    required this.imageProvider,
    required CroppableImageData data,
    this.postProcessFn,
  }) : data = data.copyWith();

  /// The image provider that represents the image to be cropped.
  final ImageProvider imageProvider;

  /// A function that is called in [crop] as a post-processing function. Use it
  /// to, for example, compress the image, or update the state in the preview
  /// page.
  final CroppableImagePostProcessFn? postProcessFn;

  /// The current crop data.
  CroppableImageData data;

  /// The scale of the viewport.
  double get viewportScale;

  /// The state at the start of a transformation.
  CroppableImageData? transformationInitialData;

  Size? _viewportSize;

  /// Size of the available viewport.
  Size? get viewportSize => _viewportSize;

  /// Sets the size of the available viewport.
  @mustCallSuper
  set viewportSize(Size? size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
  }

  /// Called when a transformation starts.
  @mustCallSuper
  void onTransformationStart() {
    transformationInitialData = data.copyWith();
    notifyListeners();
  }

  /// Called when a transformation ends.
  @mustCallSuper
  void onTransformationEnd() {
    transformationInitialData = null;
    data = data.copyWith(
      imageTransform: data.currentImageTransform * data.imageTransform,
      currentImageTransform: Matrix4.identity(),
    );

    notifyListeners();
  }

  /// Called when a base transformation is applied. Implementers can override
  /// this to update the [data] and notify listeners.
  void onBaseTransformation(CroppableImageData newData) {
    data = newData;
    notifyListeners();
  }

  /// Normalizes the crop rect to fit inside the transformed image quad.
  void normalize() {
    final normalizedAabb = FitAabbInQuadSolver.solve(
      data.cropAabb,
      data.transformedImageQuad,
    );

    data = data.copyWith(cropRect: normalizedAabb.rect);
  }

  /// Returns the transformation matrix that is needed to transform the crop
  /// rect from the current base transformations to the new base
  /// transformations.
  Matrix4 getMatrixForBaseTransformations(
    BaseTransformations newBaseTransformations,
  ) {
    final oldTransform = data.translatedBaseTransformations;
    final newTransform = data.translateTransformation(
      newBaseTransformations.matrix,
    );

    return newTransform * Matrix4.inverted(oldTransform);
  }

  /// Whether the controller can be reset to its initial state, i.e. whether
  /// the image has been transformed.
  bool get canReset =>
      data != CroppableImageData.initial(imageSize: data.imageSize);

  /// Resets the controller to its initial state.
  void reset() {
    data = CroppableImageData.initial(imageSize: data.imageSize);
    notifyListeners();
  }

  /// Crops the image and returns the cropped image as a [Uint8List].
  @mustCallSuper
  Future<CropImageResult> crop() async {
    final image = await obtainImage(imageProvider);
    final result = await cropImageBilinear(image, data);

    if (postProcessFn != null) {
      return postProcessFn!(result);
    } else {
      return result;
    }
  }
}

/// An abstract controller for images that can be cropped, that provides the
/// different transformations (pan and scale, resize, rotate, etc).
abstract class CroppableImageController extends BaseCroppableImageController
    with
        PanAndScaleTransformation,
        ResizeTransformation,
        StraightenTransformation,
        RotateTransformation,
        MirrorTransformation {
  CroppableImageController({
    required super.imageProvider,
    required super.data,
    super.postProcessFn,
  });
}
