class KickRequest {
  factory KickRequest.createOrGet(int gameId, int triggeredById, int targetUserId) {
    final existing = _activeRequests[triggeredById];
    if (existing != null) {
      return existing;
    }
    final newRequest = KickRequest._(gameId, triggeredById, targetUserId);
    _activeRequests[triggeredById] = newRequest;
    return newRequest;
  }

  KickRequest._(this.gameId, this.triggeredById, this.targetUserId);

  KickRequest(this.gameId, this.triggeredById, this.targetUserId) {}

  static final Map<int, KickRequest> _activeRequests = {};

  int gameId;
  int triggeredById;
  int targetUserId;
  int? newMasterId;
  int? newAdminId;

  void delete() {
    _activeRequests.remove(triggeredById);
  }
}
