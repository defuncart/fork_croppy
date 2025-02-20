// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:croppy/src/src.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CroppableImageWidget extends RenderObjectWidget
    with SlottedMultiChildRenderObjectWidgetMixin<EditableImageSlot> {
  const CroppableImageWidget({
    super.key,
    required this.controller,
    required this.image,
    required this.cropHandles,
    this.overlayOpacity = 1.0,
    this.gesturePadding = 0.0,
  });

  final Widget image;
  final Widget cropHandles;
  final CroppableImageController controller;
  final double gesturePadding;
  final double overlayOpacity;

  @override
  CroppableImageRenderObject createRenderObject(BuildContext context) {
    final staticCropRect = (controller is ResizeStaticLayoutMixin)
        ? (controller as ResizeStaticLayoutMixin).staticCropRect
        : null;

    return CroppableImageRenderObject(
      controller.data,
      controller.viewportScale,
      gesturePadding,
      overlayOpacity,
      staticCropRect,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    CroppableImageRenderObject renderObject,
  ) {
    renderObject.imageData = controller.data;
    renderObject.viewportScale = controller.viewportScale;
    renderObject.gesturePadding = gesturePadding;
    renderObject.overlayOpacity = overlayOpacity;
    renderObject.staticCropRect = (controller is ResizeStaticLayoutMixin)
        ? (controller as ResizeStaticLayoutMixin).staticCropRect
        : null;
  }

  @override
  Widget? childForSlot(slot) {
    switch (slot) {
      case EditableImageSlot.image:
        return image;
      case EditableImageSlot.handles:
        return cropHandles;
    }
  }

  @override
  Iterable<EditableImageSlot> get slots => EditableImageSlot.values;
}

enum EditableImageSlot {
  image,
  handles,
}

class CroppableImageRenderObject extends RenderBox
    with SlottedContainerRenderObjectMixin<EditableImageSlot> {
  CroppableImageRenderObject(
    CroppableImageData imageData,
    double viewportScale,
    double gestureSafeArea,
    double overlaysOpacity, [
    Rect? staticCropRect,
  ])  : _imageData = imageData,
        _viewportScale = viewportScale,
        _gesturePadding = gestureSafeArea,
        _staticCropRect = staticCropRect,
        _overlayOpacity = overlaysOpacity;

  CroppableImageData _imageData;
  CroppableImageData get imageData => _imageData;
  set imageData(CroppableImageData value) {
    if (_imageData == value) return;
    _imageData = value;
    markNeedsLayout();
  }

  double _viewportScale;
  double get viewportScale => _viewportScale;
  set viewportScale(double value) {
    if (_viewportScale == value) return;
    _viewportScale = value;
    markNeedsLayout();
  }

  double _gesturePadding;
  double get gesturePadding => _gesturePadding;
  set gesturePadding(double value) {
    if (_gesturePadding == value) return;
    _gesturePadding = value;
    markNeedsLayout();
  }

  Rect? _staticCropRect;
  Rect? get staticCropRect => _staticCropRect;
  set staticCropRect(Rect? value) {
    if (value == _staticCropRect) return;
    _staticCropRect = value;
    markNeedsLayout();
  }

  double _overlayOpacity;
  double get overlayOpacity => _overlayOpacity;
  set overlayOpacity(double value) {
    if (value == _overlayOpacity) return;
    _overlayOpacity = value;
    markNeedsPaint();
  }

  int get _overlayAlpha => (overlayOpacity * 255).round();

  RenderBox? get image => childForSlot(EditableImageSlot.image);
  RenderBox? get handles => childForSlot(EditableImageSlot.handles);

  @override
  void performLayout() {
    var scaledSize = Size(
      imageData.cropRect.width,
      imageData.cropRect.height,
    );

    var layoutSize = staticCropRect?.size ?? scaledSize;

    scaledSize *= viewportScale;
    layoutSize *= viewportScale;

    scaledSize =
        constraints.constrainSizeAndAttemptToPreserveAspectRatio(scaledSize);

    layoutSize =
        constraints.constrainSizeAndAttemptToPreserveAspectRatio(layoutSize);

    image!.layout(
      BoxConstraints.tight(imageData.imageSize),
      parentUsesSize: false,
    );

    final padding = Offset(gesturePadding * 2, gesturePadding * 2);
    final sizeWithPadding = scaledSize + padding;
    final layoutSizeWithPadding = layoutSize + padding;

    handles!.layout(
      BoxConstraints.tight(sizeWithPadding),
      parentUsesSize: false,
    );

    size = layoutSizeWithPadding;
  }

  final _backgroundOpacityLayer = LayerHandle<OpacityLayer>();
  final _backgroundTransformLayer = LayerHandle<TransformLayer>();
  void paintBackgroundImage(
    PaintingContext context,
    Offset offset,
    Matrix4 transform,
  ) {
    // Not working with Impeller :(
    // TODO(kekland): find a way to make it work
    // _imageFilterLayer.layer = ImageFilterLayer(
    //   imageFilter: null,
    //   offset: offset,
    // );

    // _imageFilterLayer.layer!.imageFilter = ImageFilter.compose(
    //   outer: ImageFilter.matrix(
    //     transform.storage,
    //   ),
    //   inner: ImageFilter.blur(
    //     sigmaX: 8.0,
    //     sigmaY: 8.0,
    //     tileMode: TileMode.decal,
    //   ),
    // );

    // context.pushLayer(
    //   _imageFilterLayer.layer!,
    //   (context, offset) {
    //     context.paintChild(image!, offset);
    //   },
    //   Offset.zero,
    // );

    _backgroundOpacityLayer.layer = context.pushOpacity(
      offset,
      _overlayAlpha,
      (context, offset) {
        _backgroundTransformLayer.layer = context.pushTransform(
          false,
          offset,
          transform,
          (context, offset) {
            context.paintChild(image!, offset);
          },
          oldLayer: _backgroundTransformLayer.layer,
        );
      },
      oldLayer: _backgroundOpacityLayer.layer,
    );
  }

  void paintBackgroundImageForeground(PaintingContext context, Path path) {
    if (_overlayOpacity == 0.0) return;

    context.canvas.drawPath(
      path,
      Paint()..color = Colors.black.withOpacity(0.9),
    );
  }

  final _transformLayer = LayerHandle<TransformLayer>();
  final _clipRectLayer = LayerHandle<ClipRectLayer>();
  void paintCroppedImage(
    PaintingContext context,
    Offset offset,
    Rect clipRect,
    Matrix4 transform,
  ) {
    if (_overlayOpacity == 0.0) return;

    _clipRectLayer.layer = context.pushClipRect(
      false,
      offset,
      clipRect,
      (context, offset) {
        _transformLayer.layer = context.pushTransform(
          false,
          offset,
          transform,
          (context, offset) {
            context.paintChild(image!, offset);
          },
          oldLayer: _transformLayer.layer,
        );
      },
      clipBehavior: Clip.antiAlias,
      oldLayer: _clipRectLayer.layer,
    );
  }

  final _handlesOpacityLayer = LayerHandle<OpacityLayer>();
  void paintHandles(PaintingContext context, Offset offset) {
    _handlesOpacityLayer.layer = context.pushOpacity(
      offset,
      _overlayAlpha,
      (context, offset) {
        context.paintChild(handles!, offset);
      },
      oldLayer: _handlesOpacityLayer.layer,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (image == null || handles == null) return;

    var additionalOffset = Offset.zero;

    if (staticCropRect != null) {
      additionalOffset = (imageData.cropRect.topLeft - staticCropRect!.topLeft);
      additionalOffset *= viewportScale;
    }

    final _offset = offset + Offset(gesturePadding, gesturePadding);
    final _layoutCropRect = staticCropRect ?? imageData.cropRect;

    final scaleTransform = Matrix4.identity()..scale(viewportScale);
    final translationTransform = Matrix4.identity()
      ..translate(-_layoutCropRect.left, -_layoutCropRect.top);

    final Matrix4 matrix =
        scaleTransform * translationTransform * imageData.totalImageTransform;

    var backgroundImageQuad = Quad2.fromSize(imageData.imageSize);
    backgroundImageQuad = backgroundImageQuad.transform(
      Matrix4.copy(matrix)..leftTranslate(_offset.dx, _offset.dy),
    );

    final backgroundImagePath = backgroundImageQuad.path;

    paintBackgroundImage(context, _offset, matrix);
    paintBackgroundImageForeground(context, backgroundImagePath);

    paintCroppedImage(
      context,
      _offset,
      additionalOffset & (imageData.cropRect.size * viewportScale),
      matrix,
    );

    paintHandles(context, offset + additionalOffset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return handles!.hitTest(
      result,
      position: position,
    );
  }
}
