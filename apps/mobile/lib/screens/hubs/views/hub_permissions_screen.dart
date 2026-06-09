import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class HubPermissionsScreen extends StatefulWidget {
  const HubPermissionsScreen({super.key});

  @override
  State<HubPermissionsScreen> createState() => _HubPermissionsScreenState();
}

class _HubPermissionsScreenState extends State<HubPermissionsScreen> {
  final List<String> members = ['Kofi', 'Yaw', "Kwame", "Kane", "Nuella"];

  final Set<String> selectedAdmins = {};
  final bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            context.go("/create-hub");
          },
          icon: Icon(Icons.arrow_back_ios_new),
        ),
        title: Text('Hub Permissions', style: AppTextStyles.title),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose administrators for this academic hub.',
                  style: AppTextStyles.body,
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 20),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'You are the hub owner and automatically have administrator privileges.',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];

                final isAdmin = selectedAdmins.contains(member);

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),

                  title: Text(member, style: AppTextStyles.label),

                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        if (isAdmin) {
                          selectedAdmins.remove(member);
                        } else {
                          selectedAdmins.add(member);
                        }
                      });
                    },

                    child: Text(isAdmin ? 'Promoted ✓' : 'Promote'),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(
              text: _isCreating? "Creating Hub...":"Finish",

              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Creating academic hub...",),
                    duration: Duration(milliseconds: 800),
                  ),
                );
                Future.delayed(Duration(milliseconds: 900), () {
                  // ignore: use_build_context_synchronously
                  context.go('/hub-created');
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
