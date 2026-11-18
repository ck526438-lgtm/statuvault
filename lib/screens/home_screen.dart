import 'package:flutter/material.dart';

import '../status_service.dart';
import '../theme.dart';
import '../widgets/media_grid.dart';
import 'viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final svc = StatusService.instance;

  WaApp _app = WaApp.whatsapp;
  String? _tree;
  bool _loading = true;
  String? _error;
  List<StatusItem> _statuses = [];
  List<StatusItem> _saved = [];
  List<StatusItem> _imported = [];
  Set<String> _savedNames = {};

  List<StatusItem> get _images =>
      _statuses.where((e) => !e.isVideo).toList(growable: false);
  List<StatusItem> get _videos =>
      _statuses.where((e) => e.isVideo).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (svc.isAndroid) _app = await svc.lastApp;
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (svc.isAndroid) {
        _tree = await svc.treeFor(_app);
        _statuses = _tree == null ? [] : await svc.listStatuses(_tree!);
      } else {
        _imported = await svc.listImported();
      }
      _saved = await svc.listSaved();
      _savedNames = await svc.savedNames();
    } catch (e) {
      _error = '$e';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (svc.isAndroid && _statuses.isNotEmpty && await svc.autoSave) {
      await _autoSave();
    }
  }

  Future<void> _autoSave() async {
    var n = 0;
    for (final s in _statuses) {
      if (_savedNames.contains(s.name)) continue;
      try {
        await svc.save(s);
        _savedNames.add(s.name);
        n++;
      } catch (_) {}
    }
    if (n > 0 && mounted) {
      _saved = await svc.listSaved();
      setState(() {});
      _toast('$n nouveau${n > 1 ? 'x' : ''} statut${n > 1 ? 's' : ''} enregistré${n > 1 ? 's' : ''} automatiquement');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _quickSave(StatusItem it) async {
    try {
      await svc.save(it);
      _savedNames.add(it.name);
      _saved = await svc.listSaved();
      if (mounted) setState(() {});
      _toast('Enregistré dans la galerie (album Statuvault)');
    } catch (e) {
      _toast('Échec : $e');
    }
  }

  Future<void> _grant() async {
    try {
      final uri = await svc.requestAccess(_app);
      if (uri != null) await _reload();
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _switchApp(WaApp a) async {
    if (a == _app) return;
    setState(() => _app = a);
    await svc.setLastApp(a);
    await _reload();
  }

  Future<void> _open(List<StatusItem> list, int index,
      {bool savedMode = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ViewerScreen(
        items: list,
        initialIndex: index,
        savedMode: savedMode,
        savedNames: _savedNames,
      ),
    ));
    _saved = await svc.listSaved();
    _savedNames = await svc.savedNames();
    if (!svc.isAndroid) _imported = await svc.listImported();
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    try {
      final n = await svc.importFiles();
      if (n > 0) {
        await _reload();
        _toast('$n fichier${n > 1 ? 's' : ''} importé${n > 1 ? 's' : ''}');
      }
    } catch (e) {
      _toast('Import impossible : $e');
    }
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final android = svc.isAndroid;
    final tabs = android
        ? const [Tab(text: 'Photos'), Tab(text: 'Vidéos'), Tab(text: 'Enregistrés')]
        : const [Tab(text: 'Importés'), Tab(text: 'Enregistrés')];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/logo_round.png', width: 34, height: 34),
            ),
            const SizedBox(width: 10),
            const Text.rich(TextSpan(
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              children: [
                TextSpan(text: 'Statu'),
                TextSpan(text: 'vault', style: TextStyle(color: SvColors.green)),
              ],
            )),
          ]),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Réglages',
              onPressed: _settings,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(android ? 104 : 48),
            child: Column(children: [
              if (android)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<WaApp>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        backgroundColor: SvColors.surface,
                        selectedBackgroundColor: SvColors.greenDeep,
                        selectedForegroundColor: SvColors.text,
                        foregroundColor: SvColors.muted,
                        side: const BorderSide(color: SvColors.surfaceHi),
                      ),
                      segments: const [
                        ButtonSegment(
                            value: WaApp.whatsapp,
                            icon: Icon(Icons.chat_rounded, size: 18),
                            label: Text('WhatsApp')),
                        ButtonSegment(
                            value: WaApp.business,
                            icon: Icon(Icons.storefront_rounded, size: 18),
                            label: Text('WA Business')),
                      ],
                      selected: {_app},
                      onSelectionChanged: (s) => _switchApp(s.first),
                    ),
                  ),
                ),
              TabBar(tabs: tabs),
            ]),
          ),
        ),
        floatingActionButton: android
            ? null
            : FloatingActionButton.extended(
                onPressed: _import,
                backgroundColor: SvColors.green,
                foregroundColor: const Color(0xFF02210B),
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('Importer',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: _Message(
                    icon: Icons.error_outline_rounded,
                    title: 'Lecture impossible',
                    text: '$_error\n\nRéautorise le dossier depuis les réglages.',
                    action: FilledButton(
                        onPressed: _grant,
                        child: const Text('Réautoriser le dossier')),
                  ))
                : TabBarView(
                    children: android
                        ? [
                            _statusTab(_images, 'photo'),
                            _statusTab(_videos, 'vidéo'),
                            _savedTab(),
                          ]
                        : [_importedTab(), _savedTab()],
                  ),
      ),
    );
  }

  Widget _statusTab(List<StatusItem> list, String kind) {
    if (_tree == null) return _accessCard();
    return MediaGrid(
      items: list,
      saved: _savedNames,
      onRefresh: _reload,
      onOpen: (i) => _open(list, i),
      onQuickSave: _quickSave,
      empty: _Message(
        icon: Icons.hourglass_empty_rounded,
        title: 'Aucun statut $kind',
        text:
            'Ouvre ${_app.label} et regarde quelques statuts, puis reviens ici et tire vers le bas pour actualiser.',
      ),
    );
  }

  Widget _savedTab() => MediaGrid(
        items: _saved,
        saved: const {},
        onRefresh: _reload,
        onOpen: (i) => _open(_saved, i, savedMode: true),
        empty: const _Message(
          icon: Icons.download_done_rounded,
          title: 'Rien d\'enregistré pour l\'instant',
          text:
              'Les statuts que tu enregistres apparaissent ici et dans ta galerie, album « Statuvault ».',
        ),
      );

  Widget _importedTab() => MediaGrid(
        items: _imported,
        saved: _savedNames,
        onRefresh: _reload,
        onOpen: (i) => _open(_imported, i),
        onQuickSave: _quickSave,
        empty: _Message(
          icon: Icons.phone_iphone_rounded,
          title: 'Importe tes statuts',
          text:
              'Sur iPhone, Apple ne permet à aucune appli de lire les statuts WhatsApp directement.\n\n'
              'Enregistre l\'écran pendant un statut (Centre de contrôle → Enregistrement de l\'écran) ou fais une capture, '
              'puis touche « Importer » pour le ranger ici, le partager ou l\'enregistrer dans l\'album Statuvault.',
          action: FilledButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Importer depuis Photos'),
          ),
        ),
      );

  Widget _accessCard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset('assets/logo_round.png', width: 118, height: 118),
          ),
        ),
        const SizedBox(height: 22),
        Text('Autorise l\'accès aux statuts ${_app.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        const _Step(n: 1, text: 'Ouvre WhatsApp et regarde les statuts que tu veux garder.'),
        const _Step(n: 2, text: 'Reviens ici et touche le bouton ci-dessous.'),
        const _Step(
            n: 3,
            text:
                'Le dossier « .Statuses » s\'ouvre : touche « Utiliser ce dossier » puis « Autoriser ».'),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _grant,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Autoriser l\'accès'),
        ),
        const SizedBox(height: 14),
        const Text(
          'Statuvault lit uniquement ce dossier, en lecture seule. Rien n\'est envoyé sur Internet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SvColors.muted, fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _settings() async {
    var auto = await svc.autoSave;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: SvColors.surface,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (svc.isAndroid) ...[
              SwitchListTile(
                value: auto,
                activeThumbColor: SvColors.green,
                title: const Text('Enregistrement automatique'),
                subtitle: const Text(
                    'Enregistre chaque nouveau statut dès l\'ouverture de l\'appli'),
                onChanged: (v) async {
                  await svc.setAutoSave(v);
                  setSheet(() => auto = v);
                  if (v) _autoSave();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: Text('Changer le dossier ${_app.label}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await svc.forgetAccess(_app);
                  await _grant();
                  await _reload();
                },
              ),
            ],
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Statuvault 1.0'),
              subtitle: Text(
                  'Respecte la vie privée de tes contacts : ne republie pas leurs statuts sans leur accord.'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: SvColors.greenDeep,
          child: Text('$n',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: SvColors.text)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 15, height: 1.35))),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: SvColors.green),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SvColors.muted, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}
