import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Même rouge sur toute la série, sans modifier les silhouettes ni leur alpha.
/// Le programme est partagé ; chaque image possède son propre sampler.
class MuscleIllustration extends StatefulWidget {
  const MuscleIllustration({
    required this.image,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    this.placeholder = const SizedBox.shrink(),
    super.key,
  });

  static const shaderAsset = 'shaders/muscle_red.frag';
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset(shaderAsset);

  final ImageProvider<Object> image;
  final BoxFit fit;
  final String? semanticLabel;
  final Widget placeholder;

  @override
  State<MuscleIllustration> createState() => _MuscleIllustrationState();
}

class _MuscleIllustrationState extends State<MuscleIllustration> {
  ImageStream? _stream;
  ImageInfo? _image;
  ui.FragmentShader? _shader;
  bool _shaderFailed = false;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    onError: _onImageError,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    try {
      final program = await MuscleIllustration._program;
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } on Object {
      // Un moteur sans shader conserve le détourage, jamais un fond opaque.
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(MuscleIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _resolveImage();
  }

  void _resolveImage() {
    final next = widget.image.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _image?.dispose();
    _image = null;
    _stream = next;
    next.addListener(_listener);
  }

  void _onImage(ImageInfo image, bool synchronousCall) {
    final previous = _image;
    setState(() => _image = image);
    previous?.dispose();
  }

  void _onImageError(Object error, StackTrace? stackTrace) {
    final previous = _image;
    setState(() => _image = null);
    previous?.dispose();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _shader?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _image;
    final shader = _shader;
    if (info == null || (shader == null && !_shaderFailed)) {
      return widget.placeholder;
    }

    final Widget illustration;
    if (shader == null) {
      illustration = RawImage(
        image: info.image,
        scale: info.scale,
        fit: widget.fit,
      );
    } else {
      illustration = FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: info.image.width / info.scale,
          height: info.image.height / info.scale,
          child: CustomPaint(
            painter: MuscleIllustrationPainter(info.image, shader),
          ),
        ),
      );
    }

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: illustration,
    );
  }
}

/// Rendu partagé avec les tests de pixels : aucun fond n'est peint.
class MuscleIllustrationPainter extends CustomPainter {
  const MuscleIllustrationPainter(this.image, this.shader);

  final ui.Image image;
  final ui.FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(MuscleIllustrationPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.shader != shader;
}
