import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/app_fab.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mock joined hubs list.
  final List<Map<String, dynamic>> _joinedHubs = [
    {
      "id": "cs2029",
      "name": "Computer Science 2029",
      "lastMessage": "Programming II lecture has been moved to LT4.",
      "time": "11:15 AM",
      "unreadCount": 2,
      "initials": "CS",
    },
    {
      "id": "mth301",
      "name": "Linear Algebra (MTH 301)",
      "lastMessage": "Assignment 2 file uploaded by Class Rep.",
      "time": "Yesterday",
      "unreadCount": 0,
      "initials": "LA",
    }
  ];

  @override
  Widget build(BuildContext context) {
    final hasHubs = _joinedHubs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          "Campuz",
          style: AppTextStyles.heading.copyWith(fontSize: 28, color: AppColors.primary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: hasHubs
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _joinedHubs.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
              itemBuilder: (context, index) {
                final hub = _joinedHubs[index];
                final hasUnread = hub["unreadCount"] > 0;

                return ListTile(
                  onTap: () {
                    context.push("/hub-chat");
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                    child: Text(
                      hub["initials"],
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hub["name"],
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        hub["time"],
                        style: AppTextStyles.caption.copyWith(
                          color: hasUnread ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            hub["lastMessage"],
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              hub["unreadCount"].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                      context.push('/join-hub');
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: AppFab(
        onPressed: () {
          context.push("/select-contact");
        },
      ),
    );
  }
}
