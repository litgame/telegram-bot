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
    final game = await findGameEveryWhere();
    if (game == null) return;
    try {
      final success =
          await client.endGame(game.id.toString(), triggeredById.toString());
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

    game.stop();
    catchAsyncError(telegram.sendMessage(game.id, 'Всё, наигрались!'));
  }
}

class StopGameCmd extends EndGameCmd {
  String get name => 'stopgame';
}
