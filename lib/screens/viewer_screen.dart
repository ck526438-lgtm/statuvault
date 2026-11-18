import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../status_service.dart';
import '../theme.dart';

/// Visionneuse plein écran : glisser entre les statuts, enregistrer, partager.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.savedNames,
    this.savedMode = false,
  });

  final List<StatusItem> items;
  final int initialIndex;
  final Set<String> savedNames;
  final bool savedMode;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final svc = StatusService.instance;
  late final PageController _pc;
  late int _index;
  late final List<StatusItem> _items;
  bool _busy = false;

  StatusItem get _current => _items[_index];

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _pc = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await svc.save(_current);
      widget.savedNames.add(_current.name);
      _toast('Enregistré dans la galerie (album Statuvault)');
    } catch (e) {
      _toast('Échec : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    try {
      final path = await svc.ensureLocal(_current);
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        text: 'Partagé avec Statuvault',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (e) {
      _toast('Partage impossible : $e');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: SvColors.surface,
        title: const Text('Supprimer ?'),
        content: const Text(
            'Le fichier est retiré de Statuvault. La copie dans ta galerie est conservée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await svc.deleteLocal(_current);
    widget.savedNames.remove(_current.name);
    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
    if (_items.isEmpty && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    final saved = widget.savedMode || widget.savedNames.contains(_current.name);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${_items.length}',
            style: const TextStyle(fontSize: 16)),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: _items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => _MediaPage(
          key: ValueKey(_items[i].id),
          item: _items[i],
          active: i == _index,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _share,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SvColors.text,
                  side: const BorderSide(color: SvColors.surfaceHi),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Partager'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.savedMode
                  ? FilledButton.icon(
                      onPressed: _delete,
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5A1A1A),
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Supprimer'),
                    )
                  : FilledButton.icon(
                      onPressed: (_busy || saved) ? null : _save,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(saved
                              ? Icons.check_circle_rounded
                              : Icons.download_rounded),
                      label: Text(saved ? 'Enregistré' : 'Enregistrer'),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MediaPage extends StatefulWidget {
  const _MediaPage({super.key, required this.item, required this.active});
  final StatusItem item;
  final bool active;

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  String? _path;
  VideoPlayerController? _vc;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await StatusService.instance.ensureLocal(widget.item);
      if (!mounted) return;
      if (widget.item.isVideo) {
        final vc = VideoPlayerController.file(File(p));
        await vc.initialize();
        await vc.setLooping(true);
        if (!mounted) {
          vc.dispose();
          return;
        }
        vc.addListener(() {
          if (mounted) setState(() {});
        });
        if (widget.active) vc.play();
        _vc = vc;
      }
      setState(() => _path = p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void didUpdateWidget(covariant _MediaPage old) {
    super.didUpdateWidget(old);
    final vc = _vc;
    if (vc == null) return;
    if (widget.active && !vc.value.isPlaying) vc.play();
    if (!widget.active && vc.value.isPlaying) vc.pause();
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.white70)));
    }
    if (_path == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!widget.item.isVideo) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(_path!), fit: BoxFit.contain)),
      );
    }
    final vc = _vc!;
    return GestureDetector(
      onTap: () => vc.value.isPlaying ? vc.pause() : vc.play(),
      child: Stack(alignment: Alignment.center, children: [
        Center(
          child: AspectRatio(
            aspectRatio: vc.value.aspectRatio,
            child: VideoPlayer(vc),
          ),
        ),
        if (!vc.value.isPlaying)
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0x88000000),
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Row(children: [
            Text(_fmt(vc.value.position),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 10),
            Expanded(
              child: VideoProgressIndicator(
                vc,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: SvColors.green,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(_fmt(vc.value.duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
