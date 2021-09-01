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
    deleteScheduledMessages(telegram, tags: ['game-${game.id}']);
    _sendChatIdRequest(message, user, telegram);
    sendStatisticsToAdmin(game, telegram, game.id);
  }

  void _sendChatIdRequest(Message message, LitUser user, TelegramEx telegram) {
    var text = user.nickname + ' подключился к игре!\r\n';
    telegram.sendMessage(message.chat.id, text);
  }

  @override
  ArgParser? getParser() => null;

  @override
  List<LitGameState> get worksAtStates => [LitGameState.join];
}
