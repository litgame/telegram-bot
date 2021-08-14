import 'package:args/args.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'game_command.dart';
import 'setcollection.dart';

class SetOrderCmd extends GameCommand {
  SetOrderCmd();

  @override
  bool get system => true;

  @override
  ArgParser? getParser() => getGameBaseParser()
    ..addOption('userId')
    ..addOption('reset')
    ..addOption('finish');

  @override
  String get name => 'setorder';

  static final Map<int, List<LitUser>> _sorted = {};

  List<LitUser> get sorted {
    var sorted = _sorted[game.id];
    if (sorted == null) {
      sorted = _sorted[game.id] = [];
    }
    return sorted;
  }

  @override
  void runCheckedState(Message message, TelegramEx telegram) async {
    final id = message.from?.id;
    if (id == null) {
      throw 'message.from.id is null!';
    }
    if (id != game.admin.id) {
      reportError(id, 'Это можно только админу игры');
      return;
    }
    deleteScheduledMessages(telegram);

    if (arguments?['finish'] != null) {
      game.state = LitGameState.selectCollection;
      final cmd = ComplexCommand.withAction(() => SetCollectionCmd(), 'list',
          asyncErrorHandler, {'gci': gameChatId.toString()});
      cmd.run(message, telegram);
      return;
    }

    if (arguments?['reset'] != null) {
      try {
        await client.sortReset(game.id.toString(), id.toString());
        sorted.clear();
        await client.sortPlayer(game.id.toString(), game.master.id.toString(),
            game.master.id.toString(), 0);
        sorted.add(game.master);

        telegram
            .sendMessage(
                message.chat.id,
                'В каком порядке будут ходить игроки:\r\n' +
                    _getSortedUsersListText(),
                reply_markup:
                    InlineKeyboardMarkup(inline_keyboard: getSortButtons()))
            .then((msg) {
          scheduleMessageDelete(msg.chat.id, msg.message_id);
        });
      } catch (error) {
        reportError(id, error.toString());
      }
      return;
    }

    final userId = arguments?['userId'];
    if (userId != null) {
      final uid = int.parse(userId);
      final user = game.players[uid];
      if (user != null) {
        try {
          final position = await client.sortPlayer(
              game.id.toString(), id.toString(), user.id.toString(), 99);
          sorted.add(user);
          if (position != sorted.length - 1) {
            reportError(id,
                'Игрок отсортирован, но оказался на позиции $position вместо ${sorted.length - 1}');
          }
        } catch (error) {
          reportError(id, error.toString());
          return;
        }
      }
    }

    if (sorted.length == game.players.length) {
      telegram
          .sendMessage(message.chat.id,
              'Игроки отсортированы:\r\n' + _getSortedUsersListText(),
              reply_markup: InlineKeyboardMarkup(inline_keyboard: [
                [
                  InlineKeyboardButton(
                      text: 'Играем!',

                      // callback_data: GameFlowCmd.args(arguments).buildAction('start')),
                      callback_data: buildCommandCall(
                          {'gci': gameChatId.toString(), 'finish': ''})),
                  InlineKeyboardButton(
                      text: 'Отсортировать заново',
                      callback_data: buildCommandCall(
                          {'gci': gameChatId.toString(), 'reset': ''}))
                ]
              ]))
          .then((msg) {
        scheduleMessageDelete(msg.chat.id, msg.message_id);
      });
    } else {
      telegram
          .sendMessage(
              message.chat.id,
              'В каком порядке будут ходить игроки:\r\n' +
                  _getSortedUsersListText(),
              reply_markup:
                  InlineKeyboardMarkup(inline_keyboard: getSortButtons()))
          .then((msg) {
        scheduleMessageDelete(msg.chat.id, msg.message_id);
      });
    }
  }

  String _getSortedUsersListText() {
    if (sorted.isEmpty) {
      return '';
    }
    var usersList = '';
    var i = 1;
    for (var sortedUser in sorted) {
      usersList += i.toString() +
          ' ' +
          sortedUser.nickname +
          '(' +
          sortedUser.fullName +
          ')\r\n';
      i++;
    }
    return usersList;
  }

  List<List<InlineKeyboardButton>> getSortButtons() {
    var usersToSelect = <List<InlineKeyboardButton>>[];
    game.players.forEach((key, user) {
      var skip = false;
      sorted.forEach((entry) {
        if (entry == user) skip = true;
      });
      if (skip) return;
      usersToSelect.add([
        InlineKeyboardButton(
            text: user.nickname + '(' + user.fullName + ')',
            callback_data: buildCommandCall({
              'gci': game.id.toString(),
              'userId': user.telegramUser.id.toString()
            }))
      ]);
    });
    return usersToSelect;
  }

  @override
  List<LitGameState> get worksAtStates => [LitGameState.sorting];
}
