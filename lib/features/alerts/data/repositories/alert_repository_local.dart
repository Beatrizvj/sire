import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/sos_alert.dart';
import '../../domain/repositories/alert_repository.dart';
import '../models/sos_alert_model.dart';

/// Implementación local de [AlertRepository] usando shared_preferences.
///
/// Suficiente para probar en el dispositivo sin backend. En el Hito 3 se
/// sustituye por una implementación con Cloud Firestore.
class AlertRepositoryLocal implements AlertRepository {
  const AlertRepositoryLocal(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'sire_alerts';

  @override
  Future<List<SosAlert>> getAlerts() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return SosAlertModel.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveAlert(SosAlert alert) async {
    final current = await getAlerts();
    final updated = [alert, ...current];
    await _prefs.setString(_key, SosAlertModel.encodeList(updated));
  }

  @override
  Future<void> clear() => _prefs.remove(_key);
}
