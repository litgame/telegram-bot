import 'package:args/args.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';
import 'setorder.dart';

class SetMasterCmd extends GameCommand {
  SetMasterCmd();

  @override
  bool get system => true;

  @override
  ArgParser getParser() => getGameBaseParser()..addOption('userId');

  @override
  String get name => 'setmaster';

  @override
  void runCheckedState(Message message, TelegramEx telegram) async {
    final id = message.from?.id;
    if (id == null) {
      throw 'message.from.id is null!';
    }

    deleteScheduledMessages(telegram);
    final player = game.players[int.parse(arguments?['userId'])];
    if (player == null) {
      reportError(id, 'Player not found!');
      return;
    }
    try {
      final success = await client.setMaster(
          game.id.toString(), id.toString(), player.id.toString());
      if (!success) {
        reportError(id, 'Can\'t set master');
        return;
      }
      player.isGameMaster = true;
      catchAsyncError(telegram.sendMessage(gameChatId,
          player.nickname + '(' + player.fullName + ') будет игромастером!'));

      game.state = LitGameState.sorting;

      final cmd = Command.withArguments(
          () => SetOrderCmd(),
          {
            'gci': gameChatId.toString(),
            'userId': arguments?['userId'],
            'reset': ''
          },
          asyncErrorHandler);
      cmd.run(message, telegram);
    } catch (error) {
      reportError(id, error.toString());
      return;
    }
  }

  @override
  List<LitGameState> get worksAtStates => [LitGameState.selectMaster];
}
