import 'package:flutter/material.dart';

class PackingPage extends StatefulWidget {
  const PackingPage({super.key});

  @override
  State<PackingPage> createState() => _PackingPageState();
}

class _PackingPageState extends State<PackingPage> {
  // 示範資料
  final Map<String, List<Map<String, dynamic>>> _groupedItems = {
    '重要證件': [
      {'name': '護照 (效期6個月以上)', 'checked': true},
      {'name': '日幣現金與跨國提款卡', 'checked': true},
      {'name': '海外旅遊平安保險單', 'checked': false},
    ],
    '3C 配件': [
      {'name': '行動電源 (需隨身攜帶)', 'checked': true},
      {'name': 'Type-C 快充頭與充電線', 'checked': false},
      {'name': '日本上網 SIM 卡 / eSIM QR', 'checked': false},
    ],
    '個人用品': [
      {'name': '常備藥品 (止痛、胃藥)', 'checked': false},
      {'name': '輕量雨傘', 'checked': false},
      {'name': '換洗衣物 3 套', 'checked': false},
    ],
  };

  void _importDefaultTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已成功匯入預設旅行打包範本！'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 計算打包進度
    int totalCount = 0;
    int packedCount = 0;
    for (var list in _groupedItems.values) {
      totalCount += list.length;
      packedCount += list.where((item) => item['checked'] == true).length;
    }
    final progress = totalCount == 0 ? 0.0 : packedCount / totalCount;
    final progressPercentage = (progress * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '打包清單',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          TextButton.icon(
            onPressed: _importDefaultTemplate,
            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
            label: const Text('匯入範本'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 頂部打包進度條面板
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

          // 分組清單
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _groupedItems.entries.map((entry) {
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
                        final isChecked = item['checked'] as bool;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              item['checked'] = !isChecked;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: Row(
                              children: [
                                // 大尺寸、觸控友善的 Checkbox
                                Transform.scale(
                                  scale: 1.25,
                                  child: Checkbox(
                                    value: isChecked,
                                    activeColor: const Color(0xFF10B981),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        item['checked'] = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['name'],
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
