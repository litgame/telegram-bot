// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:args/args.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'game_command.dart';
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
  void runChecked(Message message, TelegramEx telegram) async {
    deleteScheduledMessages(telegram);
    final player = game.players[int.parse(arguments?['userId'])];
    if (player == null) {
      reportError(message.from.id, 'Player not found!');
      return;
    }
    try {
      final success = await client.setMaster(
          game.id.toString(), message.from.id.toString(), player.id.toString());
      if (!success) {
        reportError(message.from.id, 'Can\'t set master');
        return;
      }
      player.isGameMaster = true;
      catchAsyncError(telegram.sendMessage(gameChatId,
          player.nickname + '(' + player.fullName + ') будет игромастером!'));

      game.state = LitGameState.sorting;

      final cmd = Command.withArguments(() => SetOrderCmd(), {
        'gci': gameChatId.toString(),
        'userId': arguments?['userId'],
        'reset': ''
      });
      cmd.run(message, telegram);
    } catch (error) {
      reportError(message.from.id, error.toString());
      return;
    }
  }

  @override
  List<LitGameState> get worksAtStates => [LitGameState.selectMaster];
}
