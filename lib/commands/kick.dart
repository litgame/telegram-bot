import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/commands/core/game_command.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/kick_request.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/src/telegram/model.dart';
import 'package:teledart_app/src/application/application.dart';
import 'package:teledart_app/src/complex_command.dart';

import 'gameflow.dart';
import 'trainingflow.dart';

/// Кикает юзеров на стадии во время игры:
///  - Обычный игрок может кикнуть сам себя, тогда не будет задаваться никаких
///    вопросов.
///  - Админ может кикнуть кого угодно.
///  - Если админ кикает мастера, то ему выпадет список всех игроков с
///    предложением выбрать нового мастера.
///  - Если админ кикает сам себя. то ему выпадет диалог с предложением выбрать
///    нового админа
///  - Если админ ещё и и громастер, то ему последовательно будут показаны два
///    диалога.
///  - Ситуация, когда на первом ходу, когда игромастеру показывается три карты,
///    игромастер выходит или его кикают -не обрабатывается полностью. Будет
///    просто запущен ход следующего игрока, повторно три стартовые карты новому
///    мастеру показываться не будут.
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
    ..addOption('gci')
    ..addOption('uid')
    ..addOption('mode');

  @override
  String get name => 'kick';

  static const modeAdmin = 'a';
  static const modeMaster = 'm';

  @override
  void onNoAction(Message message, TelegramEx telegram) async {
    if (game.state == LitGameState.paused) {
      catchAsyncError(telegram.sendMessage(
          triggeredById, 'Игра приостановлена, подождите, пока её возобновят'));
      return;
    }

    final me = game.players[triggeredById];
    if (me == null) return;

    KickRequest.create(me.id, game.id, game.state);

    if (me.isAdmin) {
      game.state = LitGameState.paused;
      catchAsyncError(
          telegram.sendMessage(game.id, 'Минуточку, игра приостановлена'));
      _printSelectTargetUser(game, me);
    } else if (me.isGameMaster) {
      game.state = LitGameState.paused;
      catchAsyncError(
          telegram.sendMessage(game.id, 'Минуточку, игра приостановлена'));
      onSelectUser(message, telegram, targetId: me.id);
    } else {
      final result = await client.kick(game.id.toString(),
          triggeredById.toString(), triggeredById.toString());
      if (result.success) {
        game.players.remove(triggeredById);
        catchAsyncError(
            telegram.sendMessage(game.id, '${me.fullName} выходит из игры'));
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
                buildAction('sel-user', {'uid': player.id.toString()}))
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
      scheduleMessageDelete(msg.chat.id, msg.message_id, tag: 'kick');
    }));
  }

  void onCancel(Message message, TelegramEx telegram) async {
    final userId = arguments?['uid'];
    if (userId == null) return;

    final request = KickRequest.find(int.parse(userId));
    if (request == null) return;

    final game = await findGameEveryWhere();
    if (game == null) return;

    game.state = request.lastGameState;
    request.delete();
    deleteScheduledMessages(telegram,
        chatId: request.triggeredById, tags: ['kick']);
    catchAsyncError(telegram.sendMessage(game.id, 'Продолжаем игру!'));
  }

  void onSelectUser(Message message, TelegramEx telegram,
      {int? targetId}) async {
    targetId ??= int.tryParse(arguments?['uid']);
    if (targetId == null) return;

    final game = await findGameEveryWhere();
    if (game == null) return;

    final me = game.players[triggeredById];
    if (me == null) return;

    final target = game.players[targetId];
    if (target == null) return;

    final kickRequest = KickRequest.find(triggeredById);
    if (kickRequest == null) return;
    kickRequest.targetUserId = target.id;
    if (target.isAdmin || target.isGameMaster) {
      deleteScheduledMessages(telegram,
          chatId: kickRequest.triggeredById, tags: ['kick']);
      _printSelectMasterOrAdmin(game, me, admin: target.isAdmin);
    } else {
      _kickByRequest(kickRequest, game);
    }
  }

  void _printSelectMasterOrAdmin(LitGame game, LitUser me,
      {required bool admin}) {
    final keyboard = <List<InlineKeyboardButton>>[];
    game.players.values.forEach((player) {
      var text = '';
      if (player.id == me.id && admin) return;
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
      scheduleMessageDelete(msg.chat.id, msg.message_id, tag: 'kick');
    }));
  }

  void onSelectAdminOrMaster(Message message, TelegramEx telegram) async {
    final targetId = int.tryParse(arguments?['uid']);
    if (targetId == null) return;

    final mode = arguments?['mode'];
    if (mode == null) return;

    final game = await findGameEveryWhere();
    if (game == null) return;

    final me = game.players[triggeredById];
    if (me == null) return;

    final target = game.players[targetId];
    if (target == null) return;

    bool fail = false;
    if (me.id != targetId) {
      await telegram
          .sendMessage(
              targetId, 'Пссс-т, тебе хотят передать управление игрой!')
          .onError((error, stackTrace) {
        fail = true;
        return telegram.sendMessage(me.id,
            'Невозможно передать управление игроку ${target.nickname} (${target.fullName}), т.к. он ещё не писал в личку боту ни разу');
      });
    }

    if (fail) return;

    final kickRequest = KickRequest.find(me.id);
    if (kickRequest == null) return;

    if (mode == modeAdmin) {
      kickRequest.newAdminId = targetId;
    } else if (mode == modeMaster) {
      kickRequest.newMasterId = targetId;
    } else {
      throw ArgumentError(
          'Invalid mode argument: ${mode}. Should be ${modeAdmin} or ${modeMaster}');
    }

    final toKick = game.players[kickRequest.targetUserId];
    if (toKick == null) return;

    final shouldSetMaster =
        toKick.isGameMaster && kickRequest.newMasterId == null;
    final shouldSetAdmin = toKick.isAdmin && kickRequest.newAdminId == null;
    if (shouldSetAdmin || shouldSetMaster) {
      _printSelectMasterOrAdmin(game, me,
          admin: kickRequest.newAdminId == null);
    } else {
      await _kickByRequest(kickRequest, game);
      if (kickRequest.newMasterId != null) {
        if (game.state == LitGameState.training) {
          final cmd = ComplexCommand.withAction(
              () => TrainingFlowCmd(), '', this.asyncErrorHandler, {
            'gci': game.id.toString(),
          }) as TrainingFlowCmd;
          cmd
            ..runWithErrorHandler(message, telegram)
            ..printTrainingEndButton();
        }
      }
      kickRequest.delete();
    }
  }

  Future<KickResult> _kickByRequest(
      KickRequest kickRequest, LitGame game) async {
    final target = game.players[kickRequest.targetUserId];
    if (target == null) {
      throw 'Target user already removed';
    }

    if (game.currentPlayerId == target.id) {
      game.state = kickRequest.lastGameState;
      if (kickRequest.lastGameState == LitGameState.game) {
        final cmd = ComplexCommand.withAction(
            () => GameFlowCmd(), 'skip', this.asyncErrorHandler, {
          'gci': game.id.toString(),
        });
        await cmd.runWithErrorHandler(message, telegram);
      } else if (kickRequest.lastGameState == LitGameState.training) {
        final cmd = ComplexCommand.withAction(
            () => TrainingFlowCmd(), 'skip', this.asyncErrorHandler, {
          'gci': game.id.toString(),
        });
        await cmd.runWithErrorHandler(message, telegram);
      }
    }

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

      catchAsyncError(
          telegram.sendMessage(game.id, '${target.fullName} покидает игру.'));

      if (kickResult.gameStopped) {
        game.stop();
        catchAsyncError(telegram.sendMessage(game.id, 'Всё, наигрались!'));
        return kickResult;
      }

      game.players.remove(target.id);

      game.state = kickRequest.lastGameState;
      deleteScheduledMessages(telegram,
          chatId: kickRequest.triggeredById, tags: ['kick']);
      catchAsyncError(telegram.sendMessage(game.id, 'Продолжаем игру!'));
    }

    return kickResult;
  }

  @override
  List<LitGameState> get worksAtStates =>
      [LitGameState.game, LitGameState.training, LitGameState.paused];
}
