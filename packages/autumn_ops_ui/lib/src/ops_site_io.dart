import 'dart:io';

import 'package:autumn_ops/autumn_ops.dart';
import 'package:path_provider/path_provider.dart';

Future<OpsSiteStore> openOpsSiteStore() async {
  final dir = await getApplicationSupportDirectory();
  return OpsSiteStore(Directory('${dir.path}/autumn_ops'));
}
