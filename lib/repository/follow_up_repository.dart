import 'package:hive/hive.dart';
import '../model/follow_up.dart';

class FollowUpRepository {
  static const String _boxName = 'followups';
  static FollowUpRepository? _instance;
  FollowUpRepository._();
  static FollowUpRepository get instance =>
      _instance ??= FollowUpRepository._();

  late Box<FollowUp> _box;

  static Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(FollowUpAdapter());
    }
    _instance ??= FollowUpRepository._();
    _instance!._box = await Hive.openBox<FollowUp>(_boxName);
  }

  List<FollowUp> getAll() => _box.values.toList();

  List<FollowUp> getByLead(String leadId) =>
      _box.values.where((f) => f.leadId == leadId).toList();

  List<FollowUp> pending() =>
      _box.values.where((f) => f.status == 'PENDING').toList();

  Future<void> save(FollowUp f) async {
    await _box.put(f.id, f);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
