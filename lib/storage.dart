part of 'main.dart';

/// Partitioned local storage layer (v2).
/// Splits active metadata, income, friend photos, and monthly history buckets into
/// separate keys so routine edits do not re-serialize months of history or photos.
/// Automatically migrates legacy single-blob `sakto-data-v1-<accountId>` records.
class LocalStore {
  static String _legacyKey(String id) => 'sakto-data-v1-$id';
  static String _metaKey(String id) => 'sakto-v2-$id-meta';
  static String _incKey(String id) => 'sakto-v2-$id-inc';
  static String _photosKey(String id) => 'sakto-v2-$id-photos';
  static String _histIndexKey(String id) => 'sakto-v2-$id-hist-index';
  static String _histMonthKey(String id, String ym) => 'sakto-v2-$id-hist-$ym';
  static String _pendingKey(String id) => 'sakto-v2-$id-pending';

  static Future<Map<String, dynamic>?> loadAccount(String accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaRaw = prefs.getString(_metaKey(accountId));
      if (metaRaw != null) {
        final meta = Map<String, dynamic>.from(jsonDecode(metaRaw) as Map);
        final incRaw = prefs.getString(_incKey(accountId));
        if (incRaw != null) meta['inc'] = jsonDecode(incRaw);
        final photosRaw = prefs.getString(_photosKey(accountId));
        if (photosRaw != null) meta['personPhotos'] = jsonDecode(photosRaw);
        final months = prefs.getStringList(_histIndexKey(accountId)) ?? const <String>[];
        final hist = <String, dynamic>{};
        for (final ym in months) {
          final mRaw = prefs.getString(_histMonthKey(accountId, ym));
          if (mRaw != null) {
            final mMap = jsonDecode(mRaw) as Map<String, dynamic>;
            hist.addAll(mMap);
          }
        }
        meta['hist'] = hist;
        return meta;
      }

      // Migrate legacy v1 single-blob storage if present.
      final legacyRaw = prefs.getString(_legacyKey(accountId));
      if (legacyRaw != null) {
        final legacy = jsonDecode(legacyRaw) as Map<String, dynamic>;
        await saveAccount(
          accountId,
          legacy,
          writeInc: true,
          writePhotos: true,
          writeHist: true,
        );
        await prefs.remove(_legacyKey(accountId));
        return legacy;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveAccount(
    String accountId,
    Map<String, dynamic> fullData, {
    bool writeMeta = true,
    bool writeInc = true,
    bool writePhotos = true,
    bool writeHist = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (writeMeta) {
        final meta = Map<String, dynamic>.from(fullData)
          ..remove('inc')
          ..remove('personPhotos')
          ..remove('hist');
        await prefs.setString(_metaKey(accountId), jsonEncode(meta));
      }
      if (writeInc) {
        await prefs.setString(_incKey(accountId), jsonEncode(fullData['inc'] ?? const []));
      }
      if (writePhotos) {
        await prefs.setString(_photosKey(accountId), jsonEncode(fullData['personPhotos'] ?? const {}));
      }
      if (writeHist) {
        final hist = (fullData['hist'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final byMonth = <String, Map<String, dynamic>>{};
        for (final e in hist.entries) {
          final ym = e.key.length >= 7 ? e.key.substring(0, 7) : 'other';
          (byMonth[ym] ??= {})[e.key] = e.value;
        }
        final prevMonths = prefs.getStringList(_histIndexKey(accountId)) ?? const <String>[];
        for (final oldYm in prevMonths) {
          if (!byMonth.containsKey(oldYm)) {
            await prefs.remove(_histMonthKey(accountId, oldYm));
          }
        }
        for (final e in byMonth.entries) {
          await prefs.setString(_histMonthKey(accountId, e.key), jsonEncode(e.value));
        }
        await prefs.setStringList(_histIndexKey(accountId), byMonth.keys.toList()..sort());
      }
    } catch (_) {}
  }

  static Future<void> eraseAccount(String accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyKey(accountId));
      await prefs.remove(_metaKey(accountId));
      await prefs.remove(_incKey(accountId));
      await prefs.remove(_photosKey(accountId));
      await prefs.remove(_pendingKey(accountId));
      final months = prefs.getStringList(_histIndexKey(accountId)) ?? const <String>[];
      for (final ym in months) {
        await prefs.remove(_histMonthKey(accountId, ym));
      }
      await prefs.remove(_histIndexKey(accountId));
    } catch (_) {}
  }

  static Future<bool> isPendingSync(String accountId) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_pendingKey(accountId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPendingSync(String accountId, bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (v) {
        await prefs.setBool(_pendingKey(accountId), true);
      } else {
        await prefs.remove(_pendingKey(accountId));
      }
    } catch (_) {}
  }
}
