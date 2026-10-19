/// A signed-in driver, mirroring the `PublicUser` the driver API returns from
/// `/app-api/auth/login`, `/auth/signup/complete` and `/auth/me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.hasPin = true,
    this.isInternal = false,
    this.idTags = const <String>[],
    this.locale = 'mn',
    this.createdAt,
    this.lastLoginAt,
    this.vehicleBrand,
    this.vehicleModel,
    this.pendingGuides = const <String>[],
  });

  final String id;
  final String name;

  /// Optional: accounts are created with a phone number and a PIN alone.
  final String? email;

  /// E.164, e.g. `+97699118844` — the number the driver signs in with.
  final String? phone;

  final bool emailVerified;
  final bool phoneVerified;

  /// False only for an account from before PIN sign-in that has not set one.
  final bool hasPin;

  /// Whether this driver is an internal user who charges free of charge.
  final bool isInternal;

  /// RFID tags this driver can start a session with.
  final List<String> idTags;

  final String locale;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  /// The vehicle this driver charges — set on the account, not read off OCPP,
  /// so it can be shown next to the station and start time of a live session.
  final String? vehicleBrand;
  final String? vehicleModel;

  /// Walkthroughs this driver has not been through yet: `app` for this app's
  /// guide, `web` for the kiosk website's. New accounts start with both;
  /// accounts from before guides existed, and servers that predate them,
  /// send none.
  final List<String> pendingGuides;

  /// First name, for greeting the driver. Falls back to the address' local
  /// part, then the phone number, so the greeting is never empty.
  String get displayName {
    final String trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed.split(RegExp(r'\s+')).first;
    if (email != null) return email!.split('@').first;
    return phone ?? '';
  }

  /// "Brand Model", either half alone, or null when neither is set.
  String? get vehicleDisplayName {
    final String joined = [
      vehicleBrand,
      vehicleModel,
    ].whereType<String>().map((String s) => s.trim()).where((String s) => s.isNotEmpty).join(' ');
    return joined.isEmpty ? null : joined;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: _stringOrNull(json['email']),
      phone: _stringOrNull(json['phone']),
      emailVerified: json['emailVerified'] == true,
      phoneVerified: json['phoneVerified'] == true,
      // A server from before PIN sign-in does not send it.
      hasPin: json['hasPin'] != false,
      isInternal: json['isInternal'] == true,
      idTags: (json['idTags'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic tag) => tag.toString())
          .toList(growable: false),
      locale: (json['locale'] ?? 'mn').toString(),
      createdAt: _dateOrNull(json['createdAt']),
      lastLoginAt: _dateOrNull(json['lastLoginAt']),
      vehicleBrand: _stringOrNull(json['vehicleBrand']),
      vehicleModel: _stringOrNull(json['vehicleModel']),
      pendingGuides: json['pendingGuides'] is List
          ? (json['pendingGuides'] as List<dynamic>)
                .whereType<Object>()
                .map((Object guide) => guide.toString())
                .toList(growable: false)
          : const <String>[],
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
