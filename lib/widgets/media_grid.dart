import 'dart:io';

import 'package:flutter/material.dart';

import '../status_service.dart';
import '../theme.dart';

/// Grille de statuts (photos ou vidéos) avec bouton de téléchargement rapide.
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.saved,
    required this.onOpen,
    this.onQuickSave,
    required this.onRefresh,
    required this.empty,
  });

  final List<StatusItem> items;
  final Set<String> saved;
  final void Function(int index) onOpen;
  final Future<void> Function(StatusItem item)? onQuickSave;
  final Future<void> Function() onRefresh;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          empty,
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: SvColors.green,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _Tile(
          item: items[i],
          isSaved: saved.contains(items[i].name),
          onTap: () => onOpen(i),
          onQuickSave: onQuickSave,
        ),
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.item,
    required this.isSaved,
    required this.onTap,
    this.onQuickSave,
  });

  final StatusItem item;
  final bool isSaved;
  final VoidCallback onTap;
  final Future<void> Function(StatusItem item)? onQuickSave;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  late Future<String?> _thumb;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _thumb = StatusService.instance.thumbnail(widget.item);
  }

  @override
  void didUpdateWidget(covariant _Tile old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) {
      _thumb = StatusService.instance.thumbnail(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: SvColors.surface,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(fit: StackFit.expand, children: [
            FutureBuilder<String?>(
              future: _thumb,
              builder: (_, snap) {
                final p = snap.data;
                if (p == null) {
                  return Center(
                    child: snap.connectionState == ConnectionState.done
                        ? Icon(
                            widget.item.isVideo
                                ? Icons.movie_outlined
                                : Icons.image_outlined,
                            color: SvColors.muted,
                            size: 32)
                        : const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return Image.file(
                  File(p),
                  fit: BoxFit.cover,
                  cacheWidth: (140 * dpr).round(),
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: SvColors.muted),
                );
              },
            ),
            if (widget.item.isVideo)
              const Center(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x99000000),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            Positioned(
              right: 6,
              bottom: 6,
              child: widget.isSaved
                  ? const _Badge(icon: Icons.check_rounded)
                  : widget.onQuickSave == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await widget.onQuickSave!(widget.item);
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          child: _busy
                              ? const _Badge(spinner: true)
                              : const _Badge(icon: Icons.download_rounded),
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({this.icon, this.spinner = false});
  final IconData? icon;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: SvColors.green,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
      ),
      child: spinner
          ? const Padding(
              padding: EdgeInsets.all(7),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF02210B)),
            )
          : Icon(icon, size: 19, color: const Color(0xFF02210B)),
    );
  }
}
