import 'dart:async';

import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/botapp.dart';
import 'package:litgame_telegram_bot/commands/finishjoin.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:meta/meta.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'exceptions.dart';

mixin GameCmdMix on Command {
  ArgParser getGameBaseParser() {
    var parser = ArgParser();
    parser.addOption('gci');
    return parser;
  }

  Message get message;

  TelegramEx get telegram;

  List<LitGameState> get worksAtStates;

  int get triggeredById {
    final id = message.from?.id;
    if (id == null) {
      throw 'message.from.id is null!';
    }
    return id;
  }

  LitGame? _foundInPM;

  LitGame get game {
    final gci = findGameIdByArguments();
    if (gci != null) {
      var game = LitGame.find(gci);
      if (game != null) return game;
    }
    if (_foundInPM != null) {
      return _foundInPM!;
    }

    throw GameNotFoundException('В этом чате не играется ни одна игра');
  }

  /// Найдёт игру, даже если команда запущена в личных сообщениях, и всё,
  /// что у нас есть - это идентификатор пользователя, отправившего сообщение.
  Future<LitGame?> findGameEveryWhere() async {
    LitGame? _g;
    try {
      _g = game;
    } catch (_) {
      if (message.chat.type == 'private') {
        final from = message.from;
        if (from == null) {
          return null;
        }
        final gameId = await client.findGameOfPlayer(from.id.toString());
        try {
          _g = LitGame.find(convertId(gameId));
        } catch (_) {
          return null;
        }
      }
    }
    return _g;
  }

  @protected
  int? findGameIdByArguments() => (arguments?['gci'] is String)
      ? int.parse(arguments?['gci'])
      : arguments?['gci'];

  void reportError(int chatId, String errorDescription) {
    catchAsyncError(telegram.sendMessage(chatId, errorDescription));
  }

  bool checkState() {
    try {
      if (worksAtStates.isEmpty) return true;
      if (worksAtStates.contains(game.state)) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  GameClient get client {
    if (BotApp.client == null) throw "Client not configured!";
    return BotApp.client as GameClient;
  }

  int convertId(String idFromClient) {
    final strId = idFromClient.replaceFirst(APP_PREFIX, '');
    return int.parse(strId);
  }

  dynamic runCheckedState(Message message, TelegramEx telegram);
}

abstract class GameCommand extends Command
    with GameCmdMix
    implements GameCmdMix {
  late Message message;
  late TelegramEx telegram;

  @override
  void run(Message message, TelegramEx telegram) async {
    this.message = message;
    this.telegram = telegram;

    if (findGameIdByArguments() == null) {
      arguments = getGameBaseParser()
          .parse(['cmd', '--gci', message.chat.id.toString()]);
    }

    try {
      game;
    } on GameNotFoundException catch (_) {
      if (message.chat.type == 'private') {
        _foundInPM = await findGameEveryWhere();
      }
    } catch (exception) {
      reportError(message.chat.id, exception.toString());
    }

    try {
      if (!checkState()) {
        reportError(message.chat.id, 'Invalid state ${game.state.toString()}');
      } else {
        final future = runCheckedState(message, telegram);
        if (future is Future) {
          catchAsyncError(future);
        }
      }
    } catch (error) {
      reportError(message.chat.id, error.toString());
    }
  }
}

abstract class ComplexGameCommand extends ComplexCommand
    with GameCmdMix
    implements GameCmdMix {
  @override
  void run(Message message, TelegramEx telegram,
      {bool stateCheck: true}) async {
    if (findGameIdByArguments() == null) {
      arguments = getGameBaseParser()
          .parse(['cmd', '--gci', message.chat.id.toString()]);
    }

    try {
      this.message = message;
      this.telegram = telegram;
      game;
    } on GameNotFoundException catch (_) {
      if (message.chat.type == 'private') {
        _foundInPM = await findGameEveryWhere();
      }
    } catch (exception) {
      reportError(message.chat.id, exception.toString());
    }

    try {
      if (stateCheck && !checkState()) {
        reportError(message.chat.id, 'Invalid state ${game.state.toString()}');
        return;
      }
      super.run(message, telegram);
    } catch (error) {
      reportError(message.chat.id, error.toString());
    }
  }

  @override
  void runCheckedState(Message message, TelegramEx telegram) {}

  @override
  String buildAction(String actionName, [Map<String, String>? parameters]) {
    parameters ??= {};
    if (parameters['gci'] == null) {
      parameters['gci'] = game.id.toString();
    }
    return super.buildAction(actionName, parameters);
  }
}

mixin ImageSender on ComplexCommand {
  @protected
  Future sendImage(int chatId, String url, String caption, LitGame game,
      [bool clear = true]) {
    return catchAsyncError(
        telegram.sendPhoto(chatId, url, caption: caption).then((msg) {
      if (clear) {
        scheduleMessageDelete(msg.chat.id, msg.message_id,
            tag: 'game-${game.id}');
      }
    }));
  }
}

mixin EndTurn on ComplexCommand {
  @protected
  void sendEndTurn(LitGame game) {
    catchAsyncError(telegram
        .sendMessage(game.id, 'Когда закончишь свою историю - жми:',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: [
              [
                InlineKeyboardButton(
                    text: 'Завершить ход',
                    callback_data: buildAction('next-turn'))
              ]
            ]))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id,
          tag: 'game-${game.id}');
    }));
  }
}

mixin JoinKickStatistics on GameCommand {
  @protected
  void sendStatisticsToAdmin(
      LitGame game, TelegramEx telegram, int gameChatId) {
    try {
      var text = '*В игре примут участие:*\r\n';
      var markup;
      if (game.players.isEmpty) {
        text = '*что-то все расхотели играть*';
        markup = ReplyMarkup();
      } else {
        for (var user in game.players.values) {
          text += ' - ' + user.nickname + ' (' + user.fullName + ')\r\n';
        }
        markup = InlineKeyboardMarkup(inline_keyboard: [
          [
            InlineKeyboardButton(
                text: 'Завершить набор игроков',
                callback_data: FinishJoinCmd()
                    .buildCommandCall({'gci': gameChatId.toString()}))
          ]
        ]);

        catchAsyncError(telegram
            .sendMessage(game.admin.id, text.escapeMarkdownV2(),
                parse_mode: 'MarkdownV2', reply_markup: markup)
            .then((message) {
          scheduleMessageDelete(message.chat.id, message.message_id,
              tag: 'game-${game.id}');
        }));
      }
    } catch (error) {
      reportError(gameChatId, error.toString());
    }
  }
}
