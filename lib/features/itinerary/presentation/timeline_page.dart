import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/database_provider.dart';
import '../../trip/domain/trip.dart';
import '../domain/itinerary_item.dart';

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  ActivityCategory? _selectedCategory;
  Trip? _currentTrip;
  List<Trip> _allTrips = [];
  List<ItineraryItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripAndItems();
  }

  /// 讀取目前選取的 Trip 與該 Trip 專屬的行程（絕不自動塞回已刪除的預設行程）
  Future<void> _loadTripAndItems() async {
    final isar = ref.read(isarProvider);
    final selectedTripId = ref.read(selectedTripIdProvider);
    final allTrips = await isar.trips.where().findAll();
    allTrips.sort((a, b) => a.startDate.compareTo(b.startDate));

    Trip? activeTrip;
    if (selectedTripId != null) {
      activeTrip = allTrips.where((t) => t.id == selectedTripId).firstOrNull;
    }
    if (activeTrip == null && allTrips.isNotEmpty) {
      activeTrip = allTrips.first;
      Future.microtask(() {
        if (mounted) {
          ref.read(selectedTripIdProvider.notifier).state = activeTrip!.id;
        }
      });
    }

    List<ItineraryItem> tripItems = [];
    if (activeTrip != null) {
      final allItems = await isar.itineraryItems.where().findAll();
      tripItems = allItems.where((e) => e.tripId == activeTrip!.id).toList();
      tripItems.sort((a, b) => a.time.compareTo(b.time));
    }

    if (mounted) {
      setState(() {
        _allTrips = allTrips;
        _currentTrip = activeTrip;
        _items = tripItems;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(ItineraryItem item) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      await isar.itineraryItems.delete(item.id);
    });
    await _loadTripAndItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已刪除「${item.title}」'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openOfflineNavigation(String locationName) async {
    final query = Uri.encodeComponent(locationName);
    final geoUri = Uri.parse('geo:0,0?q=$query');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// 開啟「手動新增 / 編輯行程」彈窗
  Future<void> _showAddOrEditDialog({
    ItineraryItem? existingItem,
    String? prefillTitle,
    ActivityCategory? prefillCategory,
    String? prefillNotes,
  }) async {
    if (_currentTrip == null) return;

    final titleCtrl = TextEditingController(
      text: existingItem?.title ?? prefillTitle ?? '',
    );
    final statusCtrl = TextEditingController(
      text: existingItem?.statusTag ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existingItem?.notesOrBudget ?? prefillNotes ?? '',
    );
    ActivityCategory selectedCat =
        existingItem?.category ?? prefillCategory ?? ActivityCategory.sightseeing;

    // 預設時間自動對齊當前旅程的出發日期早上 09:30，方便規劃未來月份的行程
    DateTime defaultInitialTime = DateTime(
      _currentTrip!.startDate.year,
      _currentTrip!.startDate.month,
      _currentTrip!.startDate.day,
      9,
      30,
    );
    if (_items.isNotEmpty) {
      defaultInitialTime = _items.last.time.add(const Duration(hours: 2));
    }
    DateTime selectedTime = existingItem?.time ?? defaultInitialTime;

    final statusSuggestions = ['已預約', '必吃推薦', '需購票', '自由參觀', '已付款'];

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
            final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(selectedTime);

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
                        Expanded(
                          child: Text(
                            existingItem == null
                                ? '新增行程至「${_currentTrip!.title}」'
                                : '編輯行程項目',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
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
                        labelText: '地點或店家名稱 *',
                        hintText: '例如：敘敘苑 晴空塔店、清水寺',
                        prefixIcon: const Icon(Icons.place_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '選擇類別',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ActivityCategory.values.map((cat) {
                        final isSelected = selectedCat == cat;
                        return ChoiceChip(
                          avatar: Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                          label: Text(cat.label),
                          selected: isSelected,
                          selectedColor: cat.color,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setModalState(() => selectedCat = cat);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedTime,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (pickedDate == null) return;
                        if (!context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedTime),
                        );
                        if (pickedTime == null) return;
                        setModalState(() {
                          selectedTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Color(0xFF0EA5E9)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '行程時間：$dateStr',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const Text(
                              '點擊修改',
                              style: TextStyle(fontSize: 13, color: Color(0xFF0EA5E9)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: statusCtrl,
                      decoration: InputDecoration(
                        labelText: '狀態標記（選填）',
                        hintText: '例如：已預約 18:00、必吃、自由參觀',
                        prefixIcon: const Icon(Icons.bookmark_border),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: statusSuggestions.map((tag) {
                        return ActionChip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setModalState(() => statusCtrl.text = tag);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '備註 / 預算 / 地址（選填）',
                        hintText: '例如：預算 ¥5,000、必點牛舌、地址資訊...',
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
                          existingItem == null ? '加入行程時間軸' : '儲存修改',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('請輸入地點或店家名稱')),
                            );
                            return;
                          }

                          final isar = ref.read(isarProvider);
                          final item = existingItem ?? ItineraryItem();
                          item.tripId = _currentTrip!.id;
                          item.title = title;
                          item.category = selectedCat;
                          item.time = selectedTime;
                          item.statusTag =
                              statusCtrl.text.trim().isEmpty ? null : statusCtrl.text.trim();
                          item.notesOrBudget =
                              notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();

                          await isar.writeTxn(() async {
                            await isar.itineraryItems.put(item);
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadTripAndItems();
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

  /// 開啟「網路搜尋店家與景點」面板（自動結合當前旅程的目的地國家/城市）
  Future<void> _openOnlineSearchModal() async {
    if (_currentTrip == null) return;

    final dest = _currentTrip!.destination;
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    String? errorMsg;

    final quickKeywords = [
      '$dest 景點',
      '$dest 美食',
      '$dest 咖啡',
      '淺草寺',
      '一蘭拉麵',
      '敘敘苑',
      '藍瓶咖啡',
      '環球影城',
    ];

    ActivityCategory detectCategory(String type, String clazz) {
      final t = '$type $clazz'.toLowerCase();
      if (t.contains('cafe') || t.contains('coffee') || t.contains('tea')) {
        return ActivityCategory.cafe;
      }
      if (t.contains('restaurant') ||
          t.contains('food') ||
          t.contains('bar') ||
          t.contains('izakaya') ||
          t.contains('bakery')) {
        return ActivityCategory.food;
      }
      if (t.contains('hotel') ||
          t.contains('hostel') ||
          t.contains('guest_house') ||
          t.contains('motel')) {
        return ActivityCategory.stay;
      }
      if (t.contains('station') ||
          t.contains('aerodrome') ||
          t.contains('airport') ||
          t.contains('subway') ||
          t.contains('bus')) {
        return ActivityCategory.transit;
      }
      if (t.contains('shop') ||
          t.contains('mall') ||
          t.contains('department_store') ||
          t.contains('market')) {
        return ActivityCategory.shopping;
      }
      return ActivityCategory.sightseeing;
    }

    Future<void> performSearch(
      String query,
      void Function(void Function()) setSheetState,
    ) async {
      final q = query.trim();
      if (q.isEmpty) return;

      setSheetState(() {
        isSearching = true;
        errorMsg = null;
      });

      try {
        final uri = Uri.https(
          'nominatim.openstreetmap.org',
          '/search',
          {
            'q': q,
            'format': 'json',
            'addressdetails': '1',
            'limit': '12',
            'accept-language': 'zh-TW,ja,en',
          },
        );

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        final request = await client.getUrl(uri);
        request.headers.set(
          'User-Agent',
          'TravelPlannerOfflineApp/1.0 (https://github.com/travelplanner)',
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(body) as List<dynamic>;
          final parsed = data.map((raw) {
            final map = raw as Map<String, dynamic>;
            final displayName = (map['display_name'] ?? '').toString();
            final nameField = (map['name'] ?? '').toString();
            final shortTitle = nameField.isNotEmpty
                ? nameField
                : displayName.split(',').first.trim();
            final type = (map['type'] ?? '').toString();
            final clazz = (map['class'] ?? '').toString();

            return <String, dynamic>{
              'title': shortTitle,
              'address': displayName,
              'category': detectCategory(type, clazz),
              'type': type,
            };
          }).toList();

          setSheetState(() {
            searchResults = parsed;
            isSearching = false;
            if (parsed.isEmpty) {
              errorMsg = '找不到「$q」的相關結果，可嘗試輸入「$dest + 店名」或點選上方「直接納入」按鈕加入。';
            }
          });
        } else {
          setSheetState(() {
            isSearching = false;
            errorMsg = '搜尋伺服器忙碌中（代碼 ${response.statusCode}），請稍後再試。';
          });
        }
      } catch (e) {
        setSheetState(() {
          isSearching = false;
          errorMsg = '無法連線至搜尋服務，請確認手機目前已連上網路。';
        });
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.travel_explore, color: Color(0xFF0EA5E9)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '搜尋店家與景點（${_currentTrip!.destination}）',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setSheetState(() {}),
                              onSubmitted: (val) => performSearch(val, setSheetState),
                              decoration: InputDecoration(
                                hintText: '輸入景點、餐廳、咖啡廳 (例：$dest 燒肉)',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          searchCtrl.clear();
                                          setSheetState(() {});
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => performSearch(searchCtrl.text, setSheetState),
                            child: const Text('搜尋'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: quickKeywords.map((kw) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(kw, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.white,
                                onPressed: () {
                                  searchCtrl.text = kw;
                                  performSearch(kw, setSheetState);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (searchCtrl.text.trim().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '想直接把「${searchCtrl.text.trim()}」加入行程？',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF0369A1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text('查地圖'),
                                onPressed: () => _openOfflineNavigation(searchCtrl.text.trim()),
                              ),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('直接納入'),
                                onPressed: () {
                                  final customTitle = searchCtrl.text.trim();
                                  Navigator.pop(ctx);
                                  _showAddOrEditDialog(prefillTitle: customTitle);
                                },
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : errorMsg != null
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        errorMsg!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                : searchResults.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '輸入關鍵字或點擊上方熱門標籤，\n即可搜尋全球景點、餐廳、咖啡廳與飯店並一鍵納入當前旅程！',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        controller: scrollController,
                                        itemCount: searchResults.length,
                                        itemBuilder: (_, idx) {
                                          final place = searchResults[idx];
                                          final title = place['title'] as String;
                                          final address = place['address'] as String;
                                          final cat = place['category'] as ActivityCategory;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: cat.color.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(cat.icon, size: 13, color: cat.color),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            cat.label,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: cat.color,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  address,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    TextButton.icon(
                                                      icon: const Icon(Icons.map_outlined, size: 16),
                                                      label: const Text('看地圖'),
                                                      onPressed: () =>
                                                          _openOfflineNavigation(title),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    FilledButton.icon(
                                                      icon: const Icon(Icons.add_task, size: 16),
                                                      label: const Text('納入行程'),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: cat.color,
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pop(ctx);
                                                        _showAddOrEditDialog(
                                                          prefillTitle: title,
                                                          prefillCategory: cat,
                                                          prefillNotes: '地址：$address',
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 快速切換不同旅程的底部選單
  void _showSwitchTripSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final fmt = DateFormat('yyyy/MM/dd');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '切換要規劃的旅程',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(bottomNavIndexProvider.notifier).state = 0;
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('管理/新增旅程'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._allTrips.map((t) {
                final isSelected = t.id == _currentTrip?.id;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected ? const Color(0xFFE0F2FE) : null,
                  leading: Icon(
                    Icons.flight_takeoff,
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                  ),
                  title: Text(
                    t.title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${t.destination}｜${fmt.format(t.startDate)} - ${fmt.format(t.endDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF0284C7))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(selectedTripIdProvider.notifier).state = t.id;
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(selectedTripIdProvider, (prev, next) {
      _loadTripAndItems();
    });
    ref.listen<int>(bottomNavIndexProvider, (prev, next) {
      if (next == 1) {
        _loadTripAndItems();
      }
    });

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentTrip == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '行程日程',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.luggage_outlined, size: 64, color: Color(0xFF94A3B8)),
                const SizedBox(height: 16),
                const Text(
                  '請先建立或選擇一個旅程',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '先建立例如「10月 日本行」或「11月 韓國行」，即可開始為該趟旅程安排專屬景點與店家！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(bottomNavIndexProvider.notifier).state = 0;
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('前往建立旅程'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredItems = _selectedCategory == null
        ? _items
        : _items.where((e) => e.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _showSwitchTripSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _currentTrip!.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF0EA5E9)),
                  ],
                ),
                Text(
                  '${_currentTrip!.destination}（點擊切換其他旅程）',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton.tonalIcon(
            onPressed: _openOnlineSearchModal,
            icon: const Icon(Icons.travel_explore, size: 18),
            label: const Text('搜尋景點/店家'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('新增行程'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_note_outlined,
                            size: 56,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedCategory == null
                                ? '「${_currentTrip!.title}」目前尚無行程'
                                : '目前尚無「${_selectedCategory!.label}」類別的行程',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '點擊右上角「搜尋景點/店家」或右下角「＋新增行程」開始規劃！',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildTimelineCard(filteredItems[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            FilterChip(
              label: const Text('全部'),
              selected: _selectedCategory == null,
              onSelected: (_) => setState(() => _selectedCategory = null),
            ),
            const SizedBox(width: 8),
            ...ActivityCategory.values.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: isSelected ? Colors.white : cat.color,
                  ),
                  label: Text(cat.label),
                  selected: isSelected,
                  selectedColor: cat.color.withOpacity(0.9),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _selectedCategory = val ? cat : null;
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(ItineraryItem item) {
    final timeStr = DateFormat('HH:mm').format(item.time);
    final dateStr = DateFormat('MM/dd').format(item.time);
    final category = item.category;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: category.color, width: 5),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: category.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(category.icon, size: 13, color: category.color),
                                const SizedBox(width: 4),
                                Text(
                                  category.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: category.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.statusTag != null && item.statusTag!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.statusTag!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                            visualDensity: VisualDensity.compact,
                            tooltip: '編輯行程',
                            onPressed: () => _showAddOrEditDialog(existingItem: item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                            visualDensity: VisualDensity.compact,
                            tooltip: '刪除行程',
                            onPressed: () => _deleteItem(item),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (item.notesOrBudget != null && item.notesOrBudget!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.notesOrBudget!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _openOfflineNavigation(item.title),
                          icon: const Icon(Icons.navigation_outlined, size: 16),
                          label: const Text('離線導航'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: const Color(0xFF0EA5E9),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
