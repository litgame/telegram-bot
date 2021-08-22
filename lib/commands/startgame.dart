import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';

class StartGameCmd extends GameCommand {
  StartGameCmd();

  @override
  String get name => 'startgame';

  @override
  bool get system => false;

  void gameStartMessage(TelegramEx telegram, LitGame game) {
    catchAsyncError(telegram
        .sendMessage(
            game.id,
            '=========================================\r\n'
            'Начинаем новую игру! \r\n'
            'ВНИМАНИЕ, с кем ещё не общались - напишите мне в личку, чтобы я тоже мог вам отправлять сообщения.\r\n'
            'У вас на планете дискриминация роботов, поэтому сам я вам просто так написать не смогу :-( \r\n'
            '\r\n'
            'Кто хочет поучаствовать?',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: [
              [
                InlineKeyboardButton(text: "Да!", callback_data: '/joinme'),
                InlineKeyboardButton(text: "Неть...", callback_data: '/kickme')
              ]
            ]))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id);
    }));
  }

  void _resumeOldGame(Message message, TelegramEx telegram) async {
    try {
      final game = await client.getGameInfo(message.chat.id.toString());
      reportError(message.chat.id, game.toString());
      await client.endGame(game['id'], game['admin']['id']);
    } catch (_) {}
  }

  @override
  ArgParser? getParser() => null;

  @override
  List<LitGameState> get worksAtStates => [];

  @override
  void runCheckedState(Message message, TelegramEx telegram) async {
    if (message.chat.id > 0) {
      catchAsyncError(telegram.sendMessage(message.chat.id,
          'Эту команду надо не в личке запускать, а в чате с игроками!'));
      return;
    }

    try {
      await client.startGame(
          message.chat.id.toString(), triggeredById.toString());
    } on ValidationException catch (error) {
      if (error.type == ErrorType.exists) {
        _resumeOldGame(message, telegram);
      } else {
        reportError(message.chat.id, error.toString());
      }
      return;
    }
    final game = LitGame.startNew(message.chat.id);
    game.players[triggeredById] = LitUser(message.from!, isAdmin: true);
    gameStartMessage(telegram, game);
  }
}
