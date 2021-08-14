import 'package:args/args.dart';
import 'package:litgame_telegram_bot/botapp.dart';
import 'package:litgame_telegram_bot/commands/gameflow.dart';
import 'package:litgame_telegram_bot/commands/trainingflow.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'game_command.dart';

class SkipCmd extends GameCommand {
  SkipCmd();

  @override
  String get name => 'skip';

  @override
  bool get system => false;

  @override
  void run(Message message, TelegramEx telegram) async {
    this.message = message;
    this.telegram = telegram;
    final from = message.from;
    if (from == null) return;

    if (message.chat.type == 'private') {
      final gameId = await client.findGameOfPlayer(from.id.toString());
      final game = LitGame.find(int.parse(gameId.replaceFirst(APP_PREFIX, '')));
      if (game == null) {
        _accessError(message.chat.id, telegram);
        return;
      }
      _runSkipTurnCommand(game);
    } else {
      super.run(message, telegram);
    }
  }

  void _runSkipTurnCommand(LitGame game) {
    final from = message.from;
    if (from == null) return;
    final player = game.players[from.id];
    if (player == null || (!player.isGameMaster && !player.isAdmin)) {
      _accessError(message.chat.id, telegram);
      return;
    }

    if (game.state == LitGameState.game) {
      final cmd = ComplexCommand.withAction(
          () => GameFlowCmd(), 'skip', this.asyncErrorHandler, {
        'gci': game.id.toString(),
      });
      cmd.runWithErrorHandler(message, telegram);
      return;
    } else if (game.state == LitGameState.training) {
      final cmd = ComplexCommand.withAction(
          () => TrainingFlowCmd(), 'skip', this.asyncErrorHandler, {
        'gci': game.id.toString(),
      });
      cmd.runWithErrorHandler(message, telegram);
      return;
    }
  }

  void _accessError(int chatId, TelegramEx telegram) => telegram.sendMessage(
      chatId,
      'Не могу найти игру, в которой ты был бы админом или мастером...');

  @override
  ArgParser? getParser() => null;

  @override
  List<LitGameState> get worksAtStates =>
      [LitGameState.game, LitGameState.training];

  @override
  void runCheckedState(Message message, TelegramEx telegram) =>
      _runSkipTurnCommand(game);
}
