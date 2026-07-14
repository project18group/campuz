import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HubInfoScreen extends StatefulWidget {
  const HubInfoScreen({super.key});

  @override
  State<HubInfoScreen> createState() => _HubInfoScreenState();
}

class _HubInfoScreenState extends State<HubInfoScreen> {
  final String hubName = "Computer Science 2029";
  final String inviteLink = "https://campuz.app/invite/abc123";
  final String description = "Official communication channel for the Computer Science 2029 class. Lecture updates, slides, and exam dates will be posted here.";

  List<Map<String, dynamic>> members = [
    {"name": "Class Rep", "username": "@class_rep", "isAdmin": true, "isMe": false},
    {"name": "John Doe", "username": "@johndoe", "isAdmin": true, "isMe": false},
    {"name": "Alice Smith", "username": "@alice_s", "isAdmin": false, "isMe": true}, // Current user
    {"name": "Bob Johnson", "username": "@bobj", "isAdmin": false, "isMe": false},
    {"name": "Charlie Brown", "username": "@charlie_b", "isAdmin": false, "isMe": false},
    {"name": "Diana Prince", "username": "@diana", "isAdmin": false, "isMe": false},
  ];

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite link copied to clipboard")),
    );
  }

  void _showQrDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Join $hubName", style: AppTextStyles.title, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(data: inviteLink),
                  ),
                ),
                const SizedBox(height: 16),
                Text("ABC123", style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleAdmin(int index) {
    // Current user Alice is not admin in mock, but for demo let's allow toggling admin status of others!
    setState(() {
      members[index]["isAdmin"] = !members[index]["isAdmin"];
    });
    final newRole = members[index]["isAdmin"] ? "Admin" : "Member";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${members[index]["name"]} is now a $newRole")),
    );
  }

  void _removeMember(int index) {
    final name = members[index]["name"];
    setState(() {
      members.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$name removed from the hub")),
    );
  }

  void _showMemberOptions(int index) {
    final member = members[index];
    if (member["isMe"]) return; // Can't manage yourself this way

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Manage ${member["name"]}",
                  style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Icon(member["isAdmin"] ? Icons.arrow_downward : Icons.arrow_upward),
                title: Text(member["isAdmin"] ? "Dismiss as Admin" : "Make Hub Admin"),
                onTap: () {
                  Navigator.pop(context);
                  _toggleAdmin(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text("Remove from Hub", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeMember(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hub Info"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Text(
                      "CS",
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hubName,
                    style: AppTextStyles.heading.copyWith(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${members.length} members",
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Description Section
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Description", style: AppTextStyles.title.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Invite Section
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Invite Code & Link", style: AppTextStyles.title.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            inviteLink,
                            style: AppTextStyles.body.copyWith(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, color: AppColors.primary),
                        onPressed: _copyLink,
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code, color: AppColors.primary),
                        onPressed: _showQrDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Members Section Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Members (${members.length})",
                    style: AppTextStyles.title.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: AppColors.primary),
                    onPressed: _showQrDialog,
                  ),
                ],
              ),
            ),

            // Members List
            Container(
              color: Colors.white,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    onTap: () => _showMemberOptions(index),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.08),
                      child: Text(
                        member["name"][0],
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          member["name"],
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (member["isMe"]) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "you",
                              style: AppTextStyles.caption.copyWith(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(member["username"], style: AppTextStyles.caption),
                    trailing: member["isAdmin"]
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Admin",
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Danger Zone
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text("Leave Hub", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Leave Hub"),
                          content: const Text("Are you sure you want to leave this academic hub?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // pop dialog
                                context.go("/home"); // return home
                              },
                              child: const Text("Leave", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text("Delete Hub", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Admins only — this action cannot be undone", style: TextStyle(fontSize: 12)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Delete Hub"),
                          content: const Text("Are you sure you want to permanently delete this hub? All announcements and documents will be deleted."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // pop dialog
                                context.go("/home"); // return home
                              },
                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
