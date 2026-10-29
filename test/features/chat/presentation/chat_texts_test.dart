import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:buildflow/features/chat/presentation/chat_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsRu();
  const names = {'u-1': 'Бакыт Касымов', 'u-2': 'Асан Бекович'};

  Message photos(int count, {String? caption, String sender = 'u-1'}) =>
      Message(
        id: 'm-1',
        clientId: 'm-1',
        chatId: 'chat-1',
        senderId: sender,
        kind: MessageKind.photo,
        text: caption,
        createdAt: DateTime(2026, 10, 28),
        attachments: [
          for (var i = 0; i < count; i++)
            MessageAttachment(id: 'a$i', url: 'fake:$i'),
        ],
      );

  Chat chatWith(Message last, {ChatType type = ChatType.project}) => Chat(
        id: 'chat-1',
        type: type,
        participantIds: const ['u-1', 'u-2'],
        updatedAt: DateTime(2026, 10, 28),
        title: 'Ала-Тоо',
        lastMessage: last,
      );

  test('a photo message reads «Фото» or «3 фото», with the caption', () {
    expect(l10n.messageSummary(photos(1), names), 'Фото');
    expect(l10n.messageSummary(photos(3), names), '3 фото');
    expect(
      l10n.messageSummary(photos(3, caption: 'Плита 8-го этажа'), names),
      '3 фото · Плита 8-го этажа',
    );
  });

  test('the chat preview marks photos for the icon', () {
    expect(
      l10n.chatPreview(chatWith(photos(2, caption: 'Леса')), 'u-2', names),
      (prefix: 'Бакыт: ', text: '2 фото · Леса', media: MessageKind.photo),
    );
    expect(
      l10n.chatPreview(chatWith(photos(1)), 'u-1', names),
      (prefix: 'Вы: ', text: 'Фото', media: MessageKind.photo),
    );
    expect(
      l10n.chatPreview(
        chatWith(photos(1), type: ChatType.direct),
        'u-2',
        names,
      ),
      (prefix: '', text: 'Фото', media: MessageKind.photo),
    );
  });

  test('a voice message reads «Голосовое · 0:42» with the microphone', () {
    final voice = photos(0).copyWith(
      kind: MessageKind.voice,
      attachments: const [
        MessageAttachment(id: 'v', url: '/v.m4a', durationMs: 42400),
      ],
    );
    expect(l10n.messageSummary(voice, names), 'Голосовое · 0:42');
    expect(
      l10n.chatPreview(chatWith(voice), 'u-2', names),
      (prefix: 'Бакыт: ', text: 'Голосовое · 0:42', media: MessageKind.voice),
    );
  });
}
