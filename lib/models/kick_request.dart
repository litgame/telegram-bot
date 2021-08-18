import 'package:litgame_telegram_bot/models/game.dart';

class KickRequest {
  factory KickRequest.create(
      int triggeredById, int gameId, LitGameState lastGameState) {
    final existing = find(triggeredById);
    if (existing != null) {
      return existing;
    }
    final newRequest = KickRequest._(gameId, triggeredById, lastGameState);

    _activeRequests[triggeredById] = newRequest;
    return newRequest;
  }

  static KickRequest? find(int triggeredById) => _activeRequests[triggeredById];

  KickRequest._(this.gameId, this.triggeredById, this.lastGameState);

  static final Map<int, KickRequest> _activeRequests = {};

  int gameId;
  int triggeredById;
  int? targetUserId;
  int? newMasterId;
  int? newAdminId;

  LitGameState lastGameState;

  void delete() {
    _activeRequests.remove(triggeredById);
  }
}
