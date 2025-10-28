import 'package:flutter/material.dart';

class VisitorPhotoWidget extends StatelessWidget {
  final String? photoUrl;
  final double height;
  final double width;
  final BoxFit fit;
  final bool enableEnlarge;
  final String? heroTag;
  final String? visitorName; // Add visitor name parameter

  const VisitorPhotoWidget({
    super.key,
    required this.photoUrl,
    this.visitorName, // Add visitor name parameter
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
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            width: 200,
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
        child: Center(
          child: Text(
            visitorName != null && visitorName!.isNotEmpty 
                ? visitorName![0].toUpperCase() 
                : '?',
            style: TextStyle(
              fontSize: height * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
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
          print('Stack trace: $stackTrace');
          
          // Show initial instead of question mark
          return Container(
            height: height,
            width: width,
            color: Colors.grey[700],
            child: Center(
              child: Text(
                visitorName != null && visitorName!.isNotEmpty 
                    ? visitorName![0].toUpperCase() 
                    : '?',
                style: TextStyle(
                  fontSize: height * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
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