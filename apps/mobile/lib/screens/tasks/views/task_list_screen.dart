import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/mock/mock_data.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = MockData.tasks;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Tasks & Assignments'),
      ),
      body: Container(
        color: AppColors.background,
        child: tasks.isEmpty
            ? Center(
                child: Text(
                  'No tasks available',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  Color statusColor;
                  IconData statusIcon;
                  if (task.status == 'pending') {
                    statusColor = AppColors.warning;
                    statusIcon = Icons.pending_actions;
                  } else if (task.status == 'submitted') {
                    statusColor = AppColors.primaryDeep;
                    statusIcon = Icons.check_circle_outline;
                  } else {
                    statusColor = AppColors.success;
                    statusIcon = Icons.verified;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 16,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        child: Icon(statusIcon, color: statusColor),
                      ),
                      title: Text(
                        task.title,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task.courseName, style: AppTextStyles.caption),
                            const SizedBox(height: 4),
                            Text(
                              "Due: ${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}",
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(
                        task.status.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
