import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;
  final bool isVideo;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
    this.isVideo = false,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late TransformationController _transformationController;
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.imageUrl),
    )..initialize().then((_) {
      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
      }
    }).catchError((e) {
      debugPrint('Error initializing video: $e');
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    if (widget.isVideo && _videoInitialized) {
      _videoController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: _videoInitialized
              ? AspectRatio(
                  aspectRatio: _videoController.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_videoController),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoController.value.isPlaying
                                ? _videoController.pause()
                                : _videoController.play();
                          });
                        },
                        child: Container(
                          color: Colors.black26,
                          child: Center(
                            child: Icon(
                              _videoController.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading video...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      body: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.all(20),
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
