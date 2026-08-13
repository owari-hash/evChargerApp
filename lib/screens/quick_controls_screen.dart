import 'package:flutter/material.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import 'mongolia_map_screen.dart';

class QuickControlsScreen extends StatefulWidget {
  const QuickControlsScreen({super.key});

  @override
  State<QuickControlsScreen> createState() => _QuickControlsScreenState();
}

class _QuickControlsScreenState extends State<QuickControlsScreen> {
  final OcppMockService _service = OcppMockService.instance;
  double _climateTemp = 17.0;
  bool _isPlayingMedia = true;

  void _openInteractiveMap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Scaffold(
        backgroundColor: AppTheme.softBg,
        appBar: AppBar(
          title: const Text('Улаанбаатар Цэнэглэх Станцын Газрын Зураг'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: MongoliaMapScreen(
          onOpenQrScanner: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.get('quick_controls'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkForest,
            letterSpacing: -0.5,
          ),
        ),
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
            // Row 1: Energy & Climate
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Energy Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('energy'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkForest,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '11:44 цагт цэнэглэж эхэлсэн',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${_service.targetLimitPct.toInt()}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkForest,
                          ),
                        ),
                        const Text(
                          'Цэнэглэх хязгаар',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 10),
                        // Limit slider badge
                        Container(
                          width: double.infinity,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppTheme.lightSage,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Stack(
                            children: [
                              FractionallySizedBox(
                                widthFactor: _service.targetLimitPct / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.sageGreen,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Хязгаар ${_service.targetLimitPct.toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Climate Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              AppStrings.get('climate'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkForest,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Гадаа агаарын хэм 28°C',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_climateTemp.toInt()}°C',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.darkForest,
                                  ),
                                ),
                                const Text(
                                  'Цонх цоожтой',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.ac_unit_rounded,
                              color: Color(0xFF5DADE2),
                              size: 26,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Temp range bar
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('08°C', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            Text('42°C', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            activeTrackColor: AppTheme.sageGreen,
                            inactiveTrackColor: AppTheme.lightSage,
                          ),
                          child: Slider(
                            value: _climateTemp,
                            min: 8,
                            max: 42,
                            onChanged: (val) => setState(() => _climateTemp = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 2: Media & Tire Pressure
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('media'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkForest,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Dolby Atmos систем',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Шангри-Ла аялгуу',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkForest,
                          ),
                        ),
                        const Text(
                          'Ардын хөгжмийн чуулга',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 10),
                        // Media Controls
                        Row(
                          children: [
                            const Expanded(
                              child: LinearProgressIndicator(
                                value: 0.45,
                                color: AppTheme.sageGreen,
                                backgroundColor: AppTheme.lightSage,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _isPlayingMedia = !_isPlayingMedia),
                              child: Icon(
                                _isPlayingMedia ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: AppTheme.darkForest,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Tire Pressure Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('tire_pressure'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkForest,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Сүүлийн хэмжилт: 12:15',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              children: [
                                Text('49 psi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkForest)),
                                SizedBox(height: 18),
                                Text('47 psi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkForest)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.softBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.tire_repair_rounded,
                                color: AppTheme.darkForest,
                                size: 32,
                              ),
                            ),
                            const Column(
                              children: [
                                Text('48 psi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkForest)),
                                SizedBox(height: 18),
                                Text('49 psi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkForest)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Interactive Location Map Card
            InkWell(
              onTap: () => _openInteractiveMap(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          AppStrings.get('location'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkForest,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.open_in_full_rounded, color: AppTheme.darkForest, size: 20),
                          onPressed: () => _openInteractiveMap(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2EC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size.infinite,
                            painter: _MapRoutePainter(),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppTheme.darkForest,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.my_location_rounded,
                                  color: AppTheme.sageGreen,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Улаанбаатар дахь автомашины байршил\n(Дарж интерактив зураг нээх)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkForest,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.sageGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppTheme.sageGreen
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.8)
      ..lineTo(size.width * 0.45, size.height * 0.5)
      ..lineTo(size.width * 0.65, size.height * 0.7)
      ..lineTo(size.width * 0.85, size.height * 0.3);

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.5), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.7), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.3), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
