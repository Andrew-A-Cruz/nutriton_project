import 'package:flutter/cupertino.dart';

/// A list whose rows can be swiped away to archive them. A dismissed
/// Dismissible must leave the tree on the frame it is dismissed, so the row is
/// hidden at once. The database stream then drops it for good. If the archive
/// fails, the row comes back.
class ArchivableList<T> extends StatefulWidget {
  const ArchivableList({
    super.key,
    required this.items,
    required this.idOf,
    required this.rowBuilder,
    this.onArchive,
  });

  final List<T> items;
  final String Function(T item) idOf;
  final Widget Function(BuildContext context, T item) rowBuilder;

  /// Null disables swiping.
  final Future<void> Function(T item)? onArchive;

  @override
  State<ArchivableList<T>> createState() => _ArchivableListState<T>();
}

class _ArchivableListState<T> extends State<ArchivableList<T>> {
  final _hidden = <String>{};

  Future<void> _archive(T item) async {
    final id = widget.idOf(item);
    setState(() => _hidden.add(id));
    try {
      await widget.onArchive!(item);
    } catch (_) {
      if (mounted) setState(() => _hidden.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final item in widget.items)
        if (!_hidden.contains(widget.idOf(item))) item,
    ];
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final item = visible[i];
        final row = widget.rowBuilder(context, item);
        if (widget.onArchive == null) return row;
        return Dismissible(
          key: ValueKey(widget.idOf(item)),
          direction: DismissDirection.endToStart,
          background: const _ArchiveBackground(),
          onDismissed: (_) => _archive(item),
          child: row,
        );
      },
    );
  }
}

class _ArchiveBackground extends StatelessWidget {
  const _ArchiveBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.systemOrange,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Text(
        'Archive',
        style: TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
