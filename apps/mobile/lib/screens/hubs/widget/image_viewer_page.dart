import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';

/// Full-screen image viewer with Hero animation, pinch-to-zoom,
/// double-tap zoom, pan, and swipe-down-to-dismiss.
class ImageViewerPage extends StatefulWidget {
  final String? imagePath;
  final String? imageUrl;
  final String heroTag;
  final String? caption;

  const ImageViewerPage({
    super.key,
    this.imagePath,
    this.imageUrl,
    required this.heroTag,
    this.caption,
  }) : assert(imagePath != null || imageUrl != null);

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with TickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _zoomAnimController;
  late final AnimationController _snapBackController;

  Animation<Matrix4>? _zoomAnimation;
  Animation<double>? _snapBackAnimation;

  bool _isZoomed = false;

  // ─── Overlay (app bar) visibility ───
  Timer? _singleTapTimer;

  // ─── Pointer tracking ───
  int _pointerCount = 0;
  Offset _pointerDownPos = Offset.zero;
  bool _pointerMoved = false;

  // ─── Double-tap detection ───
  DateTime? _prevTapTime;
  Offset? _prevTapGlobalPos;

  // ─── Swipe-to-dismiss ───
  bool _dismissActive = false;
  double _dismissDy = 0;
  double _bgOpacity = 1.0;
  Offset _dismissAnchor = Offset.zero;

  // ─── Lifecycle ───

  @override
  void initState() {
    super.initState();

    _zoomAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformController.value = _zoomAnimation!.value;
          }
        });

    _snapBackController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          if (_snapBackAnimation != null) {
            setState(() {
              _dismissDy = _snapBackAnimation!.value;
              _bgOpacity = (1.0 - (_dismissDy.abs() / 300)).clamp(0.3, 1.0);
            });
          }
        });

    _transformController.addListener(_onZoomChanged);
  }

  void _onZoomChanged() {
    final zoomed = _transformController.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _transformController.removeListener(_onZoomChanged);
    _zoomAnimController.dispose();
    _snapBackController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // ─── Image Saving ───
  
  bool _isSaving = false;

  Future<void> _saveImage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      Uint8List? imageBytes;
      if (widget.imageUrl != null) {
        final response = await http.get(Uri.parse(widget.imageUrl!));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      } else if (widget.imagePath != null) {
        final file = File(widget.imagePath!);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      }

      if (imageBytes != null) {
        final result = await ImageGallerySaver.saveImage(
          imageBytes,
          quality: 100,
          name: "campuz_${DateTime.now().millisecondsSinceEpoch}",
        );
        if (!mounted) return;
        if (result != null && result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved to gallery')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save image')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred while saving')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Raw pointer handlers (bypass gesture arena) ───

  void _onPointerDown(PointerDownEvent e) {
    _pointerCount++;
    _pointerDownPos = e.position;
    _pointerMoved = false;

    if (_snapBackController.isAnimating) {
      _snapBackController.stop();
      setState(() {
        _dismissDy = 0;
        _bgOpacity = 1.0;
      });
    }

    if (_pointerCount == 1 && !_isZoomed) {
      _dismissAnchor = e.position;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if ((e.position - _pointerDownPos).distance > 18) _pointerMoved = true;

    // Swipe-to-dismiss (single finger, not zoomed)
    if (_pointerCount == 1 && !_isZoomed) {
      final dy = e.position.dy - _dismissAnchor.dy;
      final dx = e.position.dx - _dismissAnchor.dx;

      if (!_dismissActive && dy.abs() > 20 && dy.abs() > dx.abs() * 1.3) {
        _dismissActive = true;
        _dismissAnchor = e.position;
      }

      if (_dismissActive) {
        setState(() {
          _dismissDy = e.position.dy - _dismissAnchor.dy;
          _bgOpacity = (1.0 - (_dismissDy.abs() / 300)).clamp(0.3, 1.0);
        });
      }
    }

    // Cancel dismiss when a second finger arrives
    if (_pointerCount > 1 && _dismissActive) _resetDismiss();
  }

  void _onPointerUp(PointerUpEvent e) {
    _pointerCount = (_pointerCount - 1).clamp(0, 99);

    // Resolve swipe-to-dismiss
    if (_dismissActive && _pointerCount == 0) {
      if (_dismissDy.abs() > 100) {
        Navigator.of(context).pop();
      } else {
        _animateSnapBack();
      }
      _dismissActive = false;
      return;
    }

    // Double-tap detection (clean taps only)
    if (!_pointerMoved && _pointerCount == 0) {
      final now = DateTime.now();
      if (_prevTapTime != null &&
          now.difference(_prevTapTime!).inMilliseconds < 300 &&
          _prevTapGlobalPos != null &&
          (e.position - _prevTapGlobalPos!).distance < 44) {
        _doDoubleTapZoom(e.localPosition);
        _prevTapTime = null;
        _prevTapGlobalPos = null;
      } else {
        _prevTapTime = now;
        _prevTapGlobalPos = e.position;
      }
    } else {
      _prevTapTime = null;
      _prevTapGlobalPos = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointerCount = (_pointerCount - 1).clamp(0, 99);
    _resetDismiss();
  }

  // ─── Dismiss helpers ───

  void _resetDismiss() {
    _dismissActive = false;
    if (_dismissDy != 0) _animateSnapBack();
  }

  void _animateSnapBack() {
    _snapBackAnimation = Tween<double>(begin: _dismissDy, end: 0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOut),
    );
    _snapBackController.forward(from: 0);
  }

  // ─── Double-tap zoom ───

  void _doDoubleTapZoom(Offset local) {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final Matrix4 end;

    if (scale > 1.1) {
      end = Matrix4.identity();
    } else {
      const z = 2.5;
      end = Matrix4.identity()
        ..translateByDouble(-local.dx * (z - 1), -local.dy * (z - 1), 0, 1)
        ..scaleByDouble(z, z, z, 1);
    }

    _zoomAnimation = Matrix4Tween(begin: _transformController.value, end: end)
        .animate(
          CurvedAnimation(
            parent: _zoomAnimController,
            curve: Curves.easeOutCubic,
          ),
        );
    _zoomAnimController.forward(from: 0);
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Container(
          color: Colors.black.withValues(alpha: _bgOpacity),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Zoomable / pannable image
              Center(
                child: Transform.translate(
                  offset: Offset(0, _dismissDy),
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    panEnabled: _isZoomed,
                    scaleEnabled: true,
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Hero(
                      tag: widget.heroTag,
                      child: widget.imageUrl != null
                          ? Image.network(
                              widget.imageUrl!,
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              File(widget.imagePath!),
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Material(
                          color: Colors.black26,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Material(
                          color: Colors.black26,
                          shape: const CircleBorder(),
                          child: _isSaving 
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: _saveImage,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Caption overlay
              if (widget.caption != null && widget.caption!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 24,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: Text(
                        widget.caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
