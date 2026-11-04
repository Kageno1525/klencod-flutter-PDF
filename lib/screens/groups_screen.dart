import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/common.dart';
import 'group_screen.dart';

class GroupsScreen extends StatefulWidget {
  final int refreshTick;
  final VoidCallback onChanged;
  const GroupsScreen({
    super.key,
    required this.refreshTick,
    required this.onChanged,
  });

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

  @override
  void didUpdateWidget(GroupsScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _load();
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
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _partitions.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.library_books_outlined,
                            title: 'لا توجد أقسام بعد',
                            subtitle:
                                'اضغط زر + لإنشاء قسم\nثم ضع فيه مجلدات وملفات',
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RepaintBoundary(
                              child: PartitionTile(
                                partition: entry.key,
                                foldersCount: entry.value['folders'] ?? 0,
                                filesCount: entry.value['files'] ?? 0,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    pageRoute(GroupScreen(
                                      groupId: entry.key['id'],
                                      groupName: entry.key['name'],
                                    )),
                                  );
                                  _load();
                                  widget.onChanged();
                                },
                                onLongPress: () => _showOptions(entry.key),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'groups_fab',
              onPressed: _createPartition,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupOptionsSheet(group: p, onChanged: () {
        _load();
        widget.onChanged();
      }),
    );
  }
}