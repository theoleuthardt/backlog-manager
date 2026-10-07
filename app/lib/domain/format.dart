/// Hours as shown to the user: whole numbers without a fraction, otherwise one
/// decimal.
String formatHours(double value) {
  return value.roundToDouble() == value
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

/// A whole number with a comma between the thousands.
String formatCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
