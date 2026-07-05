import 'package:flutter/material.dart';

class PreviewMessageView extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;

  const PreviewMessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _PreviewMessageBody(
          icon: icon,
          iconColor: iconColor,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _PreviewMessageBody extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;

  const _PreviewMessageBody({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: iconColor),
        const SizedBox(height: 12),
        _PreviewMessageTitle(title: title),
        const SizedBox(height: 8),
        _PreviewMessageText(message: message),
      ],
    );
  }
}

class _PreviewMessageTitle extends StatelessWidget {
  final String title;

  const _PreviewMessageTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _PreviewMessageText extends StatelessWidget {
  final String message;

  const _PreviewMessageText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
