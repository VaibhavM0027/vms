import 'package:flutter/material.dart';

class VisitorPhotoWidget extends StatelessWidget {
  final String? photoUrl;
  final double height;
  final double width;
  final BoxFit fit;
  final bool enableEnlarge;
  final String? heroTag;

  const VisitorPhotoWidget({
    super.key,
    required this.photoUrl,
    this.height = 150,
    this.width = 150,
    this.fit = BoxFit.cover,
    this.enableEnlarge = true,
    this.heroTag,
  });

  void _showEnlargedPhoto(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            width: 200,
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 50,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap to close',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[600]!),
        ),
        child: const Icon(
          Icons.person,
          size: 40,
          color: Colors.grey,
        ),
      );
    }

    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        photoUrl!,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: width,
            color: Colors.grey[700],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Log the specific error for debugging
          print('Error loading image from URL: $photoUrl');
          print('Error details: $error');
          
          return Container(
            height: height,
            width: width,
            color: Colors.grey[700],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Image failed to load',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Add hero animation if heroTag is provided
    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    if (enableEnlarge) {
      return GestureDetector(
        onTap: () => _showEnlargedPhoto(context, photoUrl!),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}