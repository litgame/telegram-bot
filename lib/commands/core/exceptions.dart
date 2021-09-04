class GameNotFoundException implements Exception {
  GameNotFoundException(this.message);

  String message;

  String toString() => message;
}
