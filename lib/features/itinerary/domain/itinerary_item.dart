import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'itinerary_item.g.dart';

/// 行程類別 Enum
enum ActivityCategory {
  food,         // 美食
  cafe,         // 咖啡
  sightseeing,  // 景點
  stay,         // 住宿
  transit,      // 交通
  shopping,     // 購物
}

/// 擴充 Category 的顯示標籤、顏色與圖示
extension ActivityCategoryExtension on ActivityCategory {
  String get label {
    switch (this) {
      case ActivityCategory.food:
        return '美食';
      case ActivityCategory.cafe:
        return '咖啡';
      case ActivityCategory.sightseeing:
        return '景點';
      case ActivityCategory.stay:
        return '住宿';
      case ActivityCategory.transit:
        return '交通';
      case ActivityCategory.shopping:
        return '購物';
    }
  }

  Color get color {
    switch (this) {
      case ActivityCategory.food:
        return const Color(0xFFF97316); // 橘色
      case ActivityCategory.cafe:
        return const Color(0xFF8B5CF6); // 暖紫/咖啡
      case ActivityCategory.sightseeing:
        return const Color(0xFF0EA5E9); // 蔚藍色
      case ActivityCategory.stay:
        return const Color(0xFF10B981); // 翡翠綠
      case ActivityCategory.transit:
        return const Color(0xFF64748B); // 鋼青灰
      case ActivityCategory.shopping:
        return const Color(0xFFEC4899); // 玫瑰粉
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityCategory.food:
        return Icons.restaurant;
      case ActivityCategory.cafe:
        return Icons.local_cafe;
      case ActivityCategory.sightseeing:
        return Icons.photo_camera;
      case ActivityCategory.stay:
        return Icons.hotel;
      case ActivityCategory.transit:
        return Icons.directions_transit;
      case ActivityCategory.shopping:
        return Icons.shopping_bag;
    }
  }
}

@collection
class ItineraryItem {
  Id id = Isar.autoIncrement;

  /// 所屬 Trip ID（便於多行程關聯與獨立匯出 JSON）
  @Index()
  late int tripId;

  /// 行程時間點
  @Index()
  late DateTime time;

  /// 標題 (地點名稱，如 "淺草雷門", "HARBS 新宿店")
  late String title;

  /// 類別 Enum (以 name 存入資料庫)
  @enumerated
  late ActivityCategory category;

  /// 狀態標記 (例如: "已預約", "需排隊", "自由參觀")
  String? statusTag;

  /// 備註或預算金額 (例如: "預算 ¥3,500 / 記得帶護照退稅")
  String? notesOrBudget;

  /// 本地檔案或照片附件路徑 (供離線憑證或門票截圖)
  String? localAttachmentPath;
}
