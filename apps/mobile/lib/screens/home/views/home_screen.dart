import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          "Campuz",
          style: AppTextStyles.heading.copyWith(fontSize: 28),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //Flexible or Sizedbox to prevent overflow on smaller devices
            // Flexible(
            //   child: SvgPicture.asset(
            //     'assets/images/home.svg',
            //     height: MediaQuery.of(context).size.height * 0.3,
            //   ),
            // ),
            SizedBox(
              height: 220,
              child: SvgPicture.asset("assets/images/firsttime_home.svg"),
            ),
            Text(
              'No Hubs or Messages Yet?',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: 12),

            Text(
              'Join hub using an invite link or QR code shared by your class representative to start receiving message updates',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 6),

            Text(
              'OR',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading.copyWith(fontSize: 18),
            ),

            const SizedBox(height: 6),

            Text(
              'Are you a rep? Create a hub to get started',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),

            const SizedBox(height: 40),

            PrimaryButton(
              text: 'Join Hub',
              onPressed: () {
                context.go('/join-hub');
              },
            ),
          ],
        ),
      ),
    );
  }
}
