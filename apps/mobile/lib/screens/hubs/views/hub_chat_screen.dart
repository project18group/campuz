import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class HubMessage {
  final String sender;
  final String message;
  final String time;
  final bool smsSent;

  HubMessage({
    required this.sender,
    required this.message,
    required this.time,
    required this.smsSent,
  });
}

class HubChatScreen extends StatefulWidget {
  const HubChatScreen({super.key});

  @override
  State<HubChatScreen> createState() => _HubChatScreenState();
}

class _HubChatScreenState extends State<HubChatScreen> {
  bool sendAsSms = false;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<HubMessage> messages = [
    HubMessage(
      sender: "Class Rep",
      message:
          "Welcome to Computer Science 2029. Important announcements will be shared here.",
      time: "8:30 AM",
      smsSent: true,
    ),

    HubMessage(
      sender: "Class Rep",
      message: "Programming II lecture has been moved to LT4.",
      time: "11:15 AM",
      smsSent: false,
    ),
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      messages.add(
        HubMessage(
          sender: "Class Rep",
          message: text,
          time: "now",
          smsSent: sendAsSms,
        ),
      );
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: Text("Document", style: AppTextStyles.title),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
              ListTile(
                leading: Icon(Icons.image),
                title: Text("Gallery", style: AppTextStyles.title),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text("Camera", style: AppTextStyles.title),
                onTap: () {
                  Navigator.pop(context);
                  _pickCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick Docs
  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles();

    if (result == null) return;

    final file = result.files.single;

    debugPrint(file.name);
  }

  // Pick Pics
  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    debugPrint(image.name);
  }

  // Open Camera
  Future<void> _pickCamera() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    debugPrint(image.name);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
          children: [
            Text("Computer Science 2029", style: AppTextStyles.title),

            Text("248 members", style: AppTextStyles.body),
          ],
        ),

        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                // return Container(
                //   margin: const EdgeInsets.only(bottom: 16),

                //   padding: const EdgeInsets.all(12),
                //   decoration: BoxDecoration(
                //     borderRadius: BorderRadius.circular(16),
                //     color: Colors.grey.shade200,
                //   ),

                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,

                //     children: [
                //       Text(
                //         message.sender,
                //         style: const TextStyle(fontWeight: FontWeight.bold),
                //       ),
                //       const SizedBox(height: 8),

                //       Text(message.message),

                //       const SizedBox(height: 8),

                //       Row(
                //         children: [
                //           Text(message.time),

                //           if (message.smsSent)
                //             const Padding(
                //               padding: EdgeInsets.only(left: 8),
                //               child: Text("SMS"),
                //             ),
                //         ],
                //       ),
                //     ],
                //   ),
                // );

                return Align(
                  alignment: Alignment.centerRight,

                  child: GestureDetector(
                    onLongPress: () {
                      showBottomSheet(
                        backgroundColor: AppColors.background,
                        context: context,
                        builder: (_) {
                          return Container(
                            margin: const EdgeInsets.all(24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: AppColors.primaryDark,
                              // color: Theme.of(context).shadowColor,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text('👍', style: TextStyle(fontSize: 28)),
                                Text('❤️', style: TextStyle(fontSize: 28)),
                                Text('🎉', style: TextStyle(fontSize: 28)),
                                Text('😂', style: TextStyle(fontSize: 28)),

                                Text('😮', style: TextStyle(fontSize: 28)),
                                Text('😒', style: TextStyle(fontSize: 28)),
                              ],
                            ),
                          );
                        },
                      );
                      log("Reaction pops");
                    },

                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                            topRight: Radius.circular(0),
                          ),

                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              message.sender,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(message.message),

                            const SizedBox(height: 8),

                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(message.time),

                                    if (message.smsSent)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(Icons.sms, size: 16),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          //Bottom Composer
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                //SMS Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Send as SMS",
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    RotatedBox(
                      quarterTurns: 3,
                      child: Switch(
                        value: sendAsSms,
                        onChanged: (newValue) {
                          setState(() {
                            sendAsSms = newValue;
                          });
                        },
                      ),
                    ),

                    // Checkbox(
                    //   value: sendAsSms,
                    //   onChanged: (value) {
                    //     setState(() {
                    //       sendAsSms = value ?? false;
                    //     });
                    //   },
                    // ),
                  ],
                ),

                //Composer
                Row(
                  children: [
                    //File attachment icon
                    IconButton(
                      onPressed: _showAttachmentOptions,
                      icon: const Icon(Icons.attach_file),
                    ),

                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: null, //Allow infinite vertical lines
                        minLines: 1, //Starts as a single line

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

                    //Send Icon
                    IconButton(onPressed: _sendMessage, icon: Icon(Icons.send)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
