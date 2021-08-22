import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';

class JoinMeCmd extends GameCommand with JoinKickStatistics {
  JoinMeCmd({this.triggeredByAlternative});

  int? triggeredByAlternative;

  @override
  int get triggeredById => triggeredByAlternative ?? super.triggeredById;

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

    LitUser user;

    if (message.from?.id != triggeredById) {
      final member =
          await telegram.getChatMember(message.chat.id, triggeredById);
      user = LitUser(member.user);
    } else {
      user = LitUser(message.from!);
    }

    if (!success) {
      reportError(game.id, 'Не удалось добавить ${user.nickname} в игру');
      return;
    }

    game.players[user.id] = user;
    _sendChatIdRequest(message, user, telegram);
    sendStatisticsToAdmin(game, telegram, game.id);
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

  @override
  ArgParser? getParser() => null;

  @override
  List<LitGameState> get worksAtStates => [LitGameState.join];
}
