import 'package:flutter/material.dart';

class ScanLoadingOverlay extends StatelessWidget {
  const ScanLoadingOverlay({
    required this.status,
    super.key,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: status,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
