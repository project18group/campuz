import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final bool obscureText;
  final TextEditingController? controller;
  final int? maxLines;
  final TextInputType keyboardType;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.maxLines,
    this.prefixText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,

          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixText: widget.prefixText,

            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
