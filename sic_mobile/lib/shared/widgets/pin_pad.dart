import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sic_mobile/config/theme.dart';

/// PIN Pad Widget for entering PIN codes
class PinPad extends StatefulWidget {
  final int pinLength;
  final void Function(String) onPinComplete;
  final void Function(String)? onPinChanged;
  final bool showBiometric;
  final VoidCallback? onBiometricTap;
  final bool isDarkMode;

  const PinPad({
    super.key,
    this.pinLength = 4,
    required this.onPinComplete,
    this.onPinChanged,
    this.showBiometric = false,
    this.onBiometricTap,
    this.isDarkMode = false,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _onKeyTap(String key) {
    HapticFeedback.lightImpact();

    if (key == 'delete') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
        });
        widget.onPinChanged?.call(_pin);
      }
    } else if (key == 'biometric') {
      widget.onBiometricTap?.call();
    } else {
      if (_pin.length < widget.pinLength) {
        setState(() {
          _pin += key;
        });
        widget.onPinChanged?.call(_pin);

        if (_pin.length == widget.pinLength) {
          widget.onPinComplete(_pin);
        }
      }
    }
  }

  void clear() {
    setState(() {
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = isDark ? SicTheme.surfaceDark : Colors.grey.shade100;
    final buttonColor = isDark ? SicTheme.surfaceLightDark : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pinLength, (index) {
            final isFilled = index < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: primaryColor,
                  width: 2,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 40),

        // Number pad
        _buildKeypad(backgroundColor, buttonColor, primaryColor),
      ],
    );
  }

  Widget _buildKeypad(Color backgroundColor, Color buttonColor, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(SicTheme.spaceMd),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(SicTheme.radiusXl),
      ),
      child: Column(
        children: [
          _buildRow(['1', '2', '3'], buttonColor, primaryColor),
          const SizedBox(height: SicTheme.spaceSm),
          _buildRow(['4', '5', '6'], buttonColor, primaryColor),
          const SizedBox(height: SicTheme.spaceSm),
          _buildRow(['7', '8', '9'], buttonColor, primaryColor),
          const SizedBox(height: SicTheme.spaceSm),
          _buildRow([
            widget.showBiometric ? 'biometric' : '',
            '0',
            'delete',
          ], buttonColor, primaryColor),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys, Color buttonColor, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 80, height: 64);
        }
        return _buildKey(key, buttonColor, primaryColor);
      }).toList(),
    );
  }

  Widget _buildKey(String key, Color buttonColor, Color primaryColor) {
    Widget child;

    if (key == 'delete') {
      child = Icon(
        Icons.backspace_outlined,
        color: primaryColor,
        size: 24,
      );
    } else if (key == 'biometric') {
      child = Icon(
        Icons.fingerprint,
        color: primaryColor,
        size: 28,
      );
    } else {
      child = Text(
        key,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      );
    }

    return Container(
      width: 80,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: buttonColor,
        borderRadius: BorderRadius.circular(SicTheme.radiusMd),
        child: InkWell(
          onTap: () => _onKeyTap(key),
          borderRadius: BorderRadius.circular(SicTheme.radiusMd),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// PIN Input Display for showing entered PIN
class PinInputDisplay extends StatelessWidget {
  final int length;
  final int filledCount;
  final Color? filledColor;
  final Color? emptyColor;

  const PinInputDisplay({
    super.key,
    this.length = 4,
    this.filledCount = 0,
    this.filledColor,
    this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final fillColor = filledColor ?? primaryColor;
    final empty = emptyColor ?? primaryColor.withValues(alpha: 0.3);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < filledCount;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? fillColor : Colors.transparent,
            border: Border.all(
              color: isFilled ? fillColor : empty,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}