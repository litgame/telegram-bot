import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'joinme.dart';

class KickMeCmd extends JoinMeCmd {
  KickMeCmd();

  @override
  bool get system => true;

  @override
  String get name => 'kickme';

  @override
  List<LitGameState> get worksAtStates =>
      [LitGameState.join, LitGameState.game, LitGameState.training];

  @override
  void runChecked(Message message, TelegramEx telegram) async {
    final id = message.from?.id;
    if (id == null) {
      throw 'message.from.id is null!';
    }

    try {
      final result =
          await client.kick(game.id.toString(), id.toString(), id.toString());
      if (result.success) {
        if (result.gameStopped) {
          game.stop();
          catchAsyncError(telegram.sendMessage(
              message.chat.id, 'Всё, наигрались!',
              reply_markup: ReplyKeyboardRemove(remove_keyboard: true)));
          return;
        }

        game.players.remove(id);
        if (game.state == LitGameState.join) {
          sendStatisticsToAdmin(game, telegram, message.chat.id);
        }

        if (result.newAdminId != null) {
          final newAdmin =
              game.players[convertId(result.newAdminId.toString())];
          if (newAdmin == null) {
            throw 'New admin not found!';
          }
          newAdmin.isAdmin = true;
          catchAsyncError(telegram.sendMessage(game.id,
              "${newAdmin.nickname} (${newAdmin.fullName}) будет новым админом игры."));
        }
        if (result.newMasterId != null) {
          final newMaster =
              game.players[convertId(result.newAdminId.toString())];
          if (newMaster == null) {
            throw 'New master not found!';
          }
          newMaster.isGameMaster = true;
          catchAsyncError(telegram.sendMessage(game.id,
              "${newMaster.nickname} (${newMaster.fullName}) будет новым мастером игры."));
        }
        if (result.nextTurnByUserId != null) {
          //TODO: дописать передачу хода другому игроку
        }
      }
    } on ValidationException catch (error) {
      if (error.type == ErrorType.notFound) {
        reportError(id, 'Вы уже не играете в игру, всё норм');
        return;
      } else
        rethrow;
    }
  }

  @override
  ArgParser? getParser() => null;
}
