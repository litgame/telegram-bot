import 'package:litgame_telegram_bot/models/user.dart';

enum LitGameState {
  stop,
  join,
  selectMaster,
  sorting,
  selectCollection,
  training,
  game,
  paused
}

class LitGame {
  static final Map<int, LitGame> _activeGames = {};
  final int id;
  final Map<int, LitUser> players = {};
  LitGameState state = LitGameState.join;

  factory LitGame.startNew(int gameId) {
    // if (_activeGames[gameId] != null) {
    //   throw 'Game already exists!';
    // }
    final game = LitGame._(gameId);
    _activeGames[gameId] = game;
    return game;
  }

  LitGame._(this.id);

  static LitGame? find(int gameId) {
    return _activeGames[gameId];
  }

  LitUser get master {
    for (var u in players.values) {
      if (u.isGameMaster) return u;
    }
    throw 'No master added';
  }

  LitUser get admin {
    for (var u in players.values) {
      if (u.isAdmin) return u;
    }
    return master;
  }

  void stop() {
    state = LitGameState.stop;
    if (_activeGames[id] != null) {
      _activeGames.remove(id);
    }
  }
}
