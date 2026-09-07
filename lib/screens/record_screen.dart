import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/app_providers.dart';
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

  @override
  void initState() {
    super.initState();
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
      // Prefer back camera first.
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
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameraIndex = index;
      _initializing = false;
    });
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

      final media = ref.read(mediaServiceProvider);
      final videoId = const Uuid().v4();
      final target =
          await media.buildRecordingPath(widget.sessionId, videoId);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    return Center(child: CameraPreview(_controller!));
  }
}
