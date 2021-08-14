import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:meta/meta.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';
import 'finishjoin.dart';

class JoinMeCmd extends GameCommand {
  JoinMeCmd();

  @override
  bool get system => true;

  @override
  String get name => 'joinme';

  @override
  void runCheckedState(Message message, TelegramEx telegram) async {
    var success = false;
    var registered = true;
    await telegram
        .sendMessage(
            triggeredById,
            'Добро пожаловать в игру! Я буду писать тебе в личку,'
            ' что происходит в общем чате, чтобы тебе туда-сюда не прыгать. '
            'Кроме того, я буду форвардить всё, что ты мне напишешь в общий чат.')
        .onError((error, stackTrace) {
      registered = false;
      final failedUser = LitUser(message.from!);
      return telegram.sendMessage(
          game.id,
          failedUser.nickname +
              ' не смог подключиться, потому что не написал мне в личку, а надо =\\ Пусть напишет сначала мне в личку, а потом попробует ещё раз!');
    });

    if (!registered) return;

    try {
      success = await client.join(game.id.toString(), triggeredById.toString());
    } on ValidationException catch (error) {
      switch (error.type) {
        case ErrorType.exists:
          return;
        case ErrorType.anotherGame:
          reportError(
              game.id, 'Нельзя подключиться к игре, пока играешь где-то ещё');
          return;
        default:
          rethrow;
      }
    }

    final user = LitUser(message.from!);
    if (!success) {
      reportError(game.id, 'Не удалось добавить ${user.nickname} в игру');
      return;
    }

    game.players[user.id] = user;
    _sendChatIdRequest(message, user, telegram);
    sendStatisticsToAdmin(game, telegram, message.chat.id);
  }

  void _sendChatIdRequest(Message message, LitUser user, TelegramEx telegram) {
    var text = user.nickname + ' подключился к игре!\r\n';
    user.registrationChecked.then((registered) {
      if (!registered) {
        text +=
            'Мы с тобой ещё не общались, напиши мне в личку, чтобы продолжить игру.\r\n';
      }
      catchAsyncError(telegram.sendMessage(message.chat.id, text));
    });
  }

  @protected
  void sendStatisticsToAdmin(
      LitGame game, TelegramEx telegram, int gameChatId) {
    try {
      var text = '*В игре примут участие:*\r\n';
      var markup;
      if (game.players.isEmpty) {
        text = '*что-то все расхотели играть*';
        markup = ReplyMarkup();
      } else {
        for (var user in game.players.values) {
          text += ' - ' + user.nickname + ' (' + user.fullName + ')\r\n';
        }
        markup = InlineKeyboardMarkup(inline_keyboard: [
          [
            InlineKeyboardButton(
                text: 'Завершить набор игроков',
                callback_data: FinishJoinCmd()
                    .buildCommandCall({'gci': gameChatId.toString()}))
          ]
        ]);

        catchAsyncError(telegram
            .sendMessage(game.admin.id, text.escapeMarkdownV2(),
                parse_mode: 'MarkdownV2', reply_markup: markup)
            .then((message) {
          scheduleMessageDelete(message.chat.id, message.message_id);
        }));
      }
    } catch (error) {
      reportError(gameChatId, error.toString());
    }
  }

  @override
  ArgParser? getParser() => null;

  @override
  List<LitGameState> get worksAtStates => [LitGameState.join];
}
