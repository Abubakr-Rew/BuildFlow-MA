import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/haptics.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The message field under a chat: up to 5 lines, the send button appears
/// with the first non-blank character.
///
/// Laid out as `[leading] [field] [trailing]` so later stages can add
/// buttons without rebuilding it: the «+» for photos goes into [leading],
/// the microphone into [trailingWhenEmpty], which shows in place of the
/// send button while the field is empty.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.onSend,
    this.leading = const [],
    this.trailingWhenEmpty,
    super.key,
  });

  /// Gets the text as typed; the field is cleared already.
  final ValueChanged<String> onSend;
  final List<Widget> leading;
  final Widget? trailingWhenEmpty;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  static const _fieldRadius = 22.0;

  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    Haptics.light();
    // Keeps the keyboard open for the next message.
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(_fieldRadius)),
      borderSide: BorderSide.none,
    );

    final trailing = _hasText
        ? Padding(
            key: const ValueKey('send'),
            padding: const EdgeInsets.only(left: AppTheme.spacing8),
            child: _SendButton(onPressed: _send),
          )
        : widget.trailingWhenEmpty ?? const SizedBox(key: ValueKey('none'));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing12,
            AppTheme.spacing8,
            AppTheme.spacing12,
            AppTheme.spacing8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ...widget.leading,
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(maxMessageLength),
                  ],
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.messageHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                      vertical: 12,
                    ),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: trailing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Tooltip(
      message: AppLocalizations.of(context).sendMessage,
      child: SizedBox.square(
        dimension: AppTheme.iconButtonSize,
        child: Material(
          color: t.accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(Icons.arrow_upward_rounded, color: t.onAccent),
          ),
        ),
      ),
    );
  }
}
