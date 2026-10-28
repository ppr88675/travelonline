import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/trip/domain/trip.dart';
import '../../features/itinerary/domain/itinerary_item.dart';
import '../../features/packing/domain/checklist_item.dart';

/// 提供全域單例 Isar 實例
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider 需在 main() 初始化後覆蓋 (override)');
});

/// 紀錄目前選取的旅程 ID (Trip ID)，讓「行程時間軸」與「打包清單」同步切換不同國家的旅程
final selectedTripIdProvider = StateProvider<int?>((ref) => null);

/// 控制底部導航列目前的分頁索引 (0: 我的旅程, 1: 行程日程, 2: 打包清單)
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// 初始化 Isar 資料庫
Future<Isar> initIsarDatabase() async {
  final dir = await getApplicationDocumentsDirectory();

  return await Isar.open(
    [
      TripSchema,
      ItineraryItemSchema,
      ChecklistItemSchema,
    ],
    directory: dir.path,
    inspector: true,
  );
}
