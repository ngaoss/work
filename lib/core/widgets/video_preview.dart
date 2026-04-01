import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatefulWidget {
  final File? file;
  final String? videoUrl;
  final bool autoPlay;
  final bool loop;
  final bool mute;
  final Map<String, String>? httpHeaders;

  const VideoPreview({
    super.key,
    this.file,
    this.videoUrl,
    this.autoPlay = true,
    this.loop = true,
    this.mute = true,
    this.httpHeaders,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.file?.path != widget.file?.path ||
        oldWidget.httpHeaders != widget.httpHeaders) {
      _controller.pause();
      _controller.dispose();
      _initController();
    } else {
      if (oldWidget.autoPlay != widget.autoPlay) {
        if (widget.autoPlay) {
          _controller.play();
        } else {
          _controller.pause();
        }
      }
      if (oldWidget.mute != widget.mute) {
        _controller.setVolume(widget.mute ? 0.0 : 1.0);
      }
    }
  }

  void _initController() {
    if (widget.videoUrl != null) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl!),
        httpHeaders:
            (widget.httpHeaders != null && widget.httpHeaders!.isNotEmpty)
            ? widget.httpHeaders!
            : const {},
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else if (widget.file != null) {
      _controller = VideoPlayerController.file(
        widget.file!,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } else {
      throw ArgumentError("Either file or videoUrl must be provided");
    }

    try {
      _controller
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {});
              if (widget.autoPlay) {
                _controller.play().catchError(
                  (e) => debugPrint('VideoPreview: error playing: $e'),
                );
              }
              _controller.setLooping(widget.loop);
              _controller.setVolume(widget.mute ? 0.0 : 1.0);
            }
          })
          .catchError((e) {
            debugPrint('VideoPreview: error initializing: $e');
            if (mounted) setState(() {});
          });
    } catch (e) {
      debugPrint('VideoPreview: catch error during init start: $e');
    }
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container(
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
