import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class HubComposer extends StatelessWidget {
  final bool sendAsSms;
  final TextEditingController controller;
  final ValueChanged<bool> onSmsChanged;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  const HubComposer({
    super.key,
    required this.sendAsSms,
    required this.controller,
    required this.onSmsChanged,
    required this.onAttach,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,

            children: [
              Text(
                "Send as SMS",
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),

              RotatedBox(
                quarterTurns: 3,

                child: Switch(value: sendAsSms, onChanged: onSmsChanged),
              ),
            ],
          ),

          Row(
            children: [
              IconButton(
                onPressed: onAttach,
                icon: const Icon(Icons.attach_file),
              ),

              Expanded(
                child: TextField(
                  controller: controller,

                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),

                  keyboardType: TextInputType.multiline,

                  maxLines: null,
                  minLines: 1,

                  decoration: InputDecoration(
                    hintText: "Post announcement",

                    hintStyle: AppTextStyles.label,

                    filled: true,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),

                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              IconButton(onPressed: onSend, icon: const Icon(Icons.send)),
            ],
          ),
        ],
      ),
    );
  }
}
