import 'package:args/args.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/src/telegram/model.dart';
import 'package:teledart_app/src/application/application.dart';
import 'package:teledart_app/src/complex_command.dart';

import 'core/game_command.dart';

class JoinCmd extends ComplexGameCommand {
  JoinCmd({this.triggeredByAlternative});

  @override
  Map<String, CmdAction> get actionMap =>
      {'accept': onAccept, 'decline': onDecline, 'join': onJoin};

  @override
  bool get system => false;

  ArgParser getParser() => super.getParser()
    ..addOption('gci')
    ..addOption('uid')
    ..addOption('b_uid');

  @override
  String get name => 'join';

  int? triggeredByAlternative;

  @override
  int get triggeredById => triggeredByAlternative ?? super.triggeredById;

  /// Приходится экономить на gci, потому что сообщение не умещается в 64 символа
  @override
  String buildAction(String actionName, [Map<String, String>? parameters]) {
    parameters ??= {};
    parameters[ComplexCommand.ACTION] = actionName;
    return buildCommandCall(parameters);
  }

  @override
  void onNoAction(Message message, TelegramEx telegram) {
    if (triggeredByAlternative != null) {
      /// debug
      _getChatMember(triggeredByAlternative!).then((user) {
        _joinOrdinaryUser(user!);
      });
    } else {
      final triggeredBy = game.players[triggeredById];
      if (triggeredBy == null) {
        final from = message.from;
        if (from == null) return;
        _joinOrdinaryUser(LitUser(from));
      } else if (triggeredBy.isAdmin || triggeredBy.isGameMaster) {
        _joinByAdminMaster(triggeredBy);
      }
    }
  }

  void _joinOrdinaryUser(LitUser wantJoin) {
    final userName = wantJoin.fullName + '(${wantJoin.nickname})';
    catchAsyncError(telegram
        .sendMessage(game.master.id, '${userName} хочет присоединиться к игре',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: [
              [
                InlineKeyboardButton(
                    text: 'Принять',
                    callback_data: buildAction('accept', {
                      'uid': wantJoin.id.toString(),
                      'gci': game.id.toString()
                    })),
                InlineKeyboardButton(
                    text: 'Отказать',
                    callback_data: buildAction('decline', {
                      'uid': wantJoin.id.toString(),
                      'gci': game.id.toString()
                    }))
              ]
            ]))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id, tag: 'join');
    }));
  }

  void onAccept(Message message, TelegramEx telegram) async {
    await deleteScheduledMessages(telegram,
        chatId: game.master.id, tags: ['join']);

    final wantJoinId = int.tryParse(arguments?['uid']);
    if (wantJoinId == null) return;

    final wantJoin = await _getChatMember(wantJoinId);
    if (wantJoin == null) return;

    final keyboard = <List<InlineKeyboardButton>>[];
    game.players.values.forEach((player) {
      var text = '';
      text += player.nickname + ' (' + player.fullName + ')';

      keyboard.add([
        InlineKeyboardButton(
            text: text,
            callback_data: buildAction('join',
                {'uid': wantJoin.id.toString(), 'b_uid': player.id.toString()}))
      ]);
    });
    keyboard.add([
      InlineKeyboardButton(
          text: 'Отмена',
          callback_data: buildAction('decline',
              {'uid': wantJoin.id.toString(), 'gci': game.id.toString()}))
    ]);

    catchAsyncError(telegram
        .sendMessage(game.master.id,
            'Выбирай, перед каким игроком поставить новенького: ',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: keyboard))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id, tag: 'join');
    }));
  }

  void onJoin(Message message, TelegramEx telegram) async {
    await deleteScheduledMessages(telegram,
        chatId: game.master.id, tags: ['join']);

    final wantJoinId = int.tryParse(arguments?['uid']);
    if (wantJoinId == null) return;

    final wantJoin = await _getChatMember(wantJoinId);
    if (wantJoin == null) return;

    final triggeredBy = game.players[triggeredById];
    if (triggeredBy == null || !triggeredBy.isGameMaster) {
      reportError(game.id, 'Только игромастер может аппрувнуть нового игрока');
      return;
    }

    bool success = await catchAsyncError(client.join(
        game.id.toString(), triggeredById.toString(),
        targetUserId: wantJoinId.toString(), position: 99));

    if (success) {
      game.players[wantJoin.id] = wantJoin;
      final playerName = wantJoin.fullName + '(${wantJoin.nickname})';
      catchAsyncError(telegram.sendMessage(
          game.id, 'Игрок $playerName присоединился к игре'));
    }
  }

  void onDecline(Message message, TelegramEx telegram) async {
    deleteScheduledMessages(telegram, chatId: game.master.id, tags: ['join']);
    final wantJoinId = int.tryParse(arguments?['uid']);
    if (wantJoinId == null) return;

    final wantJoin = await _getChatMember(wantJoinId);
    if (wantJoin == null) return;

    final playerName = wantJoin.fullName + '(${wantJoin.nickname})';

    catchAsyncError(telegram.sendMessage(
        game.id, 'Игромастер не принял игрока $playerName'));
  }

  Future<LitUser?> _getChatMember(int uid) async {
    final member = await catchAsyncError(telegram.getChatMember(game.id, uid));
    if (member == null) return null;
    return LitUser(member.user);
  }

  void _joinByAdminMaster(LitUser admin) {}

  @override
  // TODO: implement worksAtStates
  List<LitGameState> get worksAtStates =>
      [LitGameState.game, LitGameState.training];
}
