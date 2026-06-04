import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text("Register Page", style: AppTextStyles.heading)),
    );
  }
}
