class ContactInfo {
  const ContactInfo({
    required this.phone,
    required this.email,
    this.address,
    this.facebookUrl,
    this.facebookName,
    this.instagramUrl,
    this.instagramName,
    this.logoDownloadUrl,
  });

  final String phone;
  final String email;
  final String? address;
  final String? facebookUrl;
  final String? facebookName;
  final String? instagramUrl;
  final String? instagramName;
  final String? logoDownloadUrl;

  static const ContactInfo defaults = ContactInfo(
    phone: '+976 7777 4242, 8888 5516',
    email: 'contact@eplug.mn',
    address: 'Улаанбаатар хот',
    facebookUrl: 'https://facebook.com/eplug.mn',
    facebookName: 'Eplug.mn',
    instagramUrl: 'https://instagram.com/eplug.mn',
    instagramName: 'Eplug.mn',
    logoDownloadUrl: '/eplug-mark.png',
  );

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      phone: (json['phone'] as String?)?.trim() ?? defaults.phone,
      email: (json['email'] as String?)?.trim() ?? defaults.email,
      address: (json['address'] as String?)?.trim(),
      facebookUrl: (json['facebookUrl'] as String?)?.trim(),
      facebookName: (json['facebookName'] as String?)?.trim(),
      instagramUrl: (json['instagramUrl'] as String?)?.trim(),
      instagramName: (json['instagramName'] as String?)?.trim(),
      logoDownloadUrl: (json['logoDownloadUrl'] as String?)?.trim(),
    );
  }
}
