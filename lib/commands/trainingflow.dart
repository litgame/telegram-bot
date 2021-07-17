import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import '../botapp.dart';
import 'game_command.dart';
import 'gameflow.dart';

class TrainingFlowCmd extends ComplexGameCommand
    with ImageSender, EndTurn, CopyChat {
  TrainingFlowCmd();

  @override
  bool get system => true;

  @override
  ArgParser getParser() =>
      super.getParser()..addOption('gci')..addOption('cid');

  @override
  List<LitGameState> get worksAtStates => [LitGameState.training];

  @override
  Map<String, CmdAction> get actionMap => {
        'start': onTrainingStart,
        'next-turn': onNextTurn,
        'end': onTrainingEnd,
      };

  @override
  String get name => 'tf';
  bool firstStep = false;

  @override
  void onNoAction(Message message, TelegramEx telegram) {
    // TODO: implement onNoAction
  }

  void onTrainingStart(Message message, TelegramEx telegram) async {
    final id = message.from?.id;
    if (id == null) {
      throw 'message.from.id is null!';
    }
    try {
      await client.startTrainingFlow(game.id.toString(), id.toString(),
          collectionId: arguments?['cid']);
    } on ValidationException catch (error) {
      if (error.type == ErrorType.access) {
        reportError(id, error.message);
        return;
      } else {
        rethrow;
      }
    }

    const litMsg = 'Небольшая разминка!\r\n'
        'Сейчас каждому из игроков будет выдаваться случайная карта из колоды,'
        'и нужно будет по ней рассказать что-то, что связано с миром/темой, '
        'на которую вы собираетесь играть.\r\n'
        'Это позволит немного разогреть мозги, вспомнить забытые факты и "прокачать"'
        'менее подготовленных к игре товарищей.\r\n';
    catchAsyncError(telegram.sendMessage(game.id, litMsg));
    final msgToAdminIsCopied = copyChat((chatId, completer) {
      final future = catchAsyncError(telegram.sendMessage(chatId, litMsg));
      if (chatId == game.master.id) {
        future.then((value) {
          completer.complete();
        });
      }
    });

    msgToAdminIsCopied.then((value) {
      catchAsyncError(telegram.sendMessage(
          game.master.id, 'Когда решишь, что разминки хватит - жми сюда!',
          reply_markup: InlineKeyboardMarkup(inline_keyboard: [
            [
              InlineKeyboardButton(
                  text: 'Завершить разминку', callback_data: buildAction('end'))
            ]
          ])));
      firstStep = true;
      onNextTurn(message, telegram);
    });
  }

  void onNextTurn(Message message, TelegramEx telegram) async {
    final id = message.from?.id;
    if (id == null) {
      throw 'message.from.id is null!';
    }
    try {
      final playerCard =
          await client.trainingFlowNextTurn(game.id.toString(), id.toString());
      final playerId =
          int.parse(playerCard.keys.first.replaceFirst(APP_PREFIX, ''));
      final player = game.players[playerId];
      if (player == null) {
        throw ValidationException('Пользователя нет в списке игроков!',
            ErrorType.notFound.toString());
      }

      final card = playerCard.values.first;
      final cardMsg = card.name +
          '\r\n' +
          'Ходит ' +
          player.nickname +
          '(' +
          player.fullName +
          ')';

      sendImage(game.id, card.imgUrl, cardMsg, false);
      copyChat((chatId, _) {
        if (player.id == chatId) return;
        sendImage(chatId, card.imgUrl, cardMsg, false);
      });

      sendImage(player.id, card.imgUrl, card.name, false).then((value) {
        sendEndTurn(player.id);
      });
    } on ValidationException catch (error) {
      if (error.type == ErrorType.state) {
        reportError(game.id, error.message);
        return;
      } else if (error.type == ErrorType.validation) {
        reportError(game.id, error.message);
        return;
      } else if (error.type == ErrorType.notFound) {
        reportError(game.id, error.message);
        return;
      } else {
        rethrow;
      }
    }
  }

  void onTrainingEnd(Message message, TelegramEx telegram) async {
    const litMsg = 'Разминку закончили, все молодцы!\r\n'
        'Сейчас таки начнём играть :-)';
    final endMessageSent =
        catchAsyncError(telegram.sendMessage(game.id, litMsg));
    copyChat((chatId, _) {
      catchAsyncError(telegram.sendMessage(chatId, litMsg));
    });

    game.state = LitGameState.game;
    final cmd = ComplexCommand.withAction(
        () => GameFlowCmd(), 'start', {'gci': game.id.toString()});
    endMessageSent.then((value) {
      cmd.run(message, telegram);
    });
  }
}
