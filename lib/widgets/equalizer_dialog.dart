// equalizer_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:tunes4r/utils/constants.dart';
import 'package:tunes4r/utils/theme_colors.dart';

class EqualizerDialog extends StatefulWidget {
  final List<double> initialBands;
  final bool initialEnabled;

  const EqualizerDialog({
    super.key,
    required this.initialBands,
    this.initialEnabled = false,
  });

  @override
  State<EqualizerDialog> createState() => _EqualizerDialogState();
}

class _EqualizerDialogState extends State<EqualizerDialog> with TickerProviderStateMixin {
  late List<double> _bands;
  late List<double> _animatedBands;
  late bool _isEnabled;
  String? _selectedPreset;

  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  late List<SpringSimulation> _springSimulations;

  static const double _minDb = -20.0;
  static const double _maxDb = 20.0;
  // More pronounced spring effect for dramatic bouncing behavior
  static const SpringDescription _springDescription = SpringDescription(
    mass: 1.0,        // Same mass
    stiffness: 80.0,  // Lower stiffness = looser spring = more bounce
    damping: 8.0      // Lower damping = less friction = more oscillations
  );

  @override
  void initState() {
    super.initState();
    _bands = widget.initialBands.map(_dbToSlider).toList();
    _animatedBands = List.from(_bands);
    _isEnabled = widget.initialEnabled;

    // Initialize spring animations for each band (600ms duration for dramatic spring effect)
    _controllers = List.generate(10, (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _animations = List.generate(10, (i) => Tween<double>(begin: _bands[i], end: _bands[i])
        .animate(CurvedAnimation(parent: _controllers[i], curve: Curves.elasticOut)));
    _springSimulations = List.generate(10, (_) => SpringSimulation(_springDescription, 0.0, 1.0, 0.0));

    // Listen to animation updates
    for (int i = 0; i < 10; i++) {
      _animations[i].addListener(() {
        setState(() {
          _animatedBands[i] = _animations[i].value;
        });
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double _dbToSlider(double db) => (db - _minDb) / (_maxDb - _minDb);
  double _sliderToDb(double v) => v * (_maxDb - _minDb) + _minDb;

  void _updateBandWithSpring(int index, double newValue) {
    // Stop current animation if running
    _controllers[index].stop();

    // Create new spring animation
    final currentValue = _animatedBands[index];
    final tween = Tween<double>(begin: currentValue, end: newValue)
        .animate(CurvedAnimation(parent: _controllers[index], curve: Curves.elasticOut));

    // Update animation
    _animations[index] = tween;
    _bands[index] = newValue; // Update actual value

    // Start animation
    _controllers[index].forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
      title: Row(
        children: [
          Icon(Icons.equalizer, color: ThemeColorsUtil.primaryColor),
          const SizedBox(width: 8),
          Text('Equalizer', style: TextStyle(color: ThemeColorsUtil.textColorPrimary, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isEnabled ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 560,
        height: isMobile ? 480 : 520,
        child: Column(
          children: [
            _buildToggle(),
            _buildPresets(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Adjust frequency bands (-20dB to +20dB)',
                style: TextStyle(fontSize: 12, color: ThemeColorsUtil.textColorSecondary),
              ),
            ),
            Expanded(child: _buildEqualizer()),
            const SizedBox(height: 16),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isEnabled ? ThemeColorsUtil.primaryColor.withOpacity(0.1) : ThemeColorsUtil.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isEnabled ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(_isEnabled ? Icons.equalizer : Icons.equalizer_outlined,
                  color: _isEnabled ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary),
              const SizedBox(width: 8),
              Text(_isEnabled ? 'ON' : 'OFF',
                  style: TextStyle(color: _isEnabled ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Switch(value: _isEnabled, onChanged: (v) => setState(() => _isEnabled = v), activeColor: ThemeColorsUtil.primaryColor),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.surfaceColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ThemeColorsUtil.textColorSecondary.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPreset ?? 'Select Preset',
          isExpanded: true,
          dropdownColor: ThemeColorsUtil.surfaceColor,
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          icon: Icon(Icons.arrow_drop_down, color: ThemeColorsUtil.textColorSecondary),
          items: ['Select Preset', ..._presets.keys].map((e) {
            return DropdownMenuItem(
              value: e,
              child: Text(e, style: TextStyle(color: e == 'Select Preset' ? ThemeColorsUtil.textColorSecondary : ThemeColorsUtil.textColorPrimary)),
            );
          }).toList(),
          onChanged: _isEnabled ? (v) => v != null && v != 'Select Preset' ? _applyPreset(v) : null : null,
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(onPressed: () {
          final newBands = List.filled(10, 0.5);
          for (int i = 0; i < 10; i++) {
            _updateBandWithSpring(i, newBands[i]);
          }
          _selectedPreset = null;
        }, child: Text('Reset', style: TextStyle(color: ThemeColorsUtil.error))),
        TextButton(onPressed: () => Navigator.pop(context, {'bands': _bands.map(_sliderToDb).toList(), 'enabled': _isEnabled}), child: Text('Apply', style: TextStyle(color: ThemeColorsUtil.secondary))),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: TextStyle(color: ThemeColorsUtil.textColorSecondary))),
      ],
    );
  }

  Widget _buildEqualizer() {
    return AbsorbPointer(
      absorbing: !_isEnabled,
      child: Opacity(
        opacity: _isEnabled ? 1.0 : 0.5,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            // Account for text labels below sliders - hide labels on small screens for better alignment
            final hideLabels = height < 500;
            final sliderHeight = hideLabels ? height : height - 40.0; // More generous text space deduction
            // Center curve with empirical adjustment for slider positioning45
            final centerY = hideLabels ? height / 2 : sliderHeight * 0.60; // Adjusted center positioning
            // Travel height with more conservative scaling
            final sliderTravelHeight = hideLabels ? height * 0.9 : sliderHeight * 0.40;

            return Stack(
              children: [
                // Curve with spring animation
                AnimatedBuilder(
                  animation: Listenable.merge(_controllers),
                  builder: (context, child) {
                    // Calculate slider width to match the actual sliders
                    final double sliderWidth = (constraints.maxWidth / 10).clamp(20.0, 40.0);
                    return CustomPaint(
                      size: Size(constraints.maxWidth, height),
                      painter: EqualizerCurvePainter(
                        bands: _animatedBands,
                        centerY: centerY,
                        travelHeight: sliderTravelHeight,
                        sliderWidth: sliderWidth,
                      ),
                    );
                  },
                ),
                // Sliders
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (i) => _buildSlider(i, height, constraints.maxWidth)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlider(int index, double height, double availableWidth) {
    const labels = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'];

    // Dynamically calculate slider width based on available space (with minimum width)
    final double sliderWidth = (availableWidth / 10).clamp(20.0, 40.0);

    // Make thumb radius smaller on mobile devices
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double thumbRadius = isMobile ? 6.0 : 9.0;

    // Hide labels on small screens to allow better curve-slider alignment
    final bool showLabels = MediaQuery.of(context).size.width >= 600;

    return SizedBox(
      width: sliderWidth,
      child: Column(
        children: [
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: ThemeColorsUtil.surfaceColor.withOpacity(0.5),
                  thumbColor: ThemeColorsUtil.primaryColor,
                  overlayColor: ThemeColorsUtil.primaryColor.withOpacity(0.2),
                ),
                child: Slider(
                  value: _bands[index],
                  min: 0.0,
                  max: 1.0,
                  divisions: eqDivisions,
                  onChanged: _isEnabled
                      ? (v) => _updateBandWithSpring(index, v)
                      : null,
                ),
              ),
            ),
          ),
          if (showLabels) ...[
            Text(labels[index], style: TextStyle(color: ThemeColorsUtil.textColorSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('${_sliderToDb(_bands[index]).toStringAsFixed(1)}dB', style: TextStyle(color: ThemeColorsUtil.textColorPrimary, fontSize: 9)),
          ],
        ],
      ),
    );
  }

  static const Map<String, List<double>> _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [5.0, 3.0, 2.0, 1.0, 0.0, -1.0, 2.0, 3.0, 4.0, 5.0],
    'Pop': [-1.0, 0.0, 3.0, 4.0, 2.0, 1.0, 2.0, 3.0, 0.0, -1.0],
    'Jazz': [4.0, 3.0, 1.0, 2.0, -1.0, -1.0, 0.0, 2.0, 3.0, 4.0],
    'Bass Boost': [8.0, 7.0, 5.0, 2.0, 0.0, -2.0, -2.0, 0.0, 0.0, 0.0],
    'Vocal Boost': [0.0, 0.0, -2.0, -1.0, 3.0, 6.0, 6.0, 3.0, 0.0, 0.0],
  };

  void _applyPreset(String name) {
    final presetBands = _presets[name]!.map(_dbToSlider).toList();
    for (int i = 0; i < 10; i++) {
      _updateBandWithSpring(i, presetBands[i]);
    }
    _selectedPreset = name;
  }
}

// PERFECTLY ALIGNED CURVE — passes through center of every thumb
class EqualizerCurvePainter extends CustomPainter {
  final List<double> bands;
  final double centerY;
  final double travelHeight;
  final double sliderWidth;

  EqualizerCurvePainter({
    required this.bands,
    required this.centerY,
    required this.travelHeight,
    required this.sliderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final w = size.width;

    final points = <Offset>[];
    // Calculate exact slider positions matching Row with MainAxisAlignment.spaceEvenly
    // Dynamic slider width based on available space
    final numItems = bands.length;
    final availableWidth = w;
    final totalSpacing = availableWidth - (sliderWidth * numItems);
    final spacing = totalSpacing / (numItems + 1);



    for (int i = 0; i < bands.length; i++) {
      // Perfectly center the curve on slider thumb positions
      final x = spacing + (i * (sliderWidth + spacing)) + (sliderWidth / 2);
      final gain01 = bands[i]; // 0.0 = -20dB, 1.0 = +20dB
      final yOffset = (gain01 - 0.5) * travelHeight;
      final y = centerY - yOffset; // Perfect alignment
      points.add(Offset(x, y));
    }

    // Center line
    canvas.drawLine(Offset(0, centerY), Offset(w, centerY),
        Paint()..color = ThemeColorsUtil.textColorSecondary.withOpacity(0.4)..strokeWidth = 1);

    // Fill
    final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cp = (p1.dx - p0.dx) * 0.4;
      fillPath.cubicTo(p0.dx + cp, p0.dy, p1.dx - cp, p1.dy, p1.dx, p1.dy);
    }
    fillPath.lineTo(w, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ThemeColorsUtil.primaryColor.withOpacity(0.6), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w, size.height))
        ..style = PaintingStyle.fill,
    );

    // Main curve
    final curvePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cp = (p1.dx - p0.dx) * 0.4;
      curvePath.cubicTo(p0.dx + cp, p0.dy, p1.dx - cp, p1.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(
      curvePath,
      Paint()
        ..color = ThemeColorsUtil.primaryColor
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant EqualizerCurvePainter old) => old.bands != bands;


}
