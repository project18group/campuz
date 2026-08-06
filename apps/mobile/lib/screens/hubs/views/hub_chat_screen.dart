import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/screens/hubs/models/hub_message.dart';
import 'package:mobile/screens/hubs/widget/hub_attachment_bubble.dart';
import 'package:mobile/screens/hubs/widget/hub_composer.dart';
import 'package:mobile/screens/hubs/widget/hub_message_bubble.dart';
import 'package:mobile/screens/hubs/widget/invite_card.dart';
import 'package:mobile/screens/hubs/widget/attachment_preview_sheet.dart';
import 'package:mobile/core/mock/mock_data.dart';

class HubChatScreen extends StatefulWidget {
  const HubChatScreen({super.key});

  @override
  State<HubChatScreen> createState() => _HubChatScreenState();
}

class _HubChatScreenState extends State<HubChatScreen> {
  bool sendAsSms = false;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  late List<HubMessage> messages;

  @override
  void initState() {
    super.initState();
    // Map MockData messages to HubMessage for the UI
    messages = MockData.messages.map((m) {
      return HubMessage(
        sender: m.sender.name,
        message: m.content,
        time: "${m.timestamp.hour}:${m.timestamp.minute.toString().padLeft(2, '0')}",
        smsSent: false,
        messageType: MessageType.text,
      );
    }).toList();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      messages.add(
        HubMessage(
          sender: MockData.currentUser.name,
          message: text,
          time: "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          smsSent: sendAsSms,
          messageType: MessageType.text,
        ),
      );
    });

    _messageController.clear();

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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: Text("Document", style: AppTextStyles.title.copyWith(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: Text("Gallery", style: AppTextStyles.title.copyWith(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text("Camera", style: AppTextStyles.title.copyWith(color: AppColors.textPrimary)),
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

  void _showPreviewAndSend({
    required String path,
    required String name,
    required String type,
  }) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentPreviewSheet(
        filePath: path,
        fileName: name,
        fileType: type,
      ),
    ).then((caption) {
      if (caption != null) {
        setState(() {
          messages.add(
            HubMessage(
              sender: MockData.currentUser.name,
              time: "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
              smsSent: sendAsSms,
              messageType: MessageType.attachment,
              message: caption,
              attachmentName: name,
              attachmentType: type,
              attachmentPath: path,
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
    });
  }

  // Pick Docs
  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles();
    if (result == null) return;

    final file = result.files.single;
    if (file.path == null) return;

    final ext = file.extension ?? 'pdf';
    _showPreviewAndSend(
      path: file.path!,
      name: file.name,
      type: ext,
    );
  }

  // Pick Pics
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    _showPreviewAndSend(
      path: image.path,
      name: image.name,
      type: 'image',
    );
  }

  // Open Camera
  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    _showPreviewAndSend(
      path: image.path,
      name: image.name,
      type: 'image',
    );
  }

  void _showReactionPicker(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["👍", "❤️", "😂", "🎉", "😮", "😢"].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      messages[index].reaction = emoji;
                    });
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        leading: IconButton(
          onPressed: () {
            context.go("/home");
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: GestureDetector(
          onTap: () {
            context.push("/hub-info");
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Computer Science 2029",
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
              Text(
                "248 members",
                style: AppTextStyles.body.copyWith(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.push("/hub-info");
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                const InviteCard(),
                const SizedBox(height: 8),
                ...messages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final message = entry.value;

                  if (message.messageType == MessageType.attachment) {
                    return HubAttachmentBubble(
                      message: message,
                      onLongPress: () {
                        _showReactionPicker(index);
                      },
                    );
                  } else {
                    return HubMessageBubble(
                      message: message,
                      onLongPress: () {
                        _showReactionPicker(index);
                      },
                    );
                  }
                }),
              ],
            ),
          ),
          HubComposer(
            sendAsSms: sendAsSms,
            controller: _messageController,
            onSmsChanged: (value) {
              setState(() {
                sendAsSms = value;
              });
            },
            onAttach: _showAttachmentOptions,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
