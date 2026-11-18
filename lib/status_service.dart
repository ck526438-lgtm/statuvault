import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MediaKind { image, video }

/// Application WhatsApp dont on lit les statuts.
enum WaApp { whatsapp, business }

extension WaAppInfo on WaApp {
  String get label => this == WaApp.whatsapp ? 'WhatsApp' : 'WA Business';
  String get package => this == WaApp.whatsapp ? 'com.whatsapp' : 'com.whatsapp.w4b';
  String get dir => this == WaApp.whatsapp ? 'WhatsApp' : 'WhatsApp Business';
}

class StatusItem {
  StatusItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.modified,
    this.size = 0,
    this.localPath,
  });

  /// URI SAF (Android) ou chemin local.
  final String id;
  final String name;
  final MediaKind kind;
  final DateTime modified;
  final int size;
  String? localPath;
  String? thumbPath;

  bool get isVideo => kind == MediaKind.video;
}

class StatusService {
  StatusService._();
  static final StatusService instance = StatusService._();

  static const _ch = MethodChannel('statuvault/statuses');
  static const album = 'Statuvault';
  static const _videoExt = {'mp4', '3gp', 'mkv', 'mov', 'webm', 'm4v'};

  bool get isAndroid => Platform.isAndroid;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get prefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ---------------------------------------------------------------- Android
  Future<int> sdkInt() async {
    try {
      return await _ch.invokeMethod<int>('sdkInt') ?? 30;
    } catch (_) {
      return 30;
    }
  }

  /// Dossier autorisé pour cette appli (null si pas encore d'accès).
  Future<String?> treeFor(WaApp app) async {
    final p = await prefs;
    final tree = p.getString('tree_${app.name}');
    if (tree == null) return null;
    final granted =
        (await _ch.invokeListMethod<String>('persistedTrees')) ?? const [];
    if (!granted.contains(tree)) {
      await p.remove('tree_${app.name}');
      return null;
    }
    return tree;
  }

  Future<String?> requestAccess(WaApp app) async {
    final sdk = await sdkInt();
    final path = sdk >= 29
        ? 'Android/media/${app.package}/${app.dir}/Media/.Statuses'
        : '${app.dir}/Media/.Statuses';
    final uri = await _ch.invokeMethod<String>('openTree', {'path': path});
    if (uri != null) {
      final p = await prefs;
      await p.setString('tree_${app.name}', uri);
    }
    return uri;
  }

  Future<void> forgetAccess(WaApp app) async {
    final p = await prefs;
    final tree = p.getString('tree_${app.name}');
    if (tree != null) {
      await _ch.invokeMethod('releaseTree', {'tree': tree});
      await p.remove('tree_${app.name}');
    }
  }

  Future<List<StatusItem>> listStatuses(String tree) async {
    final raw = await _ch.invokeListMethod<dynamic>('list', {'tree': tree}) ??
        const [];
    final items = raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return StatusItem(
        id: m['uri'] as String,
        name: m['name'] as String,
        kind: m['type'] == 'video' ? MediaKind.video : MediaKind.image,
        modified: DateTime.fromMillisecondsSinceEpoch(
            (m['modified'] as num?)?.toInt() ?? 0),
        size: (m['size'] as num?)?.toInt() ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  /// Copie locale du fichier (nécessaire pour afficher, lire, partager).
  Future<String> ensureLocal(StatusItem it) async {
    if (it.localPath != null) return it.localPath!;
    if (!isAndroid || !it.id.startsWith('content://')) {
      return it.localPath = it.id;
    }
    final path = await _ch
        .invokeMethod<String>('cache', {'uri': it.id, 'name': it.name});
    return it.localPath = path!;
  }

  Future<String?> thumbnail(StatusItem it) async {
    if (!it.isVideo) return ensureLocal(it);
    if (it.thumbPath != null) return it.thumbPath;
    if (!isAndroid) return null;
    try {
      final uri = it.id.startsWith('content://')
          ? it.id
          : Uri.file(it.localPath ?? it.id).toString();
      return it.thumbPath = await _ch
          .invokeMethod<String>('thumb', {'uri': uri, 'name': it.name});
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------- Enregistrés
  Future<Directory> _dir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$name');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Set<String>> savedNames() async {
    final d = await _dir('saved');
    return d
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
  }

  /// Enregistre dans la galerie (album « Statuvault ») + copie dans l'appli.
  Future<void> save(StatusItem it) async {
    final path = await ensureLocal(it);
    if (!await Gal.hasAccess(toAlbum: true)) {
      final ok = await Gal.requestAccess(toAlbum: true);
      if (!ok) throw Exception('Accès à la galerie refusé');
    }
    if (it.isVideo) {
      await Gal.putVideo(path, album: album);
    } else {
      await Gal.putImage(path, album: album);
    }
    final d = await _dir('saved');
    final target = File('${d.path}/${it.name}');
    if (!target.existsSync()) await File(path).copy(target.path);
  }

  Future<List<StatusItem>> listSaved() => _listLocal('saved');

  Future<void> deleteLocal(StatusItem it) async {
    final f = File(it.localPath ?? it.id);
    if (f.existsSync()) await f.delete();
  }

  // -------------------------------------------------------- Import (iOS)
  Future<List<StatusItem>> listImported() => _listLocal('imported');

  Future<int> importFiles() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.media, allowMultiple: true);
    if (res == null) return 0;
    final d = await _dir('imported');
    var n = 0;
    for (final f in res.files) {
      final p = f.path;
      if (p == null) continue;
      final name = '${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      await File(p).copy('${d.path}/$name');
      n++;
    }
    return n;
  }

  Future<List<StatusItem>> _listLocal(String folder) async {
    final d = await _dir(folder);
    final files = d.listSync().whereType<File>().toList();
    final items = files.map((f) {
      final name = f.uri.pathSegments.last;
      final ext = name.split('.').last.toLowerCase();
      return StatusItem(
        id: f.path,
        localPath: f.path,
        name: name,
        kind: _videoExt.contains(ext) ? MediaKind.video : MediaKind.image,
        modified: f.lastModifiedSync(),
        size: f.lengthSync(),
      );
    }).toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  // ------------------------------------------------------------ Réglages
  Future<bool> get autoSave async => (await prefs).getBool('auto_save') ?? false;
  Future<void> setAutoSave(bool v) async => (await prefs).setBool('auto_save', v);

  Future<WaApp> get lastApp async =>
      (await prefs).getString('last_app') == 'business'
          ? WaApp.business
          : WaApp.whatsapp;
  Future<void> setLastApp(WaApp a) async =>
      (await prefs).setString('last_app', a.name);
}
