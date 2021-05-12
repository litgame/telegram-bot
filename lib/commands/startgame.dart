// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'game_command.dart';

class StartGameCmd extends GameCommand {
  StartGameCmd();

  @override
  String get name => 'startgame';

  @override
  bool get system => false;

  @override
  void run(Message message, TelegramEx telegram) async {
    checkGameChat(message);
    try {
      await client.startGame(
          message.chat.id.toString(), message.from.id.toString());
    } on ValidationException catch (error) {
      if (error.type == ErrorType.exists) {
        _resumeOldGame(message, telegram);
      } else {
        reportError(message.chat.id, error.toString());
      }
    }
    final game = LitGame.startNew(message.chat.id);
    game.players[message.from.id] = LitUser(message.from, isAdmin: true);
    gameStartMessage(telegram, game);
  }

  void gameStartMessage(TelegramEx telegram, LitGame game) {
    telegram
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
    });
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
  void runChecked(Message message, TelegramEx telegram) {}
}
