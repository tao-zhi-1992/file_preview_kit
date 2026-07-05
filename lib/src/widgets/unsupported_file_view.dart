import 'package:flutter/material.dart';

import 'preview_message_view.dart';

class UnsupportedFileView extends StatelessWidget {
  final String title;
  final String message;

  const UnsupportedFileView({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return PreviewMessageView(
      icon: Icons.insert_drive_file_outlined,
      title: title,
      message: message,
    );
  }
}
