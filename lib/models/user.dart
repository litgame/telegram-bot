import 'dart:collection';

import 'package:teledart/model.dart';

class LitUser {
  static late List<int> adminUsers;

  LitUser.clone()
      : telegramUser = User(id: -1, is_bot: false, first_name: 'null'),
        id = -1;

  LitUser(this.telegramUser, {this.isAdmin = false, this.isGameMaster = false})
      : id = telegramUser.id {}

  bool isGameMaster = false;
  bool isAdmin = false;
  final User telegramUser;
  int id;
  int position = -1;

  String get nickname =>
      '@' + (telegramUser.username ?? (telegramUser.first_name));

  String get fullName =>
      (telegramUser.first_name) + ' ' + (telegramUser.last_name ?? '');

  bool get noId => id < 0;

  @override
  bool operator ==(Object other) =>
      other is LitUser && other.telegramUser.id == telegramUser.id;
}

class LinkedUser extends LinkedListEntry<LinkedUser> {
  LinkedUser(this.user);

  final LitUser user;
}
