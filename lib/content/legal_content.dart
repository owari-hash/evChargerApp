import '../utils/app_strings.dart';

/// The terms of service and the privacy notice, shown in the sign-up sheet.
///
/// Word for word the same as `/legal/terms` and `/legal/privacy` on the kiosk
/// website (`terms` and `privacy` in evChargerKiosk's
/// `src/lib/i18n/dictionaries.ts`). Change the two together.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.intro,
    required this.sections,
    this.draftTitle = '',
    this.draftBody = '',
    this.storedTitle = '',
    this.stored = const <LegalItem>[],
  });

  final String title;
  final String intro;
  final String draftTitle;
  final String draftBody;
  final String storedTitle;
  final List<LegalItem> stored;
  final List<LegalSection> sections;
}

/// One stored field in the privacy notice.
class LegalItem {
  const LegalItem(this.title, this.body);

  final String title;
  final String body;
}

class LegalSection {
  const LegalSection(
    this.heading, {
    this.paragraphs = const <String>[],
    this.bullets = const <String>[],
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

/// The operator named in the documents, as in the website footer.
const String kLegalBrand = 'Жиркто ХХК';

abstract final class LegalContent {
  static LegalDocument terms(AppLanguage language) =>
      language == AppLanguage.mn ? _termsMn : _termsEn;

  static LegalDocument privacy(AppLanguage language) =>
      language == AppLanguage.mn ? _privacyMn : _privacyEn;
}

const LegalDocument _termsEn = LegalDocument(
  draftTitle: 'Draft — not yet legally binding',
  draftBody:
      'This is placeholder text written to give the app a complete set of pages. It must be replaced by the operator’s own terms of service, reviewed by a lawyer, before the service is opened to the public.',
  title: 'Terms of service',
  intro:
      'The rules for using the $kLegalBrand website and the charging network it describes.',
  sections: <LegalSection>[
    LegalSection(
      'About this service',
      paragraphs: <String>[
        '$kLegalBrand is a website that shows the charge points of a charging network, their live availability and their tariffs, and lets a driver keep an account so that charging sessions can be listed in one place. The charge points themselves are owned and run by the network operator.',
        'Using this site does not create a charging contract on its own. What you owe for a charge, and to whom, is governed by the arrangement you have with the operator.',
      ],
    ),
    LegalSection(
      'Your account',
      paragraphs: <String>[
        'You sign in with your mobile number, confirmed by a one-time SMS code, and a 4-digit PIN you choose. Keep your PIN to yourself; anyone who has it and your number can see your charging history and spend your wallet balance. Tell the operator promptly if you think someone else has access.',
        'One account is for one person. You may link the identifiers of charge tags that belong to you. Do not link a tag that is not yours: doing so would expose another driver’s sessions to you and may be treated as misuse.',
      ],
    ),
    LegalSection(
      'Using a charge point',
      paragraphs: <String>[
        'Follow the instructions displayed on the unit and any site rules where it stands. Do not use equipment that appears damaged. Do not attempt to open, modify or interfere with a charge point, and do not obstruct a charging bay when you are not charging.',
        'You are responsible for your vehicle and its charging equipment, and for whether a particular plug and power level are suitable for it.',
      ],
    ),
    LegalSection(
      'Availability and accuracy',
      paragraphs: <String>[
        'Availability, plug status and tariffs are shown as the charging network last reported them. A charge point that has lost contact with the network is marked offline and its plug status is not known. Information may be out of date or incomplete, and a charge point may be occupied or out of service by the time you arrive.',
        'The service is provided as it stands. It may be interrupted for maintenance, and features may change or be withdrawn.',
      ],
    ),
    LegalSection(
      'Prices, wallet and payment',
      paragraphs: <String>[
        'Each charge point has its own price per kilowatt-hour, set by the operator, as described on the pricing page.',
        'A wallet is a prepaid balance held in your name. It is topped up through QPay, in your own banking app; this site never receives or stores your card details. The cost of a completed charging session is deducted from that balance, and every movement is listed in your wallet history.',
        'If a session costs more than the balance available, the shortfall is recorded against the wallet and settled by your next top-up. A wallet balance is not transferable and carries no interest. Refunds are handled by the operator.',
      ],
    ),
    LegalSection(
      'Acceptable use',
      paragraphs: <String>[
        'Do not attempt to gain access to accounts or systems that are not yours, scrape or overload the service, or use it to break the law. Automated access to the site’s interfaces is rate limited and may be blocked.',
      ],
    ),
    LegalSection(
      'Liability',
      paragraphs: <String>[
        '[Placeholder — the operator’s own limitation of liability, warranty and indemnity wording belongs here, drafted to the law that applies to the operator. Nothing in this draft should be relied on as a limitation of liability.]',
      ],
    ),
    LegalSection(
      'Ending your access',
      paragraphs: <String>[
        'You may stop using the service at any time. The operator may suspend an account that is being used in breach of these terms or in a way that endangers people or equipment. Ask the operator about any remaining wallet balance before you close an account.',
      ],
    ),
    LegalSection(
      'Changes to these terms',
      paragraphs: <String>[
        'These terms may change. The version published on this page is the one that applies. Where a change materially affects you, the operator should tell you before it takes effect.',
      ],
    ),
    LegalSection(
      'Governing law and contact',
      paragraphs: <String>[
        '[Placeholder — the operator must state the governing law, the competent courts, the legal entity behind the service, its registered address and a contact address for legal notices.]',
      ],
    ),
  ],
);

const LegalDocument _termsMn = LegalDocument(
  title: 'Үйлчилгээний нөхцөл',
  intro:
      '$kLegalBrand вэбсайт болон түүнд тодорхойлсон цэнэглэх сүлжээг ашиглах журам.',
  sections: <LegalSection>[
    LegalSection(
      'Энэ үйлчилгээний тухай',
      paragraphs: <String>[
        '$kLegalBrand нь цэнэглэх сүлжээний цэнэглэх цэгүүд, тэдгээрийн сул байдал, тарифыг харуулж, жолоочид цэнэглэлтээ нэг дор жагсаах бүртгэл хөтлөх боломж олгодог вэбсайт юм. Цэнэглэх цэгүүд өөрсдөө сүлжээний операторын мэдэлд байдаг.',
        'Энэ сайтыг ашиглах нь өөрөө цэнэглэлтийн гэрээ үүсгэхгүй. Цэнэглэлтийн төлбөрийг хэнд, хэр хэмжээгээр төлөх нь операторт эсэхтэй байгуулсан тохиролцоогоор зохицуулагдана.',
      ],
    ),
    LegalSection(
      'Таны бүртгэл',
      paragraphs: <String>[
        'Та SMS-ээр ирсэн нэг удаагийн кодоор баталгаажуулсан гар утасны дугаар болон өөрийн сонгосон 4 оронтой PIN кодоор нэвтэрнэ. PIN кодоо бусдад бүү хэл; түүнийг болон таны дугаарыг мэдсэн хүн таны цэнэглэлтийн түүхийг харж, хэтэвчний үлдэгдлийг зарцуулж чадна. Хэн нэгэн нэвтэрсэн гэж бодож байвал операторт нэн даруй мэдэгдэнэ үү.',
        'Нэг бүртгэл нэг хүнд зориулагдана. Та зөвхөн өөрийн цэнэглэх картуудын дугаарыг холбож болно. Өөрийнх биш картыг бүү холбоорой: ингэснээр өөр жолоочийн цэнэглэлт танд харагдах бөгөөд буруу ашигласанд тооцогдож болно.',
      ],
    ),
    LegalSection(
      'Цэнэглэх цэг ашиглах',
      paragraphs: <String>[
        'Төхөөрөмж дээр харагдах заавар болон тухайн байршлын дүрмийг дагана уу. Гэмтэлтэй харагдаж буй тоног төхөөрөмжийг бүү ашиглаарай. Цэнэглэх цэгийг задлах, өөрчлөх, саад учруулах гэж бүү оролдоорой, мөн цэнэглээгүй үедээ цэнэглэх байрыг бүү хаагаарай.',
        'Та өөрийн тээврийн хэрэгсэл болон түүний цэнэглэх төхөөрөмжийн төлөө, мөн тухайн холбогч, хүчин чадал түүнд тохирох эсэхийг тодорхойлох үүрэгтэй.',
      ],
    ),
    LegalSection(
      'Хүртээмж ба үнэн зөв байдал',
      paragraphs: <String>[
        'Сул байдал, холбогчийн төлөв, тарифыг цэнэглэх сүлжээнээс хамгийн сүүлд мэдээлсэн байдлаар харуулна. Сүлжээтэй холбоо тасарсан цэнэглэх цэгийг «холбогдоогүй» гэж тэмдэглэх бөгөөд холбогчийн төлөв нь тодорхойгүй байна. Мэдээлэл хуучирсан эсвэл дутуу байж болох ба та очиход цэнэглэх цэг завгүй эсвэл ажиллагаагүй байж магадгүй.',
        'Үйлчилгээг байгаа байдлаар нь үзүүлнэ. Засвар үйлчилгээний улмаас тасалдаж, боломжууд өөрчлөгдөх буюу зогсох магадлалтай.',
      ],
    ),
    LegalSection(
      'Үнэ, хэтэвч ба төлбөр',
      paragraphs: <String>[
        'Цэнэглэх цэг бүр операторынхоо тогтоосон киловатт-цагийн үнэтэй байдаг бөгөөд үүнийг үнэ тарифын хуудсанд тайлбарласан болно.',
        'Хэтэвч гэдэг нь таны нэр дээр байрлах урьдчилсан төлбөрийн үлдэгдэл юм. Үүнийг QPay-ээр, таны банкны апп дотор цэнэглэдэг; энэ сайт таны картын мэдээллийг хэзээ ч хүлээн авахгүй, хадгалахгүй. Дууссан цэнэглэлтийн төлбөрийг тэр үлдэгдлээс суутгах бөгөөд хөдөлгөөн бүрийг хэтэвчийн түүхэнд бүртгэнэ.',
        'Цэнэглэлтийн төлбөр боломжит үлдэгдлээс давбал дутуу дүнг хэтэвчинд бүртгэж, дараагийн цэнэглэлтээр төлүүлнэ. Хэтэвчний үлдэгдлийг бусдад шилжүүлэх боломжгүй бөгөөд хүү тооцохгүй. Буцаалтыг оператор шийдвэрлэнэ.',
      ],
    ),
    LegalSection(
      'Зөвшөөрөгдөх хэрэглээ',
      paragraphs: <String>[
        'Өөрийнх бус бүртгэл, системд нэвтрэх гэж оролдох, үйлчилгээг хуулбарлах эсвэл хэт ачаалах, хууль зөрчихөд ашиглахыг хориглоно. Сайтын интерфэйс рүү автоматаар хандахыг хязгаарладаг бөгөөд хаагдаж болно.',
      ],
    ),
    LegalSection(
      'Хариуцлага',
      paragraphs: <String>[
        '[Түр бичвэр — операторт хамаарах хуулийн дагуу боловсруулсан хариуцлагын хязгаарлалт, баталгаа, нөхөн төлбөрийн заалт энд орно. Энэ төсөлд байгаа зүйлийг хариуцлагын хязгаарлалт гэж үзэж болохгүй.]',
      ],
    ),
    LegalSection(
      'Хандалтыг зогсоох',
      paragraphs: <String>[
        'Та үйлчилгээг ашиглахаа хэдийд ч зогсоож болно. Энэхүү нөхцөлийг зөрчсөн эсвэл хүн, тоног төхөөрөмжид аюул учруулахаар ашиглаж буй бүртгэлийг оператор түдгэлзүүлж болно. Бүртгэлээ хаахаасаа өмнө хэтэвчинд үлдсэн үлдэгдлийн талаар операторт хандана уу.',
      ],
    ),
    LegalSection(
      'Нөхцөлийн өөрчлөлт',
      paragraphs: <String>[
        'Энэхүү нөхцөл өөрчлөгдөж болно. Энэ хуудсанд нийтлэгдсэн хувилбар хүчинтэй байна. Өөрчлөлт танд ноцтой нөлөөлөх тохиолдолд оператор хүчин төгөлдөр болохоос өмнө танд мэдэгдэх ёстой.',
      ],
    ),
    LegalSection(
      'Хамаарах хууль ба холбоо барих',
      paragraphs: <String>[
        '[Түр бичвэр — оператор хамаарах хууль, эрх бүхий шүүх, үйлчилгээг эрхлэгч хуулийн этгээд, түүний бүртгэлтэй хаяг болон эрх зүйн мэдэгдэл хүлээн авах хаягаа заах ёстой.]',
      ],
    ),
  ],
);

const LegalDocument _privacyEn = LegalDocument(
  draftTitle: 'Draft — not yet a legal notice',
  draftBody:
      'This is placeholder text written so the app has a complete set of pages. It describes accurately what the software stores, but it must be replaced by the operator’s own privacy notice, reviewed by a lawyer, before the service is opened to the public.',
  title: 'Privacy notice',
  intro: 'What $kLegalBrand stores about you, why, and what you can do about it.',
  storedTitle: 'What is stored',
  stored: <LegalItem>[
    LegalItem(
      'Name (optional)',
      'Only if you add one on your account page. Used to address you in the interface.',
    ),
    LegalItem(
      'Email address (optional)',
      'Only if you add one. Used to send charging receipts and the link that confirms the address. Stored in lower case.',
    ),
    LegalItem(
      'Phone number',
      'Your sign-in identifier. Stored in international format so it can be matched reliably, and used to send a six-digit code when you sign up, verify the number or reset your PIN.',
    ),
    LegalItem(
      'PIN hash',
      'Your PIN is never stored. What is kept is a bcrypt hash of it, from which the PIN cannot be recovered, and a count of recent wrong attempts used to lock the account against guessing.',
    ),
    LegalItem(
      'Linked charge tag identifiers',
      'The identifiers of the RFID cards or fobs you have linked to the account. They are what lets the app find the charging sessions that belong to you, and what ties a charge to your wallet.',
    ),
    LegalItem(
      'Account state',
      'Whether your email and phone have been verified, your language preference, whether the account is active, when it was created and when you last signed in.',
    ),
    LegalItem(
      'Verification and reset tokens',
      'While a reset link or a one-time code is outstanding we store a hash of it, the address it was sent to, its expiry time and how many times it has been tried. The token itself is not kept.',
    ),
    LegalItem(
      'Wallet balance and ledger',
      'Your prepaid balance and every movement against it — top-ups, charges, refunds and corrections — with the amount, the time and what it referred to. Held by the charging network, not in this app’s database. No card or bank details are stored anywhere in this system: a top-up is authorised entirely inside your banking app, and QPay tells us only that an invoice was paid.',
    ),
    LegalItem(
      'Charging session records',
      'Start and stop time, charge point, connector, charge tag, energy delivered and cost. These are held by the charging network, not by this app: they are fetched for your linked tags when you open your history and are not copied into this app’s database.',
    ),
  ],
  sections: <LegalSection>[
    LegalSection(
      'Why this information is held',
      bullets: <String>[
        'To let you sign in and to keep your account secure.',
        'To send the emails and text messages that the sign-up and reset flows require.',
        'To show you the charging sessions recorded against the charge tags you have linked.',
        'To hold your prepaid balance and settle the cost of a completed charging session against it.',
        'To rate limit sign-in, reset and top-up attempts so accounts cannot be attacked in bulk.',
      ],
    ),
    LegalSection(
      'Where it is stored',
      paragraphs: <String>[
        'Driver accounts live in the operator’s MongoDB database, in collections of their own, separate from the operator’s own staff accounts. In development the app can fall back to a JSON file on the developer’s machine instead; that fallback is disabled in production.',
        'Charging records and wallet balances live in the charging network’s own database. This app reads them over a server-to-server connection; your browser never talks to the charging network directly.',
      ],
    ),
    LegalSection(
      'Cookies',
      paragraphs: <String>[
        'Two cookies are used. A session cookie is set only after you sign in: it holds a signed token, is marked HttpOnly so page scripts cannot read it, is restricted to same-site navigation, and is sent only over HTTPS in production. A second cookie records your language choice; it holds nothing but the language code and is readable by the page.',
        'There are no advertising or analytics cookies on this site. Map tiles are loaded from a third-party tile server, which will see your IP address.',
      ],
    ),
    LegalSection(
      'Who it is shared with',
      paragraphs: <String>[
        'Your charge tag identifiers are sent to the charging network in order to look up your sessions and your balance. Your email address is passed to the mail server the operator has configured, and your phone number to the SMS gateway, purely to deliver the messages you have asked for.',
        'When you top up, the amount and an invoice reference are sent to QPay so it can create the payment. QPay may also receive the phone number or email on your account as the invoice reference.',
        'Nothing is sold, and nothing is shared for advertising. [Placeholder — the operator must name the actual mail and SMS providers used, and any hosting provider, before launch.]',
      ],
    ),
    LegalSection(
      'How long it is kept',
      paragraphs: <String>[
        'Account information is kept while the account exists. SMS codes expire after 10 minutes, the step after a correct code must be finished within 15 minutes, and email verification links expire after 24 hours; expired tokens are no longer usable. Wallet ledger entries are financial records and are kept for as long as the operator’s accounting obligations require. [Placeholder — the operator must state its own retention period for closed accounts and for charging records.]',
      ],
    ),
    LegalSection(
      'Your choices',
      paragraphs: <String>[
        'You can change your name, email address and language, and add or remove charge tags, from your account. A new phone number is confirmed with an SMS code before it replaces the old one. Removing a tag stops its sessions being shown to you; it does not delete the network’s record of them.',
        'Closing an account is not yet self-service in this app — contact the operator to have it done, and to ask about any remaining wallet balance. [Placeholder — the operator must set out the access, correction, deletion and complaint rights that apply in its jurisdiction, and who to contact to exercise them.]',
      ],
    ),
  ],
);

const LegalDocument _privacyMn = LegalDocument(
  draftTitle: 'Төсөл — хараахан албан ёсны мэдэгдэл бус',
  draftBody:
      'Энэ бол аппад бүрэн хуудсууд байлгах зорилгоор бичсэн түр бичвэр юм. Программ юу хадгалдгийг үнэн зөв тайлбарласан боловч үйлчилгээг олон нийтэд нээхээс өмнө операторын өөрийн, хуульчаар хянуулсан нууцлалын бодлогоор солих ёстой.',
  title: 'Нууцлалын бодлого',
  intro: '$kLegalBrand таны талаар юу, яагаад хадгалдаг, та юу хийж болох тухай.',
  storedTitle: 'Юу хадгалагддаг вэ',
  stored: <LegalItem>[
    LegalItem(
      'Нэр (заавал биш)',
      'Зөвхөн та бүртгэлийн хуудсандаа нэмсэн тохиолдолд. Интерфэйс дээр танд хандахад ашиглана.',
    ),
    LegalItem(
      'И-мэйл хаяг (заавал биш)',
      'Зөвхөн та нэмсэн тохиолдолд. Цэнэглэлтийн баримт болон хаягийг баталгаажуулах холбоос илгээхэд ашиглана. Жижиг үсгээр хадгалагдана.',
    ),
    LegalItem(
      'Утасны дугаар',
      'Таны нэвтрэх нэр. Найдвартай тааруулах боломжтой байхаар олон улсын форматаар хадгалж, бүртгүүлэх, дугаараа баталгаажуулах эсвэл PIN кодоо сэргээхэд 6 оронтой код илгээхэд ашиглана.',
    ),
    LegalItem(
      'PIN кодын хэш',
      'Таны PIN кодыг хэзээ ч хадгалдаггүй. Зөвхөн bcrypt хэш болон таах оролдлогоос хамгаалж бүртгэлийг түгжихэд ашигладаг сүүлийн буруу оролдлогын тоог хадгална; хэшээс PIN кодыг сэргээх боломжгүй.',
    ),
    LegalItem(
      'Холбосон цэнэглэх картын дугаарууд',
      'Таны бүртгэлд холбосон RFID карт эсвэл оосорны дугаарууд. Эдгээр нь танд хамаарах цэнэглэлтийг олох, мөн цэнэглэлтийг таны хэтэвчтэй холбох үндэс болно.',
    ),
    LegalItem(
      'Бүртгэлийн төлөв',
      'И-мэйл, утас баталгаажсан эсэх, сонгосон хэл, бүртгэл идэвхтэй эсэх, хэзээ үүсгэсэн, хамгийн сүүлд хэзээ нэвтэрсэн зэрэг.',
    ),
    LegalItem(
      'Баталгаажуулах ба сэргээх кодууд',
      'Сэргээх холбоос эсвэл нэг удаагийн код хүчинтэй байх хугацаанд бид түүний хэш, илгээсэн хаяг, дуусах хугацаа, хэдэн удаа оролдсоныг хадгална. Код өөрөө хадгалагдахгүй.',
    ),
    LegalItem(
      'Хэтэвчний үлдэгдэл ба хөдөлгөөн',
      'Таны урьдчилсан төлбөрийн үлдэгдэл болон түүн дээрх хөдөлгөөн бүр — цэнэглэлт, төлбөр, буцаалт, тохируулга — дүн, хугацаа, юунд хамаарахын хамт. Үүнийг цэнэглэх сүлжээ хадгалдаг бөгөөд энэ аппын мэдээллийн санд байхгүй. Энэ системд карт, банкны мэдээллийг хаана ч хадгалдаггүй: цэнэглэлтийг бүхэлд нь таны банкны апп дотор зөвшөөрөх бөгөөд QPay бидэнд зөвхөн нэхэмжлэх төлөгдсөнийг мэдэгддэг.',
    ),
    LegalItem(
      'Цэнэглэлтийн бүртгэл',
      'Эхэлсэн, дууссан хугацаа, цэнэглэх цэг, холбогч, цэнэглэх карт, өгсөн эрчим хүч, төлбөр. Эдгээрийг энэ апп биш, цэнэглэх сүлжээ хадгалдаг: та түүхээ нээхэд холбосон картуудад тань хамаарахыг нь татаж авах бөгөөд энэ аппын мэдээллийн санд хуулж авдаггүй.',
    ),
  ],
  sections: <LegalSection>[
    LegalSection(
      'Энэ мэдээллийг яагаад хадгалдаг вэ',
      bullets: <String>[
        'Таныг нэвтрүүлэх, бүртгэлийг тань аюулгүй байлгах.',
        'Бүртгүүлэх, сэргээх үйл явцад шаардлагатай и-мэйл, мессежийг илгээх.',
        'Таны холбосон цэнэглэх картуудад бүртгэгдсэн цэнэглэлтийг харуулах.',
        'Таны урьдчилсан төлбөрийн үлдэгдлийг хадгалж, дууссан цэнэглэлтийн төлбөрийг түүнээс тооцох.',
        'Бүртгэлийг бөөнөөр халдлагад өртөхөөс сэргийлж нэвтрэх, сэргээх, цэнэглэх оролдлогыг хязгаарлах.',
      ],
    ),
    LegalSection(
      'Хаана хадгалагддаг вэ',
      paragraphs: <String>[
        'Жолоочийн бүртгэл нь операторын MongoDB мэдээллийн санд, операторын өөрийн ажилтнуудын бүртгэлээс тусдаа коллекцод байрлана. Хөгжүүлэлтийн үед апп хөгжүүлэгчийн компьютер дээрх JSON файлыг ашиглаж болох ба энэ нь продакшнд идэвхгүй байна.',
        'Цэнэглэлтийн бүртгэл болон хэтэвчний үлдэгдэл нь цэнэглэх сүлжээний өөрийн мэдээллийн санд байрлана. Энэ апп тэдгээрийг сервер хоорондын холболтоор уншдаг; таны хөтөч цэнэглэх сүлжээтэй шууд харьцдаггүй.',
      ],
    ),
    LegalSection(
      'Күүки',
      paragraphs: <String>[
        'Хоёр күүки ашиглана. Сешн күүкийг зөвхөн нэвтэрсний дараа тохируулна: энэ нь гарын үсэгтэй токен агуулах бөгөөд хуудасны скрипт уншиж чадахгүйгээр HttpOnly гэж тэмдэглэгдсэн, зөвхөн ижил сайтын шилжилтэд хязгаарлагдсан, продакшнд зөвхөн HTTPS-ээр илгээгдэнэ. Хоёр дахь күүки таны хэлний сонголтыг хадгалах бөгөөд зөвхөн хэлний код агуулна.',
        'Энэ сайтад сурталчилгаа, аналитикийн күүки байхгүй. Газрын зургийн хэсгүүдийг гуравдагч талын сервертэй ачаалдаг бөгөөд тэр нь таны IP хаягийг харна.',
      ],
    ),
    LegalSection(
      'Хэнтэй хуваалцдаг вэ',
      paragraphs: <String>[
        'Таны цэнэглэлт, үлдэгдлийг хайхын тулд цэнэглэх картын дугаарыг тань цэнэглэх сүлжээ рүү илгээнэ. Таны хүссэн мессежийг хүргэх зорилгоор л и-мэйл хаягийг тань операторын тохируулсан мэйл сервер рүү, утасны дугаарыг тань SMS гарц руу дамжуулна.',
        'Та хэтэвчээ цэнэглэхэд төлбөрийг үүсгэхийн тулд дүн болон нэхэмжлэхийн дугаарыг QPay руу илгээнэ. QPay нэхэмжлэхийн лавлагаа болгож таны бүртгэл дэх утасны дугаар эсвэл и-мэйлийг мөн хүлээн авч болно.',
        'Ямар ч мэдээллийг зардаггүй, сурталчилгааны зорилгоор хуваалцдаггүй. [Түр бичвэр — оператор нээхээсээ өмнө ашиглаж буй мэйл, SMS үйлчилгээ үзүүлэгч болон хостинг үйлчилгээ үзүүлэгчийг нэрлэх ёстой.]',
      ],
    ),
    LegalSection(
      'Хэр удаан хадгалагддаг вэ',
      paragraphs: <String>[
        'Бүртгэлийн мэдээллийг бүртгэл байх хугацаанд хадгална. SMS код 10 минутын дараа, и-мэйл баталгаажуулах холбоос 24 цагийн дараа хүчингүй болно; зөв код оруулсны дараах алхмыг 15 минутын дотор дуусгана. Хэтэвчний хөдөлгөөний бүртгэл нь санхүүгийн бичиг баримт тул операторын нягтлан бодох бүртгэлийн үүрэг шаардсан хугацаанд хадгалагдана. [Түр бичвэр — оператор хаагдсан бүртгэл болон цэнэглэлтийн бүртгэлийн хадгалах хугацаагаа заах ёстой.]',
      ],
    ),
    LegalSection(
      'Таны сонголт',
      paragraphs: <String>[
        'Та нэр, и-мэйл хаяг, хэлээ өөрчлөх, цэнэглэх карт нэмэх, хасахыг бүртгэлээсээ хийж болно. Шинэ утасны дугаарыг SMS кодоор баталгаажуулсны дараа солино. Карт хасахад түүний цэнэглэлт танд харагдахаа болих боловч сүлжээнд байгаа бүртгэл нь устахгүй.',
        'Бүртгэл хаах нь энэ аппад хараахан өөрөө хийх боломжгүй байна — операторт хандаж хаалгах, мөн хэтэвчинд үлдсэн үлдэгдлийн талаар асууна уу. [Түр бичвэр — оператор өөрийн харьяалагдах хууль зүйн орчинд үйлчлэх хандах, засах, устгах, гомдол гаргах эрх болон хэнд хандахыг тодорхойлох ёстой.]',
      ],
    ),
  ],
);
