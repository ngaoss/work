import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenMediaViewer extends StatefulWidget {
  final List<String> mediaList;
  final int initialIndex;

  const FullScreenMediaViewer({
    super.key,
    required this.mediaList,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
        title: widget.mediaList.length > 1
            ? Text(
                "${_currentIndex + 1} / ${widget.mediaList.length}",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaList.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final url = widget.mediaList[index];
          final isVideo =
              url.toLowerCase().endsWith('.mp4') ||
              url.toLowerCase().endsWith('.mov');

          return Center(
            child: isVideo ? _VideoItem(url: url) : _ImageItem(url: url),
          );
        },
      ),
    );
  }
}

class _ImageItem extends StatelessWidget {
  final String url;
  const _ImageItem({required this.url});

  @override
  Widget build(BuildContext context) {
    final bool isNet = url.startsWith('http') || !File(url).existsSync();
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Hero(
        tag: url,
        child: isNet
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              )
            : Image.file(File(url), fit: BoxFit.contain),
      ),
    );
  }
}

class _VideoItem extends StatefulWidget {
  final String url;
  const _VideoItem({required this.url});

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    final bool isNet =
        widget.url.startsWith('http') || !File(widget.url).existsSync();
    if (isNet) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    } else {
      _controller = VideoPlayerController.file(File(widget.url));
    }

    _controller!.initialize().then((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller!.play();
        _controller!.setLooping(true);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
