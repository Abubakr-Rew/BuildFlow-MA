import 'package:flutter/material.dart';

/// Banner shown at the top of the screen when the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    required this.message,
    this.isVisible = true,
    super.key,
  });

  final String message;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: isVisible ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1 : 0,
        child: Material(
          color: Theme.of(context).colorScheme.error,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
