import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class SelectContactScreen extends StatelessWidget {
  const SelectContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,

        leading: IconButton(
          onPressed: () {
            context.go("/home");
          },
          icon: Icon(Icons.arrow_back_ios_new),
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Conversation', style: AppTextStyles.title),
            Text('No contacts yet', style: AppTextStyles.caption),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              //
            },
            icon: Icon(Icons.search),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(child: Icon(Icons.groups)),

            title: Text("New Academic Hub", style: AppTextStyles.label),
            onTap: () {
              context.go("/create-hub");
            },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add)),
            title: Text('New Contact', style: AppTextStyles.label),
            trailing: IconButton(
              onPressed: () {
                //
              },
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ),

          const Divider(),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Contacts', style: AppTextStyles.label),
          ),

          ListTile(
            leading: const CircleAvatar(),
            title: const Text('Destine'),
            subtitle: const Text('+233 XX XXX XXXX'),
            onTap: () {},
          ),

          ListTile(
            leading: const CircleAvatar(),
            title: const Text('Ama'),
            subtitle: const Text('+233 XX XXX XXXX'),
            onTap: () {},
          ),

          ListTile(
            leading: const CircleAvatar(),
            title: const Text('Kofi'),
            subtitle: const Text('+233 XX XXX XXXX'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
