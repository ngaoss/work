import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullScreenMediaViewer extends StatefulWidget {
  final String? mediaPath;
  final String? mediaUrl;

  const FullScreenMediaViewer({super.key, this.mediaPath, this.mediaUrl});

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    final path = widget.mediaPath ?? widget.mediaUrl;
    if (path != null &&
        (path.toLowerCase().endsWith('.mp4') ||
            path.toLowerCase().endsWith('.mov'))) {
      _isVideo = true;
      if (widget.mediaPath != null) {
        _controller = VideoPlayerController.file(File(widget.mediaPath!));
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.mediaUrl!),
        );
      }

      _controller!.initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller!.play();
        _controller!.setLooping(true);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(child: _isVideo ? _buildVideoPlayer() : _buildImageViewer()),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Hero(
        tag: widget.mediaPath ?? widget.mediaUrl ?? 'media',
        child: widget.mediaPath != null
            ? Image.file(File(widget.mediaPath!), fit: BoxFit.contain)
            : widget.mediaUrl != null
            ? Image.network(widget.mediaUrl!, fit: BoxFit.contain)
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller!),
          GestureDetector(
            onTap: () {
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
            child: Container(
              color: Colors.transparent,
              child: !_controller!.value.isPlaying
                  ? const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 80,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
