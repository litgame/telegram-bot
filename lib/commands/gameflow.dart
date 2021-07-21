import 'dart:async';

import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_client/models/card.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import '../botapp.dart';
import 'game_command.dart';

class GameFlowCmd extends ComplexGameCommand
    with ImageSender, EndTurn, CopyChat {
  GameFlowCmd();

  @override
  ArgParser getParser() => super.getParser()..addOption('gci');

  @override
  List<LitGameState> get worksAtStates => [LitGameState.game];

  @override
  bool get system => true;

  @override
  String get name => 'gf';

  @override
  Map<String, CmdAction> get actionMap => {
        'start': onGameStart,
        'select-generic': onSelectCard,
        'select-place': onSelectCard,
        'select-person': onSelectCard,
        'next-turn': onNextTurn,
      };

  void onGameStart(Message message, TelegramEx telegram) async {
    try {
      final id = message.from?.id;
      if (id == null) {
        throw 'message.from.id is null!';
      }
      final masterCards =
          await client.startGameFlow(game.id.toString(), id.toString());

      final toMaster = catchAsyncError(telegram.sendMessage(game.master.id,
          'Ходит ' + game.master.nickname + '(' + game.master.fullName + ')'));
      final toChat = catchAsyncError(telegram.sendMessage(game.master.id,
          'Ходит ' + game.master.nickname + '(' + game.master.fullName + ')'));
      copyChat((chatId, _) {
        if (game.master.id == chatId) return;
        catchAsyncError(telegram.sendMessage(
            chatId,
            'Ходит ' +
                game.master.nickname +
                '(' +
                game.master.fullName +
                ')'));
      });

      await Future.wait([toMaster, toChat]);

      final cardToAllChats = (Card card) {
        final toGameChat = sendImage(game.id, card.imgUrl, card.name, false);
        final toMasterChat =
            sendImage(game.master.id, card.imgUrl, card.name, false);
        final toAllUsers = copyChat((chatId, completer) {
          if (game.master.id == chatId) return;
          sendImage(chatId, card.imgUrl, card.name, false).then((value) {
            completer.complete();
          });
        });

        return Future.wait([toGameChat, toMasterChat, toAllUsers]);
      };
      for (var card in masterCards) {
        await cardToAllChats(card);
      }
      sendEndTurn(game.master.id);
    } on ValidationException catch (error) {
      switch (error.type) {
        case ErrorType.validation:
          reportError(game.id, error.message);
          return;
        case ErrorType.access:
          reportError(game.id, error.message);
          return;
        case ErrorType.state:
          reportError(game.id, error.message);
          return;
        default:
          rethrow;
      }
    }
  }

  void onNextTurn(Message message, TelegramEx telegram) async {
    try {
      final id = message.from?.id;
      if (id == null) {
        throw 'message.from.id is null!';
      }
      final playerStringId =
          await client.gameFlowNextTurn(game.id.toString(), id.toString());
      final player =
          game.players[int.parse(playerStringId.replaceFirst(APP_PREFIX, ''))];
      if (player == null) {
        throw ValidationException('Пользователя нет в списке игроков!',
            ErrorType.notFound.toString());
      }
      deleteScheduledMessages(telegram);
      final toPlayer = catchAsyncError(telegram.sendMessage(
          player.id, 'Ходит ' + player.nickname + '(' + player.fullName + ')'));
      final toChat = catchAsyncError(telegram.sendMessage(
          game.id, 'Ходит ' + player.nickname + '(' + player.fullName + ')'));

      copyChat((chatId, _) {
        if (player.id == chatId) return;
        catchAsyncError(telegram.sendMessage(
            chatId, 'Ходит ' + player.nickname + '(' + player.fullName + ')'));
      });

      await Future.wait([toPlayer, toChat]);

      telegram
          .sendMessage(player.id, 'Тянем карту!',
              reply_markup: InlineKeyboardMarkup(inline_keyboard: [
                [
                  InlineKeyboardButton(
                      text: 'Общая',
                      callback_data: buildAction('select-generic')),
                  InlineKeyboardButton(
                      text: 'Место',
                      callback_data: buildAction('select-place')),
                  InlineKeyboardButton(
                      text: 'Персонаж',
                      callback_data: buildAction('select-person')),
                ]
              ]))
          .then((msg) {
        scheduleMessageDelete(msg.chat.id, msg.message_id);
      });
    } on ValidationException catch (error) {
      switch (error.type) {
        case ErrorType.validation:
          reportError(game.id, error.message);
          return;
        case ErrorType.access:
          reportError(game.id, error.message);
          return;
        case ErrorType.state:
          reportError(game.id, error.message);
          return;
        default:
          rethrow;
      }
    }
  }

  void onSelectCard(Message message, TelegramEx telegram) async {
    try {
      var sType = action.replaceAll('select-', '');
      var type = CardType.generic.getTypeByName(sType);

      final id = message.from?.id;
      if (id == null) {
        throw 'message.from.id is null!';
      }
      final card = await client.gameFlowSelectCard(
          game.id.toString(), id.toString(), type);
      deleteScheduledMessages(telegram);
      sendImage(id, card.imgUrl, card.name, false).then((value) {
        sendEndTurn(id);
      });
      sendImage(game.id, card.imgUrl, card.name, false);
      copyChat((chatId, _) {
        if (id == chatId) return;
        sendImage(chatId, card.imgUrl, card.name, false);
      });
    } on ValidationException catch (error) {
      switch (error.type) {
        case ErrorType.validation:
          reportError(game.id, error.message);
          return;
        case ErrorType.access:
          reportError(game.id, error.message);
          return;
        case ErrorType.state:
          reportError(game.id, error.message);
          return;
        default:
          rethrow;
      }
    }
  }

  @override
  void onNoAction(Message message, TelegramEx telegram) {}
}
