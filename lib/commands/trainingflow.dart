import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_client/models/card.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';
import 'gameflow.dart';

class TrainingFlowCmd extends ComplexGameCommand with ImageSender, EndTurn {
  TrainingFlowCmd();

  @override
  bool get system => true;

  @override
  ArgParser getParser() => super.getParser()
    ..addOption('gci')
    ..addOption('cid');

  @override
  List<LitGameState> get worksAtStates => [LitGameState.training];

  @override
  Map<String, CmdAction> get actionMap => {
        'start': onTrainingStart,
        'next-turn': onNextTurn,
        'skip': onSkip,
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
    try {
      await client.startTrainingFlow(
          game.id.toString(), triggeredById.toString(),
          collectionId: arguments?['cid']);
    } on ValidationException catch (error) {
      if (error.type == ErrorType.access) {
        reportError(triggeredById, error.message);
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
  }

  void onNextTurn(Message message, TelegramEx telegram) async {
    try {
      final playerCard = await client.trainingFlowNextTurn(
          game.id.toString(), triggeredById.toString());
      deleteScheduledMessages(telegram);
      _onNextPlayer(playerCard);
    } on ValidationException catch (error) {
      if (error.type == ErrorType.access) {
        if (game.master.id == triggeredById || game.admin.id == triggeredById) {
          deleteScheduledMessages(telegram);
          onSkip(message, telegram);
        }
      } else {
        reportError(game.id, error.message);
      }
    }
  }

  void onSkip(Message message, TelegramEx telegram) async {
    try {
      final playerCard = await client.trainingFlowSkipTurn(
          game.id.toString(), triggeredById.toString());
      _onNextPlayer(playerCard);
    } on ValidationException catch (error) {
      reportError(game.id, error.message);
      return;
    }
  }

  void _onNextPlayer(Map<String, Card> playerCard) {
    final playerId = convertId(playerCard.keys.first);
    final player = game.players[playerId];
    if (player == null) {
      throw ValidationException(
          'Пользователя нет в списке игроков!', ErrorType.notFound.toString());
    }

    final card = playerCard.values.first;
    final cardMsg = card.name +
        '\r\n' +
        'Ходит ' +
        player.nickname +
        '(' +
        player.fullName +
        ')';

    sendImage(game.id, card.imgUrl, cardMsg, false).then((value) {
      sendEndTurn(game.id);
    });
  }

  void onTrainingEnd(Message message, TelegramEx telegram) async {
    const litMsg = 'Разминку закончили, все молодцы!\r\n'
        'Сейчас таки начнём играть :-)';
    final endMessageSent =
        catchAsyncError(telegram.sendMessage(game.id, litMsg));

    game.state = LitGameState.game;
    final cmd = ComplexCommand.withAction(() => GameFlowCmd(), 'start',
        asyncErrorHandler, {'gci': game.id.toString()});
    endMessageSent.then((value) {
      cmd.run(message, telegram);
    });
  }
}
