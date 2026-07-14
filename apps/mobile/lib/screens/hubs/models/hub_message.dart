enum MessageType { text, attachment }

class HubMessage {
  final String sender;
  final String? message; // Used for text or caption
  final String time;
  final bool smsSent;
  final MessageType messageType;
  final String? attachmentName;
  final String? attachmentType; // pdf, docx, ppt, image, etc.
  final String? attachmentUrl;
  final String? attachmentPath; // Local file path for opening/previewing
  String? reaction;

  HubMessage({
    required this.sender,
    required this.time,
    required this.smsSent,
    this.messageType = MessageType.text,
    this.message,
    this.attachmentName,
    this.attachmentType,
    this.attachmentUrl,
    this.attachmentPath,
    this.reaction,
  });
}
