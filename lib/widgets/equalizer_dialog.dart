import 'package:flutter/material.dart';
import 'package:tunes4r/utils/constants.dart';
import 'package:tunes4r/utils/theme_colors.dart';

/// A professional 10-band equalizer dialog widget
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

class _EqualizerDialogState extends State<EqualizerDialog> {
  late List<double> _bands;
  late bool _isEnabled;
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _bands = List<double>.from(widget.initialBands);
    _isEnabled = widget.initialEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
      title: Row(
        children: [
          Icon(Icons.equalizer, color: ThemeColorsUtil.primaryColor),
          const SizedBox(width: 8),
          Text(
            'Equalizer',
            style: TextStyle(
              color: ThemeColorsUtil.textColorPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Builder(
        builder: (context) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = isMobile ? screenWidth * 0.9 : 550.0;
          final dialogHeight = isMobile ? screenWidth * 0.8 : 600.0;

          return SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: [
                // Equalizer Enable/Disable Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _isEnabled ? ThemeColorsUtil.primaryColor.withOpacity(0.1) : ThemeColorsUtil.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isEnabled ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isEnabled ? Icons.equalizer : Icons.equalizer_outlined,
                        size: 20,
                        color: _isEnabled ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Equalizer ${_isEnabled ? 'Enabled' : 'Disabled'}',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: _isEnabled ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _isEnabled,
                        onChanged: (value) {
                          setState(() => _isEnabled = value);
                        },
                        activeThumbColor: ThemeColorsUtil.primaryColor,
                        activeTrackColor: ThemeColorsUtil.primaryColor.withOpacity(0.3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),

                // Presets Dropdown
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.playlist_play,
                        size: 18,
                        color: ThemeColorsUtil.textColorSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Presets:',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColorsUtil.textColorSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AbsorbPointer(
                          absorbing: !_isEnabled,
                          child: Opacity(
                            opacity: _isEnabled ? 1.0 : 0.4,
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: ThemeColorsUtil.surfaceColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: ThemeColorsUtil.textColorSecondary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPreset ?? 'Select Preset',
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: 'Select Preset',
                                      child: Text(
                                        'Select Preset',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: ThemeColorsUtil.textColorSecondary,
                                        ),
                                      ),
                                    ),
                                    ..._presets.keys.map((preset) => DropdownMenuItem<String>(
                                      value: preset,
                                      child: Text(
                                        preset,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: ThemeColorsUtil.textColorPrimary,
                                        ),
                                      ),
                                    )),
                                  ],
                                  onChanged: _isEnabled ? (value) {
                                    if (value != null) {
                                      if (value == 'Select Preset') {
                                        setState(() => _selectedPreset = null);
                                      } else {
                                        _applyPreset(value);
                                        setState(() => _selectedPreset = value);
                                      }
                                    }
                                  } : null,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    size: 18,
                                    color: ThemeColorsUtil.textColorSecondary,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ThemeColorsUtil.textColorPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  'Adjust frequency bands (-20dB to +20dB)',
                  style: TextStyle(fontSize: 12, color: ThemeColorsUtil.textColorSecondary),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildEqualizerSliders(isMobile, _isEnabled),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _bands = List.filled(10, 0.0);
                          _selectedPreset = null; // Clear preset on reset
                        });
                      },
                      child: Text(
                        'Reset',
                        style: TextStyle(color: ThemeColorsUtil.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop({
                        'bands': _bands,
                        'enabled': _isEnabled,
                      }),
                      child: Text(
                        'Apply',
                        style: TextStyle(color: ThemeColorsUtil.secondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Close',
                        style: TextStyle(color: ThemeColorsUtil.secondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getFrequencyLabel(int index) {
    const labels = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'];
    return labels[index];
  }

  static const Map<String, List<double>> _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [5.0, 3.0, 2.0, 1.0, 0.0, -1.0, 2.0, 3.0, 4.0, 5.0],
    'Pop': [-1.0, 0.0, 3.0, 4.0, 2.0, 1.0, 2.0, 3.0, 0.0, -1.0],
    'Jazz': [4.0, 3.0, 1.0, 2.0, -1.0, -1.0, 0.0, 2.0, 3.0, 4.0],
    'Classical': [3.0, 3.0, 2.0, 1.0, -1.0, -1.0, 0.0, 1.0, 2.0, 3.0],
    'Bass Boost': [6.0, 5.0, 3.0, 1.0, 0.0, -1.0, -1.0, 0.0, 0.0, 0.0],
    'Vocal Boost': [0.0, 0.0, -1.0, -1.0, 2.0, 4.0, 4.0, 2.0, 0.0, 0.0],
    'Dance': [4.0, 2.0, 0.0, 0.0, -2.0, 1.0, 3.0, 4.0, 3.0, 2.0],
    'Electronic': [5.0, 4.0, 2.0, -1.0, -3.0, -1.0, 2.0, 4.0, 5.0, 4.0],
  };

  void _applyPreset(String presetName) {
    if (_presets.containsKey(presetName)) {
      setState(() {
        _bands = List<double>.from(_presets[presetName]!);
      });
    }
  }

  Widget _buildEqualizerSliders(bool isMobile, bool isEnabled) {
    return AbsorbPointer(
      absorbing: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: isMobile
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(_bands.length, (index) {
                    return Container(
                      width: 55,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 180,
                            width: 45,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                value: _bands[index],
                                min: minEqGain,
                                max: maxEqGain,
                                divisions: eqDivisions,
                                onChanged: isEnabled ? (value) {
                                  setState(() {
                                    _bands[index] = value;
                                    _selectedPreset = null; // Clear preset when manually adjusted
                                  });
                                } : null,
                                activeColor: ThemeColorsUtil.primaryColor,
                                inactiveColor: ThemeColorsUtil.surfaceColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getFrequencyLabel(index),
                            style: TextStyle(
                              fontSize: 9,
                              color: ThemeColorsUtil.textColorSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_bands[index].toStringAsFixed(1)}dB',
                            style: TextStyle(
                              fontSize: 9,
                              color: ThemeColorsUtil.textColorPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_bands.length, (index) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 200,
                        width: 50,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: _bands[index],
                            min: minEqGain,
                            max: maxEqGain,
                            divisions: eqDivisions,
                            onChanged: isEnabled ? (value) {
                              setState(() {
                                _bands[index] = value;
                                _selectedPreset = null; // Clear preset when manually adjusted
                              });
                            } : null,
                            activeColor: ThemeColorsUtil.primaryColor,
                            inactiveColor: ThemeColorsUtil.surfaceColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getFrequencyLabel(index),
                        style: TextStyle(
                          fontSize: 10,
                          color: ThemeColorsUtil.textColorSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_bands[index].toStringAsFixed(1)}dB',
                        style: TextStyle(
                          fontSize: 10,
                          color: ThemeColorsUtil.textColorPrimary,
                        ),
                      ),
                    ],
                  );
                }),
              ),
      ),
    );
  }
}
