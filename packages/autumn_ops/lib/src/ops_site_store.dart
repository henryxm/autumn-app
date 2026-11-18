import 'dart:convert';
import 'dart:io';

import 'ops_endpoint.dart';
import 'ops_models.dart';
import 'ops_store.dart';

/// One Autumn backend entry in the multi-site list.
class OpsSiteEntry {
  OpsSiteEntry({
    required this.id,
    required this.title,
    required this.baseUrl,
    this.siteId,
    this.certId,
    this.serverFingerprint,
    this.enrolled = false,
  });

  final String id;
  String title;
  String baseUrl;
  String? siteId;
  String? certId;
  String? serverFingerprint;
  bool enrolled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'baseUrl': baseUrl,
        'siteId': siteId,
        'certId': certId,
        'serverFingerprint': serverFingerprint,
        'enrolled': enrolled,
      };

  factory OpsSiteEntry.fromJson(Map<String, dynamic> json) {
    return OpsSiteEntry(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      baseUrl: '${json['baseUrl'] ?? ''}',
      siteId: json['siteId']?.toString(),
      certId: json['certId']?.toString(),
      serverFingerprint: json['serverFingerprint']?.toString(),
      enrolled: json['enrolled'] == true,
    );
  }

  /// Prefer [OpsEndpoint.normalizeBaseUrl] / [OpsEndpoint.resolve] for new input.
  static String normalizeBaseUrl(String u) =>
      OpsEndpoint.normalizeBaseUrl(u);

  static String siteKeyFromBaseUrl(String baseUrl) {
    final n = normalizeBaseUrl(baseUrl).toLowerCase();
    return n.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}

/// Index of sites + per-site credential directories under [rootDir].
class OpsSiteStore {
  OpsSiteStore(this.rootDir);

  final Directory rootDir;

  File get _indexFile => File('${rootDir.path}/sites.json');

  Future<List<OpsSiteEntry>> listSites() async {
    if (!await _indexFile.exists()) {
      return [];
    }
    final raw = await _indexFile.readAsString();
    if (raw.trim().isEmpty) {
      return [];
    }
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => OpsSiteEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveSites(List<OpsSiteEntry> sites) async {
    await rootDir.create(recursive: true);
    await _indexFile.writeAsString(
      jsonEncode(sites.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }

  OpsStore credentialStoreFor(OpsSiteEntry site) {
    final key = OpsSiteEntry.siteKeyFromBaseUrl(site.baseUrl);
    final dir = Directory('${rootDir.path}/$key');
    return OpsStore(File('${dir.path}/credential.json'));
  }

  Future<void> upsertSite(OpsSiteEntry site) async {
    final list = await listSites();
    final i = list.indexWhere((e) => e.id == site.id);
    if (i >= 0) {
      list[i] = site;
    } else {
      list.add(site);
    }
    await saveSites(list);
  }

  Future<void> removeSite(String id) async {
    final list = await listSites();
    OpsSiteEntry? removed;
    list.removeWhere((e) {
      if (e.id == id) {
        removed = e;
        return true;
      }
      return false;
    });
    await saveSites(list);
    if (removed != null) {
      await credentialStoreFor(removed!).clear();
    }
  }

  Future<OpsCredentialBundle?> loadCredential(OpsSiteEntry site) {
    return credentialStoreFor(site).load();
  }

  Future<void> saveCredential(OpsSiteEntry site, OpsCredentialBundle bundle) {
    return credentialStoreFor(site).save(bundle);
  }
}
