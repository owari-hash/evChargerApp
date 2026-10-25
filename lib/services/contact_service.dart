import '../models/contact_info.dart';
import 'api_client.dart';

class ContactService {
  ContactService({ApiClient? client}) : _client = client ?? ApiClient.shared;

  static final ContactService instance = ContactService();

  final ApiClient _client;
  ContactInfo? _cached;

  ContactInfo get current => _cached ?? ContactInfo.defaults;

  Future<ContactInfo> load() async {
    try {
      final Map<String, dynamic> res = await _client.get('/app/contact');
      _cached = ContactInfo.fromJson(res);
      return _cached!;
    } catch (_) {
      return _cached ?? ContactInfo.defaults;
    }
  }
}
