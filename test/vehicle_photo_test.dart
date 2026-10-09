import 'package:evchargerapp/services/vehicle_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _search(List<Map<String, dynamic>> pages) =>
    <String, dynamic>{
      'query': <String, dynamic>{'pages': pages},
    };

void main() {
  group('searchQuery', () {
    test('joins brand and model', () {
      expect(VehiclePhotoService.searchQuery('BYD', 'atto 3'), 'BYD atto 3');
    });

    test('does not repeat a brand typed into the model too', () {
      expect(
        VehiclePhotoService.searchQuery('BYD', 'BYD Atto 3'),
        'BYD Atto 3',
      );
    });

    test('needs a model: a brand alone finds a logo, not the car', () {
      expect(VehiclePhotoService.searchQuery('Tesla', ''), '');
      expect(VehiclePhotoService.searchQuery(null, null), '');
    });
  });

  group('titleCandidates', () {
    test(
      'tries the name as typed, title-cased, and with the brand as an acronym',
      () {
        expect(VehiclePhotoService.titleCandidates('byd', 'atto 1'), <String>[
          'byd atto 1',
          'Byd Atto 1',
          'BYD Atto 1',
        ]);
      },
    );

    test('collapses duplicates', () {
      expect(VehiclePhotoService.titleCandidates('Tesla', 'Model Y'), <String>[
        'Tesla Model Y',
      ]);
    });
  });

  group('pickTitleImage', () {
    test('follows a redirect to the article the name is filed under', () {
      // "BYD Atto 1" redirects to "BYD Seagull" on Wikipedia.
      expect(
        VehiclePhotoService.pickTitleImage(<String, dynamic>{
          'query': <String, dynamic>{
            'redirects': <dynamic>[
              <String, dynamic>{'from': 'BYD Atto 1', 'to': 'BYD Seagull'},
            ],
            'pages': <dynamic>[
              <String, dynamic>{'title': 'byd atto 1', 'missing': true},
              <String, dynamic>{
                'title': 'BYD Seagull',
                'pageimage': '2023_BYD_Seagull_(front).jpg',
              },
            ],
          },
        }),
        '2023_BYD_Seagull_(front).jpg',
      );
    });

    test('ignores missing pages and logos', () {
      expect(
        VehiclePhotoService.pickTitleImage(<String, dynamic>{
          'query': <String, dynamic>{
            'pages': <dynamic>[
              <String, dynamic>{'title': 'Foo Bar', 'missing': true},
              <String, dynamic>{'title': 'Acme', 'pageimage': 'Acme_logo.svg'},
            ],
          },
        }),
        isNull,
      );
    });
  });

  group('pickImageName', () {
    test('takes the best-ranked article that names the model', () {
      final String? name = VehiclePhotoService.pickImageName(
        _search(<Map<String, dynamic>>[
          <String, dynamic>{
            'index': 2,
            'title': 'BYD Auto',
            'pageimage': 'BYD_HQ.jpg',
          },
          <String, dynamic>{
            'index': 1,
            'title': 'BYD Atto 3',
            'pageimage': 'BYD_Atto_3.jpg',
          },
        ]),
        'atto 3',
      );
      expect(name, 'BYD_Atto_3.jpg');
    });

    test('skips logos and articles about something else', () {
      expect(
        VehiclePhotoService.pickImageName(
          _search(<Map<String, dynamic>>[
            <String, dynamic>{
              'index': 1,
              'title': 'Tesla Model Y',
              'pageimage': 'Tesla_logo.svg',
            },
            <String, dynamic>{
              'index': 2,
              'title': 'Tesla, Inc.',
              'pageimage': 'Giga.jpg',
            },
          ]),
          'Model Y',
        ),
        isNull,
      );
    });

    test('a partial match is not enough ("Model 3" is not "Model Y")', () {
      expect(
        VehiclePhotoService.pickImageName(
          _search(<Map<String, dynamic>>[
            <String, dynamic>{
              'index': 1,
              'title': 'Tesla Model 3',
              'pageimage': 'M3.jpg',
            },
          ]),
          'Model Y',
        ),
        isNull,
      );
    });
  });

  test('parseImageInfo reads the thumbnail and strips the credit HTML', () {
    final VehiclePhoto?
    photo = VehiclePhotoService.parseImageInfo(<String, dynamic>{
      'query': <String, dynamic>{
        'pages': <Map<String, dynamic>>[
          <String, dynamic>{
            'imageinfo': <Map<String, dynamic>>[
              <String, dynamic>{
                'url': 'https://upload.wikimedia.org/full.jpg',
                'thumburl': 'https://upload.wikimedia.org/1280px.jpg',
                'extmetadata': <String, dynamic>{
                  'Artist': <String, dynamic>{
                    'value':
                        '<a href="//commons.wikimedia.org/wiki/User:X">Alexander Migl</a>',
                  },
                  'LicenseShortName': <String, dynamic>{
                    'value': 'CC BY-SA 4.0',
                  },
                },
              },
            ],
          },
        ],
      },
    });
    expect(photo?.url, 'https://upload.wikimedia.org/1280px.jpg');
    expect(photo?.credit, 'Alexander Migl · CC BY-SA 4.0');
  });
}
