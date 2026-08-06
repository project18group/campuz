import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/mock/mock_data.dart';
import 'package:mobile/shared/widgets/app_fab.dart';
import 'package:mobile/screens/home/widgets/empty_home_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> get _joinedHubs => MockData.isNewUser ? const <dynamic>[] : MockData.hubs;
  bool get _hasHubs => _joinedHubs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          "Campuz",
          style: AppTextStyles.heading.copyWith(fontSize: 25),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _hasHubs
            ? ListView.separated(
                key: const ValueKey('home-hub-list'),
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _joinedHubs.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 80),
                itemBuilder: (context, index) {
                  final hub = _joinedHubs[index];

                  // Determine if there are unread messages (using a fake logic for mock data)
                  final hasUnread = index == 0;
                  final unreadCount = hasUnread ? 2 : 0;

                  // Get initials
                  final words = hub.name.split(' ');
                  final initials = words.length > 1
                      ? '${words[0][0]}${words[1][0]}'
                      : words[0].substring(0, 2).toUpperCase();

                  // Get last message (if any)
                  final hubMessages = MockData.messages
                      .where((m) => m.hubId == hub.id)
                      .toList();
                  final lastMessage = hubMessages.isNotEmpty
                      ? hubMessages.last.content
                      : 'No messages yet';

                  final time = hubMessages.isNotEmpty
                      ? '${hubMessages.last.timestamp.hour}:${hubMessages.last.timestamp.minute.toString().padLeft(2, '0')}'
                      : '';

                  return ListTile(
                    onTap: () {
                      context.push("/hub-chat");
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
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
                            hub.name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          time,
                          style: AppTextStyles.caption.copyWith(
                            color: hasUnread
                                ? AppColors.primaryDeep
                                : AppColors.textSecondary,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                              lastMessage,
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
                                unreadCount.toString(),
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
            : EmptyHomeState(
                key: const ValueKey('home-empty-state'),
              ),
      ),
      floatingActionButton: _hasHubs
          ? AppFab(
              onPressed: () {
                context.push("/select-contact");
              },
            )
          : null,
    );
  }
}
