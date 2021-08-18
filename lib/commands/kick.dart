import 'package:args/args.dart';
import 'package:litgame_telegram_bot/commands/core/game_command.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/kick_request.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/src/telegram/model.dart';
import 'package:teledart_app/src/application/application.dart';
import 'package:teledart_app/src/complex_command.dart';

class KickCmd extends ComplexGameCommand {
  @override
  Map<String, CmdAction> get actionMap => {
        'sel-user': onSelectUser,
        'cancel': onCancel,
        'sel-adm': onSelectAdminOrMaster
      };

  @override
  bool get system => false;

  ArgParser getParser() => super.getParser()
    ..addOption('uid')
    ..addOption('mode');

  @override
  String get name => 'kick';

  static const modeAdmin = 'a';
  static const modeMaster = 'm';

  @override
  void onNoAction(Message message, TelegramEx telegram) async {
    final game = await findGameEveryWhere();
    if (game == null) return;

    final user = game.players[triggeredById];
    if (user == null) return;

    KickRequest.create(game.id, user.id, game.state);

    if (user.isGameMaster || user.isAdmin) {
      game.state = LitGameState.paused;
      catchAsyncError(
          telegram.sendMessage(game.id, 'Минуточку, игра приостановлена'));
      _printSelectTargetUser(game, user);
    } else {
      final result = await client.kick(game.id.toString(),
          triggeredById.toString(), triggeredById.toString());
      if (result.success) {
        game.players.remove(triggeredById);
        catchAsyncError(
            telegram.sendMessage(game.id, '${user.fullName} выходит из игры'));
      }
    }
  }

  void _printSelectTargetUser(LitGame game, LitUser me) {
    final keyboard = <List<InlineKeyboardButton>>[];
    game.players.values.forEach((player) {
      var text = '';
      if (player.id == me.id) {
        text += '(Это ты!)';
      }
      text += player.nickname + ' (' + player.fullName + ')';
      if (player.isAdmin) {
        text += '(admin)';
      }
      if (player.isGameMaster) {
        text += '(master)';
      }

      keyboard.add([
        InlineKeyboardButton(
            text: text,
            callback_data:
                buildAction('sel-user', {'kickId': player.id.toString()}))
      ]);
    });
    keyboard.add([
      InlineKeyboardButton(
          text: 'Я передумал!',
          callback_data: buildAction('cancel', {'uid': me.id.toString()}))
    ]);

    catchAsyncError(telegram
        .sendMessage(me.id, 'Выбирай, кого кикнуть: ',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: keyboard))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id);
    }));
  }

  void onCancel(Message message, TelegramEx telegram) async {
    final userId = arguments?['uid'];
    if (userId == null) return;

    final request = KickRequest.find(userId);
    if (request == null) return;

    final game = await findGameEveryWhere();
    if (game == null) return;

    game.state = request.lastGameState;
    request.delete();
    deleteScheduledMessages(telegram);
    catchAsyncError(telegram.sendMessage(game.id, 'Продолжаем игру!'));
  }

  void onSelectUser(Message message, TelegramEx telegram) async {
    final targetId = arguments?['uid'];
    if (targetId == null) return;

    final game = await findGameEveryWhere();
    if (game == null) return;

    final me = game.players[triggeredById];
    if (me == null) return;

    final target = game.players[targetId];
    if (target == null) return;

    if (target.isAdmin) {
      _printSelectMasterOrAdmin(game, me, admin: true);
    }
    if (target.isGameMaster) {
      _printSelectMasterOrAdmin(game, me, admin: false);
    }
  }

  void _printSelectMasterOrAdmin(LitGame game, LitUser me,
      {required bool admin}) {
    final keyboard = <List<InlineKeyboardButton>>[];
    game.players.values.forEach((player) {
      var text = '';
      if (player.id == me.id) return;
      text += player.nickname + ' (' + player.fullName + ')';
      if (player.isAdmin) {
        if (admin) return;
        text += '(admin)';
      }
      if (player.isGameMaster) {
        if (!admin) return;
        text += '(master)';
      }

      keyboard.add([
        InlineKeyboardButton(
            text: text,
            callback_data: buildAction('sel-adm', {
              'uid': player.id.toString(),
              'mode': admin ? modeAdmin : modeMaster
            }))
      ]);
    });
    keyboard.add([
      InlineKeyboardButton(
          text: 'Я передумал!',
          callback_data: buildAction('cancel', {'uid': me.id.toString()}))
    ]);

    var header = 'Выбери нового ';
    if (admin) {
      header += 'админа игры:';
    } else {
      header += 'мастера игры:';
    }

    catchAsyncError(telegram
        .sendMessage(me.id, header,
            reply_markup: InlineKeyboardMarkup(inline_keyboard: keyboard))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id);
    }));
  }

  void onSelectAdminOrMaster(Message message, TelegramEx telegram) async {
    final targetId = arguments?['uid'];
    if (targetId == null) return;

    final mode = arguments?['mode'];
    if (mode == null) return;

    final game = await findGameEveryWhere();
    if (game == null) return;

    final me = game.players[triggeredById];
    if (me == null) return;

    final target = game.players[targetId];
    if (target == null) return;

    final kickRequest = KickRequest.find(me.id);
    if (kickRequest == null) return;

    if (mode == modeAdmin) {
      kickRequest.newAdminId = targetId;
    } else if (mode == modeMaster) {
      kickRequest.newMasterId = targetId;
    } else {
      throw ArgumentError(
          'Invalid mode argument: ${mode}. Should be ${modeAdmin} or ${modeMaster}',
          'mode');
    }

    if ((target.isGameMaster && kickRequest.newMasterId == null) ||
        (target.isAdmin && kickRequest.newAdminId == null)) {
      _printSelectMasterOrAdmin(game, me,
          admin: kickRequest.newAdminId == null);
    } else {
      _kickRequest(kickRequest, game, target);
    }
  }

  void _kickRequest(
      KickRequest kickRequest, LitGame game, LitUser target) async {
    final kickResult = await client.kick(
        kickRequest.gameId.toString(),
        kickRequest.triggeredById.toString(),
        kickRequest.targetUserId.toString(),
        newAdminId: kickRequest.newAdminId?.toString(),
        newMasterId: kickRequest.newMasterId?.toString());
    if (kickResult.success) {
      if (kickResult.newAdminId != null) {
        final newAdminId = convertId(kickResult.newAdminId!);
        final user = game.players[newAdminId];
        if (user == null) throw 'Assigned admin does not exists in game';
        user.isAdmin = true;
        target.isAdmin = false;
        catchAsyncError(telegram.sendMessage(
            game.id, '${user.fullName} будет новым админом.'));
      }
      if (kickResult.newMasterId != null) {
        final newMasterId = convertId(kickResult.newMasterId!);
        final user = game.players[newMasterId];
        if (user == null) throw 'Assigned master does not exists in game';
        user.isGameMaster = true;
        target.isGameMaster = false;
        catchAsyncError(telegram.sendMessage(
            game.id, '${user.fullName} будет новым игромастером.'));
      }

      game.players.remove(target.id);
    }

    if (kickResult.gameStopped) {
      game.stop();
      catchAsyncError(telegram.sendMessage(game.id, 'Всё, наигрались!'));
    }
  }

  @override
  List<LitGameState> get worksAtStates =>
      [LitGameState.game, LitGameState.training, LitGameState.paused];
}
