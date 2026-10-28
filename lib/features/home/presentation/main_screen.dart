import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../../../core/database/database_provider.dart';
import '../../itinerary/domain/itinerary_item.dart';
import '../../itinerary/presentation/timeline_page.dart';
import '../../packing/domain/checklist_item.dart';
import '../../packing/presentation/packing_page.dart';
import '../../trip/domain/trip.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    final pages = const [
      TripListPage(),
      TimelinePage(),
      PackingPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: '我的旅程',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: '行程日程',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '打包清單',
          ),
        ],
      ),
    );
  }
}

/// 多旅程管理頁面（支援建立 10月去A國家、11月去B國家 等多個獨立行程）
class TripListPage extends ConsumerStatefulWidget {
  const TripListPage({super.key});

  @override
  ConsumerState<TripListPage> createState() => _TripListPageState();
}

class _TripListPageState extends ConsumerState<TripListPage> {
  List<Trip> _trips = [];
  Map<int, int> _itineraryCountMap = {};
  Map<int, String> _packingProgressMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final isar = ref.read(isarProvider);
    var trips = await isar.trips.where().findAll();
    final allItinerary = await isar.itineraryItems.where().findAll();
    final allChecklist = await isar.checklistItems.where().findAll();

    // 若從舊版升級，已有 tripId=1 的行程但尚未建立 Trip 實體，自動補齊對應旅程標題
    if (trips.isEmpty && (allItinerary.isNotEmpty || allChecklist.isNotEmpty)) {
      final defaultTrip = Trip()
        ..id = 1
        ..title = '我的預設旅程'
        ..destination = '日本 東京'
        ..startDate = DateTime(2026, 10, 10)
        ..endDate = DateTime(2026, 10, 15)
        ..createdAt = DateTime.now()
        ..description = '可點擊右上角鉛筆修改國家與日期';
      await isar.writeTxn(() async {
        await isar.trips.put(defaultTrip);
      });
      trips = await isar.trips.where().findAll();
    }

    trips.sort((a, b) => a.startDate.compareTo(b.startDate));

    final countMap = <int, int>{};
    final packMap = <int, String>{};
    for (final t in trips) {
      countMap[t.id] = allItinerary.where((i) => i.tripId == t.id).length;
      final tPack = allChecklist.where((c) => c.tripId == t.id).toList();
      final packed = tPack.where((c) => c.isPacked).length;
      packMap[t.id] = '${packed}/${tPack.length}';
    }

    final currentSelected = ref.read(selectedTripIdProvider);
    if (trips.isNotEmpty &&
        (currentSelected == null || !trips.any((t) => t.id == currentSelected))) {
      Future.microtask(() {
        if (mounted) {
          ref.read(selectedTripIdProvider.notifier).state = trips.first.id;
        }
      });
    } else if (trips.isEmpty && currentSelected != null) {
      Future.microtask(() {
        if (mounted) {
          ref.read(selectedTripIdProvider.notifier).state = null;
        }
      });
    }

