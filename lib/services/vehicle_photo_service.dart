import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A real photo of a car model, with the credit its licence requires.
@immutable
class VehiclePhoto {
  const VehiclePhoto({required this.url, this.artist, this.license});

  final String url;

  /// The photographer, as Wikimedia Commons records them.
  final String? artist;

  /// e.g. "CC BY-SA 4.0".
  final String? license;

  /// "Фото: Alexander Migl · CC BY-SA 4.0", or null when nothing is known.
  String? get credit {
    final List<String> parts = <String>[
      if (artist != null && artist!.isNotEmpty) artist!,
      if (license != null && license!.isNotEmpty) license!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Finds a photo of the driver's saved car model on Wikipedia.
///
/// Wikipedia's article for a model nearly always leads with a photo of the
/// car itself, released under a Creative Commons licence, so this needs no API
/// key. Anything doubtful — no article matching the model, a logo instead of
/// a photo, no network — returns null and the dashboard keeps its drawing.
class VehiclePhotoService {
  VehiclePhotoService({http.Client? client})
    : _client = client ?? http.Client();

  static final VehiclePhotoService instance = VehiclePhotoService();

  final http.Client _client;

  /// Lookups already made this run, hits and misses alike.
  final Map<String, VehiclePhoto?> _cache = <String, VehiclePhoto?>{};

  static const Duration _timeout = Duration(seconds: 10);

  /// Wikimedia asks every client to identify itself.
  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'EplugApp/1.0 (contact@eplug.mn)',
    'Api-User-Agent': 'EplugApp/1.0 (contact@eplug.mn)',
  };

  /// Width asked of Wikimedia's thumbnailer — sharp on a 3x phone, far
  /// lighter than the originals, which run to several megabytes.
  static const int photoWidth = 1280;

  Future<VehiclePhoto?> photoFor(String? brand, String? model) async {
    final String query = searchQuery(brand, model);
    if (query.isEmpty) return null;
    if (_cache.containsKey(query)) return _cache[query];

    VehiclePhoto? photo;
    try {
      // An exact title first, following redirects: Wikipedia files many export
      // names under the home-market one ("BYD Atto 1" → "BYD Seagull"),
      // which a title-matching search would reject.
      List<String> files = await _findByTitle(
        titleCandidates(brand, model),
        model!,
      );
      if (files.isEmpty) files = await _findImage(query, model);
      if (files.isNotEmpty) photo = await _describeBest(files);
    } catch (e) {
      // Offline, rate limited, or an unexpected response: the drawing stays.
      debugPrint('Vehicle photo lookup failed: $e');
      return null; // Not cached, so it is tried again next time.
    }
    _cache[query] = photo;
    return photo;
  }

  /// "BYD Atto 3". Empty without a model: a brand alone finds the company's
  /// article, which leads with a logo or a headquarters, not the driver's car.
  static String searchQuery(String? brand, String? model) {
    final String m = (model ?? '').trim();
    if (m.isEmpty) return '';
    final String b = (brand ?? '').trim();
    // Drivers often type the brand into both fields ("BYD", "BYD Atto 3").
    if (b.isEmpty || m.toLowerCase().startsWith(b.toLowerCase())) return m;
    return '$b $m';
  }

  /// The saved name in the capitalisations Wikipedia titles tend to use;
  /// titles and redirects are case-sensitive past the first letter.
  static List<String> titleCandidates(String? brand, String? model) {
    final String query = searchQuery(brand, model);
    if (query.isEmpty) return const <String>[];
    String word(String w) =>
        w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
    final List<String> words = query.split(RegExp(r'\s+'));
    final String titled = words.map(word).join(' ');
    final String b = (brand ?? '').trim();
    // Short brands are usually acronyms: BYD, MG, GAC, BMW.
    final String acronym =
        b.isNotEmpty &&
            b.length <= 4 &&
            titled.toLowerCase().startsWith(b.toLowerCase())
        ? '${b.toUpperCase()}${titled.substring(b.length)}'
        : titled;
    return <String>{query, titled, acronym}.toList(growable: false);
  }

  /// The article's lead photo first, then its other photos of the model.
  Future<List<String>> _findByTitle(List<String> titles, String model) async {
    if (titles.isEmpty) return const <String>[];
    final Uri uri =
        Uri.https('en.wikipedia.org', '/w/api.php', <String, String>{
          'action': 'query',
          'format': 'json',
          'formatversion': '2',
          'origin': '*',
          'redirects': '1',
          'titles': titles.join('|'),
          'prop': 'pageimages|images',
          'piprop': 'name',
          'imlimit': '100',
        });
    final http.Response response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String? lead = pickTitleImage(json);
    if (lead == null) return const <String>[];
    return candidateFiles(_pages(json), lead, model);
  }

  static List<Map<String, dynamic>> _pages(Map<String, dynamic> json) =>
      (((json['query'] as Map<String, dynamic>?)?['pages'] as List<dynamic>?) ??
              const <dynamic>[])
          .cast<Map<String, dynamic>>();

  /// [lead] then the other photos on the same article whose file names name
  /// the model — the alternatives tried when the lead shows a crowd.
  static List<String> candidateFiles(
    List<Map<String, dynamic>> pages,
    String lead,
    String model,
  ) {
    final List<String> tokens = _tokens(model);
    final List<String> out = <String>[lead];
    for (final Map<String, dynamic> page in pages) {
      if (page['pageimage'] != lead) continue;
      for (final dynamic raw
          in (page['images'] as List<dynamic>?) ?? const <dynamic>[]) {
        final String title = (raw as Map<String, dynamic>)['title'] as String;
        final String name = title
            .replaceFirst(RegExp(r'^File:'), '')
            .replaceAll(' ', '_');
        if (!_isPhoto(name) || out.contains(name)) continue;
        final String n = ' ${_normalize(name)} ';
        if (tokens.every((String t) => n.contains(' $t '))) out.add(name);
      }
    }
    // One request describes them all; a dozen is plenty to find a clean one.
    return out.take(12).toList(growable: false);
  }

  /// The photo of whichever candidate title exists, redirects included.
  static String? pickTitleImage(Map<String, dynamic> json) {
    final List<dynamic> pages =
        ((json['query'] as Map<String, dynamic>?)?['pages']
            as List<dynamic>?) ??
        const <dynamic>[];
    for (final dynamic raw in pages) {
      final Map<String, dynamic> page = raw as Map<String, dynamic>;
      if (page['missing'] == true || page['invalid'] == true) continue;
      final String? image = page['pageimage'] as String?;
      if (image != null && _isPhoto(image)) return image;
    }
    return null;
  }

  static bool _isPhoto(String file) =>
      RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(file);

  Future<List<String>> _findImage(String query, String model) async {
    final Uri uri =
        Uri.https('en.wikipedia.org', '/w/api.php', <String, String>{
          'action': 'query',
          'format': 'json',
          'formatversion': '2',
          'origin': '*',
          'generator': 'search',
          'gsrsearch': query,
          'gsrlimit': '3',
          'prop': 'pageimages|images',
          'piprop': 'name',
          'imlimit': '200',
        });
    final http.Response response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String? lead = pickImageName(json, model);
    if (lead == null) return const <String>[];
    return candidateFiles(_pages(json), lead, model);
  }

  /// The image of the best-ranked article whose title names the model.
  ///
  /// Kept apart from the network call so the matching is testable.
  static String? pickImageName(Map<String, dynamic> json, String model) {
    final List<dynamic> pages =
        ((json['query'] as Map<String, dynamic>?)?['pages']
            as List<dynamic>?) ??
        const <dynamic>[];
    final List<Map<String, dynamic>> ranked =
        pages.cast<Map<String, dynamic>>().toList()..sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              ((a['index'] as num?) ?? 99).compareTo(
                (b['index'] as num?) ?? 99,
              ),
        );

    final List<String> tokens = _tokens(model);
    if (tokens.isEmpty) return null;

    for (final Map<String, dynamic> page in ranked) {
      final String? image = page['pageimage'] as String?;
      if (image == null) continue;
      // Logos and diagrams are SVGs; the car itself is a photograph.
      if (!_isPhoto(image)) continue;
      final String title = ' ${_normalize(page['title'] as String? ?? '')} ';
      if (tokens.every((String t) => title.contains(' $t '))) return image;
    }
    return null;
  }

  /// The first of [files] that is a clean shot of the car, described with
  /// its credit — or null when every one shows a crowd, a stand or a cabin.
  Future<VehiclePhoto?> _describeBest(List<String> files) async {
    final Uri uri =
        Uri.https('en.wikipedia.org', '/w/api.php', <String, String>{
          'action': 'query',
          'format': 'json',
          'formatversion': '2',
          'origin': '*',
          'titles': files.map((String f) => 'File:$f').join('|'),
          'prop': 'imageinfo|categories',
          'iiprop': 'url|extmetadata',
          'iiurlwidth': '$photoWidth',
          'iiextmetadatafilter': 'Artist|LicenseShortName',
          'cllimit': 'max',
        });
    final http.Response response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return pickCleanPhoto(
      jsonDecode(response.body) as Map<String, dynamic>,
      files,
    );
  }

  /// Categories that mean the photo is not just the car: people, a show
  /// floor, an exhibition stand, or the inside of the cabin.
  static final RegExp _crowded = RegExp(
    r'\b(people|persons?|men|women|man|woman|children|girls?|boys?|'
    r'visitors?|crowds?|audiences?|spectators?|drivers?|portraits?|'
    r'motor ?shows?|auto ?shows?|car ?shows?|autosalon|salon|salone|'
    r'exhibitions?|expos?|messe|iaa|fairs?|museums?|collections?|'
    r'stands?|booths?|interiors?|dashboards?|steering|cockpits?|seats?)\b',
    caseSensitive: false,
  );

  /// True when none of a file's Commons categories suggests people or a show.
  static bool looksClean(List<String> categories) =>
      !categories.any((String c) => _crowded.hasMatch(c));

  /// Picks from an imageinfo + categories response, in [order].
  static VehiclePhoto? pickCleanPhoto(
    Map<String, dynamic> json,
    List<String> order,
  ) {
    final Map<String, Map<String, dynamic>> byFile =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> page in _pages(json)) {
      final String title = (page['title'] as String? ?? '')
          .replaceFirst(RegExp(r'^File:'), '')
          .replaceAll(' ', '_');
      byFile[title] = page;
    }
    for (final String file in order) {
      final Map<String, dynamic>? page = byFile[file.replaceAll(' ', '_')];
      if (page == null) continue;
      final List<String> categories =
          ((page['categories'] as List<dynamic>?) ?? const <dynamic>[])
              .map(
                (dynamic c) => ((c as Map<String, dynamic>)['title'] as String)
                    .replaceFirst(RegExp(r'^Category:'), ''),
              )
              .toList(growable: false);
      if (!looksClean(categories)) continue;
      final VehiclePhoto? photo = parseImageInfo(<String, dynamic>{
        'query': <String, dynamic>{
          'pages': <dynamic>[page],
        },
      });
      if (photo != null) return photo;
    }
    return null;
  }

  static VehiclePhoto? parseImageInfo(Map<String, dynamic> json) {
    final List<dynamic> pages =
        ((json['query'] as Map<String, dynamic>?)?['pages']
            as List<dynamic>?) ??
        const <dynamic>[];
    if (pages.isEmpty) return null;
    final List<dynamic> info =
        ((pages.first as Map<String, dynamic>)['imageinfo']
            as List<dynamic>?) ??
        const <dynamic>[];
    if (info.isEmpty) return null;
    final Map<String, dynamic> first = info.first as Map<String, dynamic>;
    final String? url = (first['thumburl'] ?? first['url']) as String?;
    if (url == null) return null;

    final Map<String, dynamic> meta =
        (first['extmetadata'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    String? field(String key) {
      final String? raw =
          (meta[key] as Map<String, dynamic>?)?['value'] as String?;
      if (raw == null) return null;
      // Artist arrives as HTML, usually a link to the photographer's page.
      final String text = raw
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return text.isEmpty ? null : text;
    }

    return VehiclePhoto(
      url: url,
      artist: field('Artist'),
      license: field('LicenseShortName'),
    );
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> _tokens(String model) => _normalize(
    model,
  ).split(' ').where((String t) => t.isNotEmpty).toList(growable: false);
}
