import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/models/popup_model.dart';
import 'package:novopharma/services/popup_service.dart';
import 'package:novopharma/theme.dart';

class PopupDialog extends StatefulWidget {
  final PopupModel popup;

  const PopupDialog({super.key, required this.popup});

  @override
  State<PopupDialog> createState() => _PopupDialogState();
}

class _PopupDialogState extends State<PopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _displayTimer;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    if (widget.popup.displayDuration != null) {
      _remainingSeconds = widget.popup.displayDuration;
      _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds! > 0) {
            _remainingSeconds = _remainingSeconds! - 1;
          } else {
            timer.cancel();
            _close();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleTap() {
    _close();
    PopupService.handleRedirection(context, widget.popup.link);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image part
                    GestureDetector(
                      onTap: _handleTap,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: widget.popup.imageUrl.isNotEmpty
                            ? Image.network(
                                widget.popup.imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color:
                                            LightModeColors.lightSurfaceVariant,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: LightModeColors.lightSurfaceVariant,
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: LightModeColors.lightPrimary,
                                child: const Icon(
                                  Icons.campaign,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    // Text details part
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.popup.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.popup.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.lightPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                "En savoir plus",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Close button (X)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _close,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Timer badge if duration exists
                if (_remainingSeconds != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: LightModeColors.lightPrimary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$_remainingSeconds s",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

void showPremiumPopup(BuildContext context, PopupModel popup) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => PopupDialog(popup: popup),
  );
}
