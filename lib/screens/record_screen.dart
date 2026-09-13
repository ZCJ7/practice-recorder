import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/app_providers.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';

class RecordResult {
  final String filePath;
  final int durationSeconds;

  const RecordResult({
    required this.filePath,
    required this.durationSeconds,
  });
}

class RecordScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const RecordScreen({super.key, required this.sessionId});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _recording = false;
  bool _initializing = true;
  String? _error;
  DateTime? _startedAt;
  Timer? _ticker;
  int _elapsed = 0;

  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _baseZoom = 1;
  late final MediaService _media;

  static const _allOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const _portraitOnly = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  @override
  void initState() {
    super.initState();
    _media = ref.read(mediaServiceProvider);
    SystemChrome.setPreferredOrientations(_allOrientations);
    _media.setKeepScreenOn(true);
    _setup();
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = '未找到可用摄像头';
          _initializing = false;
        });
        return;
      }
      final backIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = backIndex >= 0 ? backIndex : 0;
      await _openCamera(_cameraIndex);
    } catch (e) {
      setState(() {
        _error = '相机初始化失败：$e';
        _initializing = false;
      });
    }
  }

  Future<void> _openCamera(int index) async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final cam = _cameras[index];
    final controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    await controller.unlockCaptureOrientation();

    var minZoom = 1.0;
    var maxZoom = 1.0;
    var zoom = 1.0;
    try {
      minZoom = await controller.getMinZoomLevel();
      maxZoom = await controller.getMaxZoomLevel();
      zoom = minZoom;
      await controller.setZoomLevel(zoom);
    } catch (_) {}

    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameraIndex = index;
      _minZoom = minZoom;
      _maxZoom = maxZoom;
      _zoom = zoom;
      _baseZoom = zoom;
      _initializing = false;
    });
  }

  Future<void> _applyZoom(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = value.clamp(_minZoom, _maxZoom).toDouble();
    try {
      await controller.setZoomLevel(next);
      if (mounted) setState(() => _zoom = next);
    } catch (_) {}
  }

  DeviceOrientation _captureOrientation() {
    final reported = _controller?.value.deviceOrientation;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      if (reported == DeviceOrientation.landscapeLeft ||
          reported == DeviceOrientation.landscapeRight) {
        return reported!;
      }
      return DeviceOrientation.landscapeLeft;
    }
    if (reported == DeviceOrientation.portraitUp ||
        reported == DeviceOrientation.portraitDown) {
      return reported!;
    }
    return DeviceOrientation.portraitUp;
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _recording) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(next);
  }

  Future<void> _toggleRecord() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (_recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final orientation = _captureOrientation();
      await controller.lockCaptureOrientation(orientation);
      await SystemChrome.setPreferredOrientations([orientation]);
      await _media.setKeepScreenOn(true);

      await controller.startVideoRecording();
      _startedAt = DateTime.now();
      _elapsed = 0;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() {
          _elapsed = DateTime.now().difference(_startedAt!).inSeconds;
        });
      });
      setState(() => _recording = true);
    } catch (e) {
      await SystemChrome.setPreferredOrientations(_allOrientations);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法开始录制：$e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_recording) return;
    try {
      final file = await controller.stopVideoRecording();
      _ticker?.cancel();
      final duration = _elapsed;
      setState(() => _recording = false);

      try {
        await controller.unlockCaptureOrientation();
      } catch (_) {}
      await SystemChrome.setPreferredOrientations(_allOrientations);

      final media = ref.read(mediaServiceProvider);
      final videoId = const Uuid().v4();
      final target = await media.buildRecordingPath(widget.sessionId, videoId);
      final saved = await File(file.path).copy(target);
      try {
        await File(file.path).delete();
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop(
        RecordResult(
          filePath: saved.path,
          durationSeconds: duration,
        ),
      );
    } catch (e) {
      await SystemChrome.setPreferredOrientations(_allOrientations);
      if (!mounted) return;
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('停止录制失败：$e')),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(_portraitOnly);
    _media.setKeepScreenOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canZoom = _maxZoom > _minZoom + 0.05;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildPreview()),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: _recording
                    ? null
                    : () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  formatDuration(_elapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            if (canZoom)
              Positioned(
                right: 8,
                top: 72,
                bottom: 140,
                child: Column(
                  children: [
                    Text(
                      '${_zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                          ),
                          child: Slider(
                            min: _minZoom,
                            max: _maxZoom,
                            value: _zoom.clamp(_minZoom, _maxZoom),
                            activeColor: Colors.white,
                            inactiveColor: Colors.white38,
                            onChanged: _applyZoom,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _recording ? null : _flipCamera,
                    iconSize: 32,
                    icon: const Icon(
                      Icons.cameraswitch_rounded,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleRecord,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: AppColors.record,
                          borderRadius: BorderRadius.circular(
                            _recording ? 12 : 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white)),
      );
    }
    if (_initializing || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final controller = _controller!;
    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        onScaleStart: (_) => _baseZoom = _zoom,
        onScaleUpdate: (details) {
          if (_maxZoom <= _minZoom) return;
          _applyZoom(_baseZoom * details.scale);
        },
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}
