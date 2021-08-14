import 'dart:io';

import 'package:args/args.dart';
import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/commands/skip.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:teledart/model.dart';
import 'package:teledart_app/teledart_app.dart';

import 'commands/endgame.dart';
import 'commands/finishjoin.dart';
import 'commands/gameflow.dart';
import 'commands/help.dart';
import 'commands/joinme.dart';
import 'commands/kickme.dart';
import 'commands/setcollection.dart';
import 'commands/setmaster.dart';
import 'commands/setorder.dart';
import 'commands/startgame.dart';
import 'commands/trainingflow.dart';
import 'middleware/logger.dart';
import 'models/user.dart';

const APP_PREFIX = 'telegram-';

class BotApp extends TeledartApp {
  BotApp(this._conf) : super(_conf.botKey) {
    client = GameClient(_conf.gameServerUrl as String, APP_PREFIX);
  }

  final BotAppConfig _conf;
  static GameClient? client;

  @override
  List<CommandConstructor> commands = [
    () => StartGameCmd(),
    () => EndGameCmd(),
    () => StopGameCmd(),
    () => JoinMeCmd(),
    () => KickMeCmd(),
    () => FinishJoinCmd(),
    () => SetMasterCmd(),
    () => SetOrderCmd(),
    () => SetCollectionCmd(),
    () => TrainingFlowCmd(),
    () => GameFlowCmd(),
    () => SkipCmd(),
    // () => AddCollectionCmd(),
    // () => DelCollectionCmd(),
    () => HelpCmd(),
  ];

  @override
  List<MiddlewareConstructor> middleware = [
    () => ComplexCommand.withAction(
            () => HelpCmd(), 'firstRun', (exception, _, __) => print(exception))
        as Middleware,
    () => Logger(),
  ];

  @override
  void onError(Object exception, dynamic trace, dynamic data) {
    print('=== EXCEPTION! ===');
    print(exception);
    if (data is Update) {
      var chatId =
          data.message?.chat.id ?? data.callback_query?.message?.chat.id;
      if (exception is FatalException || exception is ValidationException) {
        telegram
            .sendMessage(chatId, 'Rest server error: ' + exception.toString())
            .catchError((error) {
          print(error.toString());
        });
      } else {
        telegram.sendMessage(chatId, exception.toString()).catchError((error) {
          print(error.toString());
        });
      }
    }
    print(trace);
    print('==================');
  }

  @override
  void run() async {
    await Parse().initialize(
      _conf.dataAppKey!,
      _conf.dataAppUrl!,
      masterKey: _conf.parseMasterKey,
      clientKey: _conf.parseRestKey,
      debug: true,
      registeredSubClassMap: <String, ParseObjectConstructor>{
        'LitUsers': () => LitUser.clone(),
      },
    );

    super.run();
  }
}

class BotAppConfig {
  BotAppConfig(this.arguments) {
    var successSetup = _setupFromCliArguments();
    if (!successSetup) {
      successSetup = _setupFromEnv();
    }

    if (botKey == null) {
      successSetup = false;
    }
    if (!successSetup) {
      print('Cant setup bot properly.');
      exit(1);
    }
    print('Setup finished successfully!');
  }

  late String botKey;
  String? dataAppUrl;
  String? dataAppKey;
  String? parseMasterKey;
  String? parseRestKey;
  String? gameServerUrl;

  List<String> arguments;

  bool _setupFromCliArguments() {
    if (arguments.isEmpty) {
      return false;
    }
    final parser = ArgParser();
    parser.addOption('botKey', abbr: 'k');
    parser.addOption('dataAppUrl', abbr: 'u');
    parser.addOption('dataAppKey', abbr: 'a');
    parser.addOption('adminUserIds', abbr: 'i');
    parser.addOption('parseMasterKey', abbr: 'm');
    parser.addOption('parseRestKey', abbr: 'r');
    parser.addOption('gameServerUrl', abbr: 's');
    try {
      final results = parser.parse(arguments);
      botKey = results['botKey'];
      dataAppUrl = results['dataAppUrl'];
      dataAppKey = results['dataAppKey'];
      parseMasterKey = results['parseMasterKey'];
      parseRestKey = results['parseRestKey'];
      gameServerUrl = results['gameServerUrl'];
      LitUser.adminUsers = results['adminUserIds']
          .toString()
          .split(',')
          .map((e) => int.parse(e.trim()))
          .toList();
    } on ArgumentError {
      print('Missing CLI arguments');
      print(arguments);
      return false;
    } on ArgParserException {
      print('Missing CLI arguments');
      print(arguments);
      return false;
    }
    return true;
  }

  bool _setupFromEnv() {
    final envVars = Platform.environment;
    //damn null safety!
    final _botKey = envVars['BOT_TELEGRAM_KEY'];
    if (_botKey == null) return false;
    botKey = _botKey;

    final _dataAppUrl = envVars['BOT_PARSESERVER_URL'];
    if (_dataAppUrl == null) return false;
    dataAppUrl = _dataAppUrl;

    final _dataAppKey = envVars['BOT_PARSESERVER_APP_KEY'];
    if (_dataAppKey == null) return false;
    dataAppKey = _dataAppKey;

    final _parseMasterKey = envVars['BOT_PARSESERVER_MASTER_KEY'];
    if (_parseMasterKey == null) return false;
    parseMasterKey = _parseMasterKey;

    final _parseRestKey = envVars['BOT_PARSESERVER_REST_KEY'];
    if (_parseRestKey == null) return false;
    parseRestKey = _parseRestKey;

    final _gameServerUrl = envVars['BOT_GAME_SERVER_URL'];
    if (_gameServerUrl == null) return false;
    gameServerUrl = _gameServerUrl;

    if (envVars['BOT_ADMIN_USER_IDS'] != null) {
      LitUser.adminUsers = envVars['BOT_ADMIN_USER_IDS']
          .toString()
          .split(',')
          .map((e) => int.parse(e.trim()))
          .toList();
    }
    return true;
  }
}
