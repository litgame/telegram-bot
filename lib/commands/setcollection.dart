import 'package:args/args.dart';
import 'package:litgame_telegram_bot/commands/endgame.dart';
import 'package:litgame_telegram_bot/commands/trainingflow.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'core/game_command.dart';

class SetCollectionCmd extends ComplexGameCommand {
  SetCollectionCmd();

  @override
  Map<String, CmdAction> get actionMap =>
      {'list': onCollectionList, 'select': onCollectionSelect};

  @override
  ArgParser getParser() => super.getParser()
    ..addOption('gci')
    ..addOption('cid');

  @override
  bool get system => true;

  @override
  String get name => 'scl';

  void onCollectionSelect(Message message, TelegramEx telegram) {
    final collectionName = arguments?['cid'];
    _startGameWithCollection(collectionName);
  }

  void onCollectionList(Message message, TelegramEx telegram) async {
    final collections = await client.collections;
    if (collections.isEmpty) {
      _resumeGameWithError(message, telegram);
      return;
    }

    if (collections.length == 1) {
      _startGameWithCollection(collections.first.name);
      return;
    }

    var collectionButtons = <List<InlineKeyboardButton>>[];
    for (var item in collections) {
      if (item.objectId == null) continue;
      collectionButtons.add([
        InlineKeyboardButton(
            text: item.name,
            callback_data:
                buildAction('select', {'cid': item.objectId as String}))
      ]);
    }

    catchAsyncError(telegram.sendMessage(
        game.master.id, 'Выбери коллекцию карт для игры',
        reply_markup:
            InlineKeyboardMarkup(inline_keyboard: collectionButtons)));
  }

  void _resumeGameWithError(Message message, TelegramEx telegram) {
    telegram
        .sendMessage(gameChatId,
            'Не нашлось ни одной колоды карт, а без них сыграть не выйдет..')
        .then((value) {
      final cmd = Command.withArgumentsFrom(() => EndGameCmd(), this);
      if (gameChatId != null) {
        message.chat.id = gameChatId!;
        message.from!.id = game.admin.id;
        cmd.run(message, telegram);
      }
    });
  }

  void _startGameWithCollection(String id) {
    game.state = LitGameState.training;
    final cmd = ComplexCommand.withAction(() => TrainingFlowCmd(), 'start',
        asyncErrorHandler, {'gci': arguments?['gci'], 'cid': id});
    cmd.run(message, telegram);
  }

  @override
  void onNoAction(Message message, TelegramEx telegram) {
    // TODO: implement onNoAction
  }

  @override
  List<LitGameState> get worksAtStates => [LitGameState.selectCollection];
}
