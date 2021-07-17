import 'dart:async';
import 'dart:collection';

import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:teledart/model.dart';

const PARSE_CLASSNAME = 'TelegramLitUser';

class LitUser extends ParseObject implements ParseCloneable {
  static late List<int> adminUsers;
  static final Map<int, Map<String, dynamic>> _usersDataCache = {};

  LitUser.clone()
      : telegramUser = User(id: -1, is_bot: false, first_name: 'null'),
        id = -1,
        super(PARSE_CLASSNAME);

  LitUser.byId(int userId)
      : id = userId,
        telegramUser = User(id: userId, is_bot: false, first_name: 'null'),
        super(PARSE_CLASSNAME) {
    telegramUser.id = userId;
    registrationChecked = _findInStorage();
    this['userId'] = id;
  }

  @override
  LitUser clone(Map<String, dynamic> map) => LitUser.clone()..fromJson(map);

  LitUser(this.telegramUser, {this.isAdmin = false, this.isGameMaster = false})
      : id = telegramUser.id,
        super(PARSE_CLASSNAME) {
    if (!noId) {
      registrationChecked = _findInStorage();
      this['userId'] = id;
    }
  }

  late Future<bool> registrationChecked;
  bool isGameMaster = false;
  bool isAdmin = false;
  final User telegramUser;
  int id;

  String get nickname =>
      '@' + (telegramUser.username ?? (telegramUser.first_name));

  String get fullName =>
      (telegramUser.first_name) + ' ' + (telegramUser.last_name ?? '');

  bool get noId => id < 0;

  @override
  bool operator ==(Object other) =>
      other is LitUser && other.telegramUser.id == telegramUser.id;

  Future<ParseResponse> allowAddCollection(bool allow) {
    this['allowAddCollection'] = allow;
    return save();
  }

  @override
  Future<ParseResponse> save() {
    // final redis = Redis();
    // redis.init.then((_) {
    //   redis.commands.set('telegram-id-$id', toRedis());
    // });
    return super.save();
  }

  bool get isAllowedAddCollection => this['allowAddCollection'] ?? false;

  Future<bool> _findInStorage() async {
    var found = false;
    found = await _findInMemory();
    if (!found) {
      // found = await _findInRedis();
      if (!found) {
        found = await _findInParse();
      }
    }
    return found;
  }

  Future<bool> _findInMemory() {
    final searchFinished = Completer<bool>();
    final userData = _usersDataCache[id];
    if (userData == null) {
      searchFinished.complete(false);
      return searchFinished.future;
    }
    this['objectId'] = userData['objectId'] ?? -1;
    this['allowAddCollection'] = userData['allowAddCollection'] ?? false;
    if (this['allowAddCollection'] is String) {
      this['allowAddCollection'] =
          this['allowAddCollection'] == 'true' ? true : false;
    }
    searchFinished.complete(true);
    return searchFinished.future;
  }

  void _saveToMemory() {
    if (_usersDataCache.length > 10000) {
      var keysToDelete = <int>[];
      _usersDataCache.forEach((key, value) {
        final ts = value['ts'] as DateTime;
        if (DateTime.now().difference(ts).inDays > 10) {
          keysToDelete.add(key);
        }
      });
      keysToDelete.forEach((element) {
        _usersDataCache.remove(element);
      });
    }

    _usersDataCache[id] = {
      'allowAddCollection': this['allowAddCollection'] ?? false.toString(),
      'objectId': this['objectId'] ?? (-1).toString(),
      'ts': DateTime.now()
    };
  }

  // Future<bool> _findInRedis() {
  //   final redis = Redis();
  //   final searchFinished = Completer<bool>();
  //   var timeout = false;
  //   redis.init.then((_) {
  //     redis.commands.get('telegram-id-' + id.toString()).then((value) {
  //       if (value == null || timeout) {
  //         if (!searchFinished.isCompleted) {
  //           searchFinished.complete(false);
  //         }
  //         return;
  //       }
  //       fromRedis(value);
  //       _saveToMemory();
  //       if (!searchFinished.isCompleted) {
  //         searchFinished.complete(true);
  //       }
  //     });
  //   });
  //   Future.delayed(Duration(milliseconds: 10)).then((_) {
  //     if (!searchFinished.isCompleted) {
  //       searchFinished.complete(false);
  //     }
  //     timeout = true;
  //   });
  //   return searchFinished.future;
  // }

  // void _saveToRedis() {
  //   final redis = Redis();
  //   redis.init.then((_) {
  //     redis.commands.set('id-$id', toRedis());
  //   });
  // }

  Future<bool> _findInParse() {
    final builder = QueryBuilder<LitUser>(LitUser.clone())
      ..whereEqualTo('userId', id);
    return builder.query().then((ParseResponse response) {
      final results = response.results;
      if (results == null) return false;
      if (results.isNotEmpty) {
        this['objectId'] = results.first['objectId'];
        this['allowAddCollection'] = results.first['allowAddCollection'];
        _saveToMemory();
        // _saveToRedis();
        return true;
      }
      return false;
    });
  }

  // String toRedis() {
  //   final _json = <String, String>{};
  //   _json['objectId'] = this['objectId'] ?? (-1).toString();
  //   _json['allowAddCollection'] =
  //       (this['allowAddCollection'] ?? false).toString();
  //   return jsonEncode(_json);
  // }

  // void fromRedis(String value) {
  //   final _json = jsonDecode(value);
  //   this['objectId'] = _json['objectId'] ?? -1;
  //   this['allowAddCollection'] = _json['allowAddCollection'] ?? false;
  // }
}

class LinkedUser extends LinkedListEntry<LinkedUser> {
  LinkedUser(this.user);

  final LitUser user;
}
