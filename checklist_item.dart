import 'package:isar/isar.dart';

part 'checklist_item.g.dart';

@collection
class ChecklistItem {
  Id id = Isar.autoIncrement;

  /// 所屬 Trip ID
  @Index()
  late int tripId;

  /// 物品名稱 (例如: "萬國轉接頭", "行動電源", "護照")
  late String name;

  /// 分組類別 (例如: "基本證件", "3C配件", "個人藥品", "衣物服飾")
  @Index()
  late String groupName;

  /// 是否已完成打包
  late bool isPacked;
}