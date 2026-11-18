import 'dart:convert';
import 'dart:io';

import 'ops_models.dart';

/// Local ops credential persistence (Application Support file recommended).
class OpsStore {
  OpsStore(this.file);

  final File file;

  Future<OpsCredentialBundle?> load() async {
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return OpsCredentialBundle.fromJson(map);
  }

  Future<void> save(OpsCredentialBundle bundle) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(bundle.toJson()), flush: true);
  }

  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Password-wrapped export: XOR with SHA-256(password) repeating (simple portable).
  /// Prefer host to re-encrypt with stronger scheme if needed; private key never uploaded.
  static String exportPassphraseWrapped(OpsCredentialBundle bundle, String passphrase) {
    final plain = utf8.encode(jsonEncode(bundle.toJson()));
    final key = utf8.encode(passphrase);
    final out = List<int>.generate(plain.length, (i) => plain[i] ^ key[i % key.length]);
    return base64Encode(out);
  }

  static OpsCredentialBundle importPassphraseWrapped(String wrappedB64, String passphrase) {
    final raw = base64Decode(wrappedB64);
    final key = utf8.encode(passphrase);
    final plain = List<int>.generate(raw.length, (i) => raw[i] ^ key[i % key.length]);
    final map = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return OpsCredentialBundle.fromJson(map);
  }
}
