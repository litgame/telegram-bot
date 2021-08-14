import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';
import 'setmaster.dart';

class FinishJoinCmd extends GameCommand {
  FinishJoinCmd();

  @override
  bool get system => true;

  @override
  String get name => 'finishjoin';

  @override
  void runCheckedState(Message message, TelegramEx telegram) async {
    if (message.chat.id != game.admin.id) {
      catchAsyncError(
          telegram.sendMessage(message.chat.id, 'Не ты админ текущей игры!'));
      return;
    }

    try {
      await client.finishJoin(game.id.toString(), message.chat.id.toString());
    } on ValidationException catch (error) {
      if (error.type == ErrorType.access) {
        reportError(message.chat.id, error.message);
        return;
      } else
        rethrow;
    }

    game.state = LitGameState.selectMaster;
    deleteScheduledMessages(telegram);
    final keyboard = <List<InlineKeyboardButton>>[];
    game.players.values.forEach((player) {
      var text = player.nickname + ' (' + player.fullName + ')';
      if (player.isAdmin) {
        text += '(admin)';
      }
      if (player.isGameMaster) {
        text += '(master)';
      }

      keyboard.add([
        InlineKeyboardButton(
            text: text,
            callback_data: SetMasterCmd().buildCommandCall({
              'gci': gameChatId.toString(),
              'userId': player.telegramUser.id.toString()
            }))
      ]);
    });
    telegram
        .sendMessage(game.admin.id, 'Выберите мастера игры: ',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: keyboard))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id);
    });
  }

  @override
  ArgParser getParser() => getGameBaseParser();

  @override
  List<LitGameState> get worksAtStates => [LitGameState.join];
}
