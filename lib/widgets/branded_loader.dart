import 'package:flutter/material.dart';

/// Full-screen loading view that mirrors the native splash (logo on white) so
/// the hand-off from the cold-start splash to the first in-app fetch is
/// seamless.
class BrandedLoader extends StatelessWidget {
  const BrandedLoader({super.key, this.message});

  final String? message;

  static const Color _brand = Color(0xFFB5651D);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Image(
              image: AssetImage('assets/branding/osho_logo_transparent.png'),
              width: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_brand),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 18),
              Text(
                message!,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
