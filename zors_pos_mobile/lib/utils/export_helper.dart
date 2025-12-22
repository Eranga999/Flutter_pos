import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart'
    as helper;

Future<bool> exportCsv(String filename, String csvContent) {
  // Use web implementation when available; fallback to stub.
  return helper.exportCsv(filename, csvContent);
}
