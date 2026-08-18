import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Botón SOS grande con anillo pulsante. Muestra un indicador de progreso
/// mientras se obtiene la ubicación.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    required this.isSending,
  });

  final VoidCallback onPressed;
  final bool isSending;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!widget.isSending)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                return Container(
                  width: 170 + 90 * t,
                  height: 170 + 90 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emergency.withValues(alpha: (1 - t) * 0.25),
                  ),
                );
              },
            ),
          Material(
            color: AppColors.emergency,
            shape: const CircleBorder(),
            elevation: 10,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.isSending ? null : widget.onPressed,
              child: SizedBox(
                width: 170,
                height: 170,
                child: Center(
                  child: widget.isSending
                      ? CircularProgressIndicator(color: Colors.white)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sos, size: 60, color: Colors.white),
                            const SizedBox(height: 4),
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
