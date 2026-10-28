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
    inspector: true, // 開發環境可在瀏覽器直接檢查 DB 內容
  );
}
