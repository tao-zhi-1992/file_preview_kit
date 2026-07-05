import 'package:flutter/material.dart';

import 'preview_message_view.dart';

class PreviewErrorView extends StatelessWidget {
  final String title;
  final String message;

  const PreviewErrorView({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PreviewMessageView(
      icon: Icons.error_outline,
      iconColor: colorScheme.error,
      title: title,
      message: message,
    );
  }
}
