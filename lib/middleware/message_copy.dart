import 'package:litgame_client/client.dart';
import 'package:litgame_telegram_bot/models/game.dart';
import 'package:litgame_telegram_bot/models/user.dart';
import 'package:teledart/src/telegram/model.dart';
import 'package:teledart_app/teledart_app.dart';

import '../botapp.dart';

class MessageCopy with Middleware {
  @override
  void handle(Update data, TelegramEx telegram) {
    if (isCmd) return;
    if (isCallbackQuery) return;
    if (data.message == null) return;

    final message = data.message;
    if (message == null) return;
    if (message.chat.type == 'private') {
      final from = message.from;
      if (from == null) return;
      final user = LitUser(from);
      user.registrationChecked.then((registered) {
        _copyPMMessagesToGameChat(message, telegram);
      });
    } else {
      _copyGameChatMessagesToPM(message, telegram);
    }
  }

  void _copyPMMessagesToGameChat(Message message, TelegramEx telegram) async {
    if (BotApp.client == null) throw "Client not configured!";
    final client = BotApp.client as GameClient;
    final gameId = await client.findGameOfPlayer(message.chat.id.toString());
    if (gameId.isEmpty) return;

    final telegramGameId = int.tryParse(gameId.replaceFirst(APP_PREFIX, ''));
    if (telegramGameId == null) return;

    final game = LitGame.find(telegramGameId);
    if (game == null) return;
    telegram.forwardMessage(game.id, message.chat.id, message.message_id);
  }

  void _copyGameChatMessagesToPM(Message message, TelegramEx telegram) {
    final game = LitGame.find(message.chat.id);
    if (game == null) return;
    final fromId = message.from?.id;
    if (fromId == null || !game.players.containsKey(fromId)) return;
    for (var player in game.players.entries) {
      if (player.value.telegramUser.id == fromId) continue;

      telegram.forwardMessage(
          player.value.id, message.chat.id, message.message_id);
    }
  }
}
