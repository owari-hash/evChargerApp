import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DemoDriveScreen extends StatefulWidget {
  const DemoDriveScreen({super.key});

  @override
  State<DemoDriveScreen> createState() => _DemoDriveScreenState();
}

class _DemoDriveScreenState extends State<DemoDriveScreen> {
  String _selectedSeries = 'All Series';
  final List<String> _seriesList = const [
    'All Series',
    'X5 xDrive50e',
    'BMW iM3',
    'M5',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Book A Demo Drive',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkForest,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notes_rounded, color: AppTheme.darkForest, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // Search Input Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search Your Vehicle',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.darkForest),
                filled: true,
                fillColor: AppTheme.cardWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Series Tabs Filter Row
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _seriesList.length,
                itemBuilder: (context, index) {
                  final series = _seriesList[index];
                  final isSelected = series == _selectedSeries;

                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: InkWell(
                      onTap: () => setState(() => _selectedSeries = series),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppTheme.darkForest : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isSelected)
                            Container(
                              width: 32,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: AppTheme.darkForest,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Vehicle Cards List (Matching Screen 4 of reference image)
            _buildVehicleCard(
              title: 'BMW',
              subtitle: 'X5 xDrive50e',
              imageAssetPath: 'assets/images/bmw_x5.jpg',
            ),
            const SizedBox(height: 16),
            _buildVehicleCard(
              title: 'BMW',
              subtitle: '4 Series Gran',
              imageAssetPath: 'assets/images/bmw_x5.jpg',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard({
    required String title,
    required String subtitle,
    required String imageAssetPath,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // BMW M Badge Icon Graphic
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F261B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Text(
                      '///',
                      style: TextStyle(
                        color: Color(0xFFE74C3C),
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkForest,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Vehicle Image Display
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE2EFE7),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imageAssetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.electric_car_rounded,
                      size: 90,
                      color: AppTheme.darkForest,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Demo Drive Booking Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Demo Drive requested for $title $subtitle!'),
                    backgroundColor: AppTheme.darkForest,
                  ),
                );
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: const Text('Book Test Drive'),
            ),
          ),
        ],
      ),
    );
  }
}
