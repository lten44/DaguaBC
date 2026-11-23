import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final exportOutputPickerProvider = Provider((ref) => ExportOutputPicker());

/// Keeps the native modal boundary replaceable in export regression tests.
class ExportOutputPicker {
  static const lastDirectoryKey = 'export_last_directory';

  Future<String?> initialDirectory() async {
    final saved = (await SharedPreferences.getInstance()).getString(lastDirectoryKey);
    return saved != null && await Directory(saved).exists() ? saved : null;
  }

  Future<String?> selectMerged({required String typeLabel, String? initialDirectory}) async {
    final location = await getSaveLocation(
      initialDirectory: initialDirectory,
      suggestedName: 'highlights.mp4',
      acceptedTypeGroups: [XTypeGroup(label: typeLabel, extensions: ['mp4'])],
    );
    return location?.path;
  }

  Future<String?> selectDirectory({required String confirmLabel, String? initialDirectory}) =>
      getDirectoryPath(confirmButtonText: confirmLabel, initialDirectory: initialDirectory);

  Future<String?> mergedPath({required String typeLabel}) async {
    final selected = await selectMerged(typeLabel: typeLabel, initialDirectory: await initialDirectory());
    if (selected != null && selected.isNotEmpty) {
      await (await SharedPreferences.getInstance()).setString(lastDirectoryKey, File(selected).parent.path);
    }
    return selected;
  }

  Future<String?> directory({required String confirmLabel}) async {
    final selected = await selectDirectory(confirmLabel: confirmLabel, initialDirectory: await initialDirectory());
    if (selected != null && selected.isNotEmpty) {
      await (await SharedPreferences.getInstance()).setString(lastDirectoryKey, selected);
    }
    return selected;
  }
}
