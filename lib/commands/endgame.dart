import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';

class EndGameCmd extends GameCommand {
  EndGameCmd();

  @override
  String get name => 'endgame';

  @override
  bool get system => false;

  @override
  ArgParser? getParser() => null;

  @override
  List<LitGameState> get worksAtStates => [];

  @override
  void runCheckedState(Message message, TelegramEx telegram) async {
    checkGameChat(message);

    try {
      final id = message.from?.id;
      if (id == null) {
        throw 'message.from.id is null!';
      }
      final success =
          await client.endGame(message.chat.id.toString(), id.toString());
      if (!success) {
        reportError(message.chat.id,
            'Не получилось остановить игру... непонятно, почему.');
        return;
      }
    } on ValidationException catch (error) {
      if (error.type == ErrorType.access) {
        reportError(message.chat.id, error.message);
        return;
      } else
        rethrow;
    }

    final game = LitGame.find(message.chat.id);
    game?.stop();
    catchAsyncError(telegram.sendMessage(message.chat.id, 'Всё, наигрались!',
        reply_markup: ReplyKeyboardRemove(remove_keyboard: true)));
  }
}

class StopGameCmd extends EndGameCmd {
  String get name => 'stopgame';
}
