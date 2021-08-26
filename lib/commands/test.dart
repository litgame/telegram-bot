import 'dart:io';

import 'package:args/args.dart';
import 'package:litgame_telegram_bot/commands/core/game_command.dart';
import 'package:litgame_telegram_bot/commands/finishjoin.dart';
import 'package:litgame_telegram_bot/commands/joinme.dart';
import 'package:litgame_telegram_bot/commands/kick.dart';
import 'package:litgame_telegram_bot/commands/setcollection.dart';
import 'package:litgame_telegram_bot/commands/setorder.dart';
import 'package:litgame_telegram_bot/commands/startgame.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:teledart/src/telegram/model.dart';
import 'package:teledart_app/src/application/application.dart';
import 'package:teledart_app/src/complex_command.dart';

import 'setmaster.dart';

class TestCmd extends ComplexGameCommand {
  @override
  Map<String, CmdAction> get actionMap => {};

  @override
  bool get system => false;

  ArgParser getParser() => super.getParser()
    ..addOption('gci')
    ..addOption('uid')
    ..addOption('mode');

  @override
  String get name => 'test';

  int get testUserId => _getEnvInt('TEST_USER_ID');
  int get testUserId2 => _getEnvInt('TEST_USER_ID2');
  int get delay => _getEnvInt('TEST_DELAY');
  String get testCollection => _getEnvStr('TEST_COLLECTION_ID');

  String _getEnvStr(String name) => Platform.environment[name] ?? '';
  int _getEnvInt(String name) {
    final strId = Platform.environment[name];
    if (strId == null) return 0;
    try {
      return int.parse(strId);
    } catch (e) {
      return 0;
    }
  }

  @override
  void onNoAction(Message message, TelegramEx telegram) async {
    print('!!! /startgame');
    final startgame =
        Command.withArguments(() => StartGameCmd(), {}, asyncErrorHandler);
    await startgame.runWithErrorHandler(message, telegram);

    await Future.delayed(Duration(seconds: delay));

    final basicArgs = {'gci': message.chat.id.toString()};
    final game = LitGame.find(message.chat.id);

    if (game == null) {
      print('!!! kill.');
      return;
    }

    print('!!! /joinme');

    final join = Command.withArguments(
        () => JoinMeCmd(triggeredByAlternative: testUserId),
        basicArgs,
        asyncErrorHandler);
    await join.runWithErrorHandler(message, telegram);

    final join2 = Command.withArguments(
        () => JoinMeCmd(triggeredByAlternative: testUserId2),
        basicArgs,
        asyncErrorHandler);
    await join2.runWithErrorHandler(message, telegram);

    await Future.delayed(Duration(seconds: delay));

    print('!!! /finishjoin');

    final finishjoin = Command.withArguments(
        () => FinishJoinCmd(), basicArgs, asyncErrorHandler);
    await finishjoin.runWithErrorHandler(message, telegram);
    await Future.delayed(Duration(seconds: delay));

    print('!!! /setmaster');

    final setmaster = Command.withArguments(
        () => SetMasterCmd(),
        {
          'gci': message.chat.id.toString(),
          'userId': message.from!.id.toString()
        },
        asyncErrorHandler);
    await setmaster.runWithErrorHandler(message, telegram);
    await Future.delayed(Duration(seconds: delay));

    print('!!! /setorder (start)');

    var setorder = Command.withArguments(
        () => SetOrderCmd(),
        {
          'gci': message.chat.id.toString(),
          'userId': message.from!.id.toString(),
          'reset': ''
        },
        asyncErrorHandler);
    await setorder.runWithErrorHandler(message, telegram);
    await Future.delayed(Duration(seconds: delay));

    print('!!! /setorder (sort)');

    setorder = Command.withArguments(
        () => SetOrderCmd(),
        {'gci': message.chat.id.toString(), 'userId': testUserId.toString()},
        asyncErrorHandler);

    await setorder.runWithErrorHandler(message, telegram);
    await Future.delayed(Duration(seconds: delay));

    setorder = Command.withArguments(
        () => SetOrderCmd(),
        {'gci': message.chat.id.toString(), 'userId': testUserId2.toString()},
        asyncErrorHandler);

    await setorder.runWithErrorHandler(message, telegram);
    await Future.delayed(Duration(seconds: delay));

    print('!!! /setorder (finish)');

    setorder = Command.withArguments(() => SetOrderCmd(),
        {'gci': message.chat.id.toString(), 'finish': ''}, asyncErrorHandler);

    await setorder.runWithErrorHandler(message, telegram);
    await Future.delayed(Duration(seconds: delay));

    print('!!! /setcollection');

    final setcollection = ComplexCommand.withAction(
        () => SetCollectionCmd(),
        'select',
        asyncErrorHandler,
        {'gci': message.chat.id.toString(), 'cid': testCollection});
    await setcollection.runWithErrorHandler(message, telegram);

    await Future.delayed(Duration(seconds: 4));

    print('!!! /kick');

    var kick = Command.withArguments(() => KickCmd(),
        {'gci': message.chat.id.toString()}, asyncErrorHandler);
    await kick.runWithErrorHandler(message, telegram);

    /* await Future.delayed(Duration(minutes: 5));

    print('!!! /endgame');

    var endgame = Command.withArguments(() => EndGameCmd(),
        {'gci': message.chat.id.toString()}, asyncErrorHandler);
    await endgame.runWithErrorHandler(message, telegram);
    await Future.delayed(Duration(seconds: delay));*/
  }

  @override
  List<LitGameState> get worksAtStates => [];
}
