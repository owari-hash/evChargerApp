/// A signed-in driver, mirroring the `PublicUser` the driver API returns from
/// `/app-api/auth/login`, `/register` and `/me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.idTags = const <String>[],
    this.locale = 'mn',
    this.createdAt,
    this.lastLoginAt,
  });

  final String id;
  final String email;
  final String name;

  /// E.164, e.g. `+97699118844`. Optional: an account can be created with an
  /// address alone, in which case signing in by phone is not available.
  final String? phone;

  final bool emailVerified;
  final bool phoneVerified;

  /// RFID tags this driver can start a session with.
  final List<String> idTags;

  final String locale;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  /// First name, for greeting the driver. Falls back to the address' local part
  /// so the greeting is never empty.
  String get displayName {
    final String trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed.split(RegExp(r'\s+')).first;
    return email.split('@').first;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: _stringOrNull(json['phone']),
      emailVerified: json['emailVerified'] == true,
      phoneVerified: json['phoneVerified'] == true,
      idTags: (json['idTags'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic tag) => tag.toString())
          .toList(growable: false),
      locale: (json['locale'] ?? 'mn').toString(),
      createdAt: _dateOrNull(json['createdAt']),
      lastLoginAt: _dateOrNull(json['lastLoginAt']),
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _dateOrNull(dynamic value) {
    final String? text = _stringOrNull(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}
