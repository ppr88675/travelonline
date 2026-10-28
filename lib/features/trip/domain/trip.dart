import 'package:isar/isar.dart';

part 'trip.g.dart';

@collection
class Trip {
  Id id = Isar.autoIncrement;

  /// 旅程名稱 (例如: "2026 東京賞櫻 6 日遊")
  late String title;

  /// 目的地
  late String destination;

  /// 開始與結束日期
  late DateTime startDate;
  late DateTime endDate;

  /// 建立時間戳記
  late DateTime createdAt;

  /// 備註說明
  String? description;
}
