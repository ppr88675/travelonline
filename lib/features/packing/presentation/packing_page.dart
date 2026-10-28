import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/database_provider.dart';
import '../../trip/domain/trip.dart';
import '../domain/checklist_item.dart';

class PackingPage extends ConsumerStatefulWidget {
  const PackingPage({super.key});

  @override
  ConsumerState<PackingPage> createState() => _PackingPageState();
}

class _PackingPageState extends ConsumerState<PackingPage> {
  Trip? _currentTrip;
  List<ChecklistItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripAndChecklist();
  }

  /// 讀取目前選取的 Trip 專屬打包清單（絕不自動塞回已刪除的項目）
  Future<void> _loadTripAndChecklist() async {
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
    }

    List<ChecklistItem> tripItems = [];
    if (activeTrip != null) {
      final allItems = await isar.checklistItems.where().findAll();
      tripItems = allItems.where((e) => e.tripId == activeTrip!.id).toList();
    }

    if (mounted) {
      setState(() {
        _currentTrip = activeTrip;
        _items = tripItems;
        _isLoading = false;
      });
    }
  }

  /// 僅在使用者主動點擊「匯入範本」按鈕時，才為當前旅程加入預設行李項目
  Future<void> _seedTemplateItems() async {
    if (_currentTrip == null) return;

    final isar = ref.read(isarProvider);
    final allItems = await isar.checklistItems.where().findAll();
    final existingNames = allItems
        .where((e) => e.tripId == _currentTrip!.id)
        .map((e) => e.name)
        .toSet();

    final template = <Map<String, String>>[
      {'group': '重要證件', 'name': '護照 (效期6個月以上)'},
      {'group': '重要證件', 'name': '外幣現金與跨國提款卡'},
      {'group': '重要證件', 'name': '海外旅遊平安保險單'},
      {'group': '3C 配件', 'name': '行動電源 (需隨身攜帶)'},
      {'group': '3C 配件', 'name': 'Type-C 快充頭與充電線'},
      {'group': '3C 配件', 'name': '上網 SIM 卡 / eSIM 憑證'},
      {'group': '個人用品', 'name': '常備藥品 (止痛、腸胃藥)'},
      {'group': '個人用品', 'name': '折疊輕量雨傘'},
      {'group': '個人用品', 'name': '換洗衣物與盥洗用品'},
    ];

    final newItems = <ChecklistItem>[];
    for (final entry in template) {
      if (!existingNames.contains(entry['name'])) {
        newItems.add(
          ChecklistItem()
            ..tripId = _currentTrip!.id
            ..groupName = entry['group']!
            ..name = entry['name']!
            ..isPacked = false,
        );
      }
    }

    if (newItems.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.checklistItems.putAll(newItems);
      });
    }

    await _loadTripAndChecklist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newItems.isEmpty
                ? '範本項目皆已在「${_currentTrip!.title}」清單中！'
                : '已為「${_currentTrip!.title}」匯入 ${newItems.length} 項預設打包清單！',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleItem(ChecklistItem item) async {
    final isar = ref.read(isarProvider);
    item.isPacked = !item.isPacked;
    await isar.writeTxn(() async {
      await isar.checklistItems.put(item);
    });
    await _loadTripAndChecklist();
  }

  Future<void> _deleteItem(ChecklistItem item) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      await isar.checklistItems.delete(item.id);
    });
    await _loadTripAndChecklist();
  }

  Future<void> _showAddItemDialog() async {
    if (_currentTrip == null) return;

    final nameCtrl = TextEditingController();
    final groupCtrl = TextEditingController(text: '個人用品');
    final presetGroups = ['重要證件', '3C 配件', '個人用品', '衣物服飾', '常備藥品'];

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
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '新增打包物品（${_currentTrip!.title}）',
                          overflow: TextOverflow.ellipsis,
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
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '物品名稱 *',
                      hintText: '例如：萬國轉接頭、太陽眼鏡',
                      prefixIcon: const Icon(Icons.luggage_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: groupCtrl,
                    decoration: InputDecoration(
                      labelText: '所屬分類群組',
                      prefixIcon: const Icon(Icons.folder_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: presetGroups.map((g) {
                      return ActionChip(
                        label: Text(g, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setModalState(() => groupCtrl.text = g);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('加入打包清單'),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final group = groupCtrl.text.trim().isEmpty
                            ? '其他用品'
                            : groupCtrl.text.trim();
                        if (name.isEmpty) return;

                        final isar = ref.read(isarProvider);
                        final newItem = ChecklistItem()
                          ..tripId = _currentTrip!.id
                          ..name = name
                          ..groupName = group
                          ..isPacked = false;

                        await isar.writeTxn(() async {
                          await isar.checklistItems.put(newItem);
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadTripAndChecklist();
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
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(selectedTripIdProvider, (prev, next) {
      _loadTripAndChecklist();
    });
    ref.listen<int>(bottomNavIndexProvider, (prev, next) {
      if (next == 2) {
        _loadTripAndChecklist();
      }
    });

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentTrip == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '打包清單',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.checklist_outlined, size: 64, color: Color(0xFF94A3B8)),
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
                  '每個旅程都擁有各自獨立的打包清單，不會互相混淆！',
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

    final totalCount = _items.length;
    final packedCount = _items.where((e) => e.isPacked).length;
    final progress = totalCount == 0 ? 0.0 : packedCount / totalCount;
    final progressPercentage = (progress * 100).toInt();

    final Map<String, List<ChecklistItem>> grouped = {};
    for (final item in _items) {
      grouped.putIfAbsent(item.groupName, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '打包清單',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '當前旅程：${_currentTrip!.title}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _seedTemplateItems,
            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
            label: const Text('匯入範本'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        icon: const Icon(Icons.add),
        label: const Text('新增物品'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$packedCount / $totalCount 已打包',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '$progressPercentage%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.luggage_outlined,
                            size: 56,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '「${_currentTrip!.title}」尚無打包項目',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '可點擊下方按鈕一鍵匯入常用行李範本，或點擊右下角「＋新增物品」自訂清單。',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: _seedTemplateItems,
                            icon: const Icon(Icons.download_for_offline_outlined),
                            label: const Text('一鍵匯入預設打包範本'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    children: grouped.entries.map((entry) {
                      final groupName = entry.key;
                      final items = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                              child: Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            ...items.map((item) {
                              final isChecked = item.isPacked;
                              return InkWell(
                                onTap: () => _toggleItem(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Transform.scale(
                                        scale: 1.25,
                                        child: Checkbox(
                                          value: isChecked,
                                          activeColor: const Color(0xFF10B981),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          onChanged: (_) => _toggleItem(item),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isChecked
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF0F172A),
                                            decoration: isChecked
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        onPressed: () => _deleteItem(item),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
