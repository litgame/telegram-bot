import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_client/models/card.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';

class GameFlowCmd extends ComplexGameCommand with ImageSender, EndTurn {
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
        'skip': onSkip,
      };

  void onGameStart(Message message, TelegramEx telegram) async {
    try {
      final masterCards = await client.startGameFlow(
          game.id.toString(), triggeredById.toString());

      await catchAsyncError(telegram.sendMessage(game.id,
          'Ходит ' + game.master.nickname + '(' + game.master.fullName + ')'));

      for (var card in masterCards) {
        await sendImage(game.id, card.imgUrl, card.name, false);
      }

      if (masterCards.length < 3) {
        print(
            'DEBUG: master cards length is ${masterCards.length} instead of 3!!!');
      }
      sendEndTurn(game.id);
    } on ValidationException catch (error) {
      reportError(game.id, error.message);
      return;
    }
  }

  void onNextTurn(Message message, TelegramEx telegram) async {
    try {
      final playerStringId = await client.gameFlowNextTurn(
          game.id.toString(), triggeredById.toString());
      deleteScheduledMessages(telegram);
      _onNextPlayer(playerStringId);
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
      final playerStringId = await client.gameFlowSkipTurn(
          game.id.toString(), triggeredById.toString());
      _onNextPlayer(playerStringId);
    } on ValidationException catch (error) {
      reportError(game.id, error.message);
    }
  }

  void _onNextPlayer(String playerStringId) async {
    final player = game.players[convertId(playerStringId)];
    if (player == null) {
      throw ValidationException(
          'Пользователя нет в списке игроков!', ErrorType.notFound.toString());
    }
    await catchAsyncError(telegram.sendMessage(
        game.id, 'Ходит ' + player.nickname + '(' + player.fullName + ')'));

    catchAsyncError(telegram
        .sendMessage(game.id, 'Тянем карту!',
            reply_markup: InlineKeyboardMarkup(inline_keyboard: [
              [
                InlineKeyboardButton(
                    text: 'Общая',
                    callback_data: buildAction('select-generic')),
                InlineKeyboardButton(
                    text: 'Место', callback_data: buildAction('select-place')),
                InlineKeyboardButton(
                    text: 'Персонаж',
                    callback_data: buildAction('select-person')),
              ]
            ]))
        .then((msg) {
      scheduleMessageDelete(msg.chat.id, msg.message_id);
    }));
  }

  void onSelectCard(Message message, TelegramEx telegram) async {
    try {
      var sType = action.replaceAll('select-', '');
      var type = CardType.generic.getTypeByName(sType);

      final card = await client.gameFlowSelectCard(
          game.id.toString(), triggeredById.toString(), type);
      deleteScheduledMessages(telegram);

      await sendImage(game.id, card.imgUrl, card.name, false);
      sendEndTurn(game.id);
    } on ValidationException catch (error) {
      if (error.type != ErrorType.access) {
        reportError(game.id, error.message);
      }
    }
  }

  @override
  void onNoAction(Message message, TelegramEx telegram) {}
}
