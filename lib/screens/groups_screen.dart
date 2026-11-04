import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';
import 'group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _db = DatabaseService.instance;
  List<MapEntry<Map<String, dynamic>, Map<String, int>>> _partitions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final partitions = await _db.getGroups(parentId: null);
    final data = <MapEntry<Map<String, dynamic>, Map<String, int>>>[];
    for (final p in partitions) {
      final stats = await _db.getGroupStats(p['id'] as int);
      data.add(MapEntry(p, stats));
    }
    if (!mounted) return;
    setState(() {
      _partitions = data;
      _loading = false;
    });
  }

  Future<void> _createPartition() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('قسم جديد'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم القسم'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _db.insertGroup(name);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('المجموعات',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: AppBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _partitions.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            EmptyState(
                              icon: Icons.library_books_outlined,
                              title: 'لا توجد أقسام بعد',
                              subtitle:
                                  'اضغط زر + لإنشاء قسم جديد\nثم ضع فيه مجلدات وملفات',
                              color: Color(0xFFDC2626),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 120),
                          itemCount: _partitions.length,
                          itemBuilder: (ctx, i) {
                            final entry = _partitions[i];
                            final p = entry.key;
                            final stats = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RepaintBoundary(
                                child: PartitionTile(
                                  partition: p,
                                  foldersCount: stats['folders'] ?? 0,
                                  filesCount: stats['files'] ?? 0,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      pageRoute(GroupScreen(
                                        groupId: p['id'],
                                        groupName: p['name'],
                                      )),
                                    );
                                    _load();
                                  },
                                  onLongPress: () => _showPartitionOptions(p),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPartition,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showPartitionOptions(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupOptionsSheet(
        group: p,
        onChanged: _load,
      ),
    );
  }
}