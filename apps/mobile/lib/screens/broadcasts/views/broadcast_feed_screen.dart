import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/mock/mock_data.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class BroadcastFeedScreen extends StatelessWidget {
  const BroadcastFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final broadcasts = MockData.broadcasts;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Campus Broadcasts'),
      ),
      body: Container(
        color: AppColors.background,
        child: broadcasts.isEmpty
            ? Center(
                child: Text(
                  'No broadcasts available',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: broadcasts.length,
                itemBuilder: (context, index) {
                  final broadcast = broadcasts[index];
                  final isUrgent = broadcast.priority == 'high';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isUrgent ? AppColors.primary.withValues(alpha: 0.30) : AppColors.border,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: NetworkImage(broadcast.sender.avatarUrl),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  broadcast.sender.name,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUrgent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDeep,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'URGENT',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            broadcast.title,
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 18,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            broadcast.content,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "${broadcast.timestamp.day}/${broadcast.timestamp.month}/${broadcast.timestamp.year} at ${broadcast.timestamp.hour}:${broadcast.timestamp.minute.toString().padLeft(2, '0')}",
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