    if (mounted) {
      setState(() {
        _trips = trips;
        _itineraryCountMap = countMap;
        _packingProgressMap = packMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確定刪除此旅程？'),
        content: Text('刪除「${trip.title}」將會一併清除該旅程底下的所有行程與打包清單，且不會自動復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final isar = ref.read(isarProvider);
    final allItinerary = await isar.itineraryItems.where().findAll();
    final allChecklist = await isar.checklistItems.where().findAll();
    final itinIds = allItinerary.where((i) => i.tripId == trip.id).map((i) => i.id).toList();
    final packIds = allChecklist.where((c) => c.tripId == trip.id).map((c) => c.id).toList();

    await isar.writeTxn(() async {
      await isar.trips.delete(trip.id);
      if (itinIds.isNotEmpty) {
        await isar.itineraryItems.deleteAll(itinIds);
      }
      if (packIds.isNotEmpty) {
        await isar.checklistItems.deleteAll(packIds);
      }
    });

    await _loadTrips();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已刪除旅程「${trip.title}」'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddOrEditTripModal({Trip? existingTrip}) async {
    final titleCtrl = TextEditingController(text: existingTrip?.title ?? '');
    final destCtrl = TextEditingController(text: existingTrip?.destination ?? '');
    final descCtrl = TextEditingController(text: existingTrip?.description ?? '');
    DateTime startDate = existingTrip?.startDate ?? DateTime.now().add(const Duration(days: 7));
    DateTime endDate = existingTrip?.endDate ?? DateTime.now().add(const Duration(days: 12));

    final popularDestinations = [
      '日本 東京',
      '日本 大阪/京都',
      '日本 北海道',
      '韓國 首爾',
      '泰國 曼谷',
      '台灣 環島',
      '歐洲 自由行',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final fmt = DateFormat('yyyy/MM/dd');
            final days = endDate.difference(startDate).inDays + 1;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existingTrip == null ? '建立新旅程' : '編輯旅程資訊',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: '旅程名稱 *',
                        hintText: '例如：10月 日本東京賞楓、11月 韓國首爾美食行',
                        prefixIcon: const Icon(Icons.flight_takeoff),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: destCtrl,
                      decoration: InputDecoration(
                        labelText: '目的地國家 / 城市 *',
                        hintText: '例如：日本 東京（搜尋景點時會自動以此為預設地區）',
                        prefixIcon: const Icon(Icons.public),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: popularDestinations.map((d) {
                        return ActionChip(
                          label: Text(d, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setModalState(() {
                              destCtrl.text = d;
                              if (titleCtrl.text.trim().isEmpty) {
                                titleCtrl.text = '${startDate.month}月 $d之旅';
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                          initialDateRange: DateTimeRange(start: startDate, end: endDate),
                        );
                        if (picked != null) {
                          setModalState(() {
                            startDate = picked.start;
                            endDate = picked.end;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, color: Color(0xFF0EA5E9)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${fmt.format(startDate)}  ➔  ${fmt.format(endDate)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '共 $days 天行程（點擊選擇出發與回程日期）',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: '旅程備註（選填）',
                        hintText: '例如：搭乘星宇航空 JX800、入住新宿飯店...',
                        prefixIcon: const Icon(Icons.notes),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: Text(
                          existingTrip == null ? '建立並開始規劃' : '儲存變更',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final dest = destCtrl.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('請輸入旅程名稱')),
                            );
                            return;
                          }

                          final isar = ref.read(isarProvider);
                          final trip = existingTrip ?? Trip();
                          trip.title = title;
                          trip.destination = dest.isEmpty ? '未設定目的地' : dest;
                          trip.startDate = DateTime(
                            startDate.year,
                            startDate.month,
                            startDate.day,
                          );
                          trip.endDate = DateTime(
                            endDate.year,
                            endDate.month,
                            endDate.day,
                            23,
                            59,
                          );
                          trip.createdAt = existingTrip?.createdAt ?? DateTime.now();
                          trip.description =
                              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();

                          late int savedId;
                          await isar.writeTxn(() async {
                            savedId = await isar.trips.put(trip);
                          });

                          ref.read(selectedTripIdProvider.notifier).state = savedId;
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadTrips();

                          // 若是新建立的旅程，自動跳轉至「行程日程」分頁方便立即排行程
                          if (existingTrip == null && mounted) {
                            ref.read(bottomNavIndexProvider.notifier).state = 1;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTripId = ref.watch(selectedTripIdProvider);
    final fmt = DateFormat('yyyy/MM/dd');

    ref.listen<int>(bottomNavIndexProvider, (prev, next) {
      if (next == 0) {
        _loadTrips();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '我的旅程清單',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditTripModal(),
        icon: const Icon(Icons.add),
        label: const Text('新增旅程'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flight_takeoff,
                          size: 64,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '尚未建立任何旅程',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '你可以分別建立「10月 日本行」、「11月 韓國行」等多個獨立旅程，行程與打包清單皆會分開保存！',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showAddOrEditTripModal(),
                          icon: const Icon(Icons.add),
                          label: const Text('建立第一個旅程'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    final isSelected = trip.id == selectedTripId;
                    final days = trip.endDate.difference(trip.startDate).inDays + 1;
                    final itinCount = _itineraryCountMap[trip.id] ?? 0;
                    final packStat = _packingProgressMap[trip.id] ?? '0/0';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0EA5E9)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          ref.read(selectedTripIdProvider.notifier).state = trip.id;
                          ref.read(bottomNavIndexProvider.notifier).state = 1;
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF0EA5E9)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.public,
                                          size: 14,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          trip.destination,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '目前規劃中',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: '編輯旅程',
                                    onPressed: () =>
                                        _showAddOrEditTripModal(existingTrip: trip),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Color(0xFFEF4444),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: '刪除旅程',
                                    onPressed: () => _deleteTrip(trip),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                trip.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${fmt.format(trip.startDate)} - ${fmt.format(trip.endDate)}（$days 天）',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              if (trip.description != null &&
                                  trip.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  trip.description!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '已排 $itinCount 個行程點',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.checklist_rtl,
                                    size: 16,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '打包進度 $packStat',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    '進入規劃 ➔',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
