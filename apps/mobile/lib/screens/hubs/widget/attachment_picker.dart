import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

/// Modern WhatsApp/Telegram-style attachment sheet with a grid of large
/// circular option buttons and a staggered entrance animation.
class AttachmentPicker extends StatefulWidget {
  final VoidCallback onPickDocument;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  /// Optional callbacks for the placeholder options. When null, tapping the
  /// option simply closes the sheet and shows a "Coming soon" snackbar.
  final VoidCallback? onPickLocation;
  final VoidCallback? onPickContact;
  final VoidCallback? onPickPoll;
  final VoidCallback? onPickEvent;
  final VoidCallback? onPickAIImages;

  const AttachmentPicker({
    super.key,
    required this.onPickDocument,
    required this.onPickGallery,
    required this.onPickCamera,
    this.onPickLocation,
    this.onPickContact,
    this.onPickPoll,
    this.onPickEvent,
    this.onPickAIImages,
  });

  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<AttachmentPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _optionCount = 8;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(VoidCallback? callback, String label) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (callback != null) {
      callback();
    } else {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            "$label — Coming soon",
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
      );
    }
  }

  List<_AttachmentOption> get _options => [
        _AttachmentOption(
          label: "Document",
          icon: Icons.description_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () => _handleTap(widget.onPickDocument, "Document"),
        ),
        _AttachmentOption(
          label: "Camera",
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFFEF476F),
          onTap: () => _handleTap(widget.onPickCamera, "Camera"),
        ),
        _AttachmentOption(
          label: "Gallery",
          icon: Icons.photo_rounded,
          color: const Color(0xFF3B82F6),
          onTap: () => _handleTap(widget.onPickGallery, "Gallery"),
        ),
        _AttachmentOption(
          label: "Location",
          icon: Icons.location_on_rounded,
          color: const Color(0xFF22C55E),
          onTap: () => _handleTap(widget.onPickLocation, "Location"),
        ),
        _AttachmentOption(
          label: "Contact",
          icon: Icons.person_rounded,
          color: const Color(0xFF06B6D4),
          onTap: () => _handleTap(widget.onPickContact, "Contact"),
        ),
        _AttachmentOption(
          label: "Poll",
          icon: Icons.poll_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () => _handleTap(widget.onPickPoll, "Poll"),
        ),
        _AttachmentOption(
          label: "Event",
          icon: Icons.event_rounded,
          color: const Color(0xFFF97316),
          onTap: () => _handleTap(widget.onPickEvent, "Event"),
        ),
        _AttachmentOption(
          label: "AI Images",
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF10B981),
          onTap: () => _handleTap(widget.onPickAIImages, "AI Images"),
        ),
      ];

  /// Staggered interval for the button at [index]: (start, end) of the
  /// controller's timeline that this button animates over.
  (double, double) _staggerInterval(int index) {
    const double overlap = 0.55;
    final double start = (index / _optionCount) * (1 - overlap);
    return (start, start + overlap);
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Share content",
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final (start, end) = _staggerInterval(index);
                  final scale = CurvedAnimation(
                    parent: _controller,
                    curve: Interval(start, end, curve: Curves.easeOutBack),
                  );
                  final fade = CurvedAnimation(
                    parent: _controller,
                    curve: Interval(start, end, curve: Curves.easeOut),
                  );
                  return FadeTransition(
                    opacity: fade,
                    child: ScaleTransition(
                      scale: scale,
                      child: _AttachmentButton(option: options[index]),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentOption {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _AttachmentButton extends StatelessWidget {
  final _AttachmentOption option;

  const _AttachmentButton({required this.option});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: option.color,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: option.onTap,
            child: Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              child: Icon(
                option.icon,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}