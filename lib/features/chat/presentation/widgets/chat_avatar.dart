import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/presentation/chat_texts.dart';
import 'package:flutter/material.dart';

/// Picture of a chat: a graphite square with an accent building for a
/// project chat, the other person's initials for a direct one.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({required this.chat, this.size = 52, super.key});

  final Chat chat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    if (chat.type.isProject) {
      return ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: t.graphite,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.apartment_rounded,
            size: size * 0.5,
            color: t.accent,
          ),
        ),
      );
    }
    return AvatarInitials(
      name: AppLocalizations.of(context).chatTitle(chat),
      size: size,
    );
  }
}
