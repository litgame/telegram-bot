import 'dart:async';

import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/botapp.dart';
import 'package:litgame_telegram_bot/commands/finishjoin.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:meta/meta.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

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

  LitGame get game {
    final gci = gameChatId;
    if (gci == null) throw 'В этом чате не играется ни одна игра';
    var game = LitGame.find(gci);
    if (game == null) throw 'В этом чате не играется ни одна игра';
    return game;
  }

  int? get gameChatId => (arguments?['gci'] is String)
      ? int.parse(arguments?['gci'])
      : arguments?['gci'];

  @protected
  void checkGameChat(Message message) {
    if (message.chat.id > 0) {
      throw 'Эту команду надо не в личке запускать, а в чате с игроками ;-)';
    }
  }

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

  void runCheckedState(Message message, TelegramEx telegram);
}

mixin LitGameClient on Command {
  GameClient get client {
    if (BotApp.client == null) throw "Client not configured!";
    return BotApp.client as GameClient;
  }

  int convertId(String idFromClient) {
    final strId = idFromClient.replaceFirst(APP_PREFIX, '');
    return int.parse(strId);
  }
}

abstract class GameCommand extends Command
    with GameCmdMix, LitGameClient
    implements GameCmdMix {
  late Message message;
  late TelegramEx telegram;

  @override
  void run(Message message, TelegramEx telegram) {
    this.message = message;
    this.telegram = telegram;
    try {
      if (gameChatId == null) {
        arguments = getGameBaseParser()
            .parse(['cmd', '--gci', message.chat.id.toString()]);
      }
      if (!checkState()) {
        reportError(message.chat.id, 'Invalid state ${game.state.toString()}');
      } else {
        runCheckedState(message, telegram);
      }
    } catch (error) {
      reportError(message.chat.id, error.toString());
    }
  }
}

abstract class ComplexGameCommand extends ComplexCommand
    with GameCmdMix, LitGameClient
    implements GameCmdMix {
  @override
  void run(Message message, TelegramEx telegram, {bool stateCheck: true}) {
    try {
      if (gameChatId == null) {
        arguments = getGameBaseParser()
            .parse(['cmd', '--gci', message.chat.id.toString()]);
      }
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
      parameters['gci'] = gameChatId.toString();
    }
    return super.buildAction(actionName, parameters);
  }
}

mixin ImageSender on ComplexCommand {
  @protected
  Future sendImage(int chatId, String url, String caption,
      [bool clear = true]) {
    return catchAsyncError(
        telegram.sendPhoto(chatId, url, caption: caption).then((msg) {
      if (clear) {
        scheduleMessageDelete(msg.chat.id, msg.message_id);
      }
    }));
  }
}

mixin EndTurn on ComplexCommand {
  @protected
  void sendEndTurn(int playerChatId) {
    catchAsyncError(telegram
        .sendMessage(playerChatId, 'Когда закончишь свою историю - жми:',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: [
              [
                InlineKeyboardButton(
                    text: 'Завершить ход',
                    callback_data: buildAction('next-turn'))
              ]
            ]))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id);
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
          scheduleMessageDelete(message.chat.id, message.message_id);
        }));
      }
    } catch (error) {
      reportError(gameChatId, error.toString());
    }
  }
}
