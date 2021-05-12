import 'package:litgame_telegram_bot/botapp.dart';

Future main(List<String> arguments) async {
  final app = BotApp(BotAppConfig(arguments));
  app.run();
}
