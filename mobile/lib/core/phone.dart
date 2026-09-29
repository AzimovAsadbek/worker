/// Mirrors backend normalizePhone(): Uzbek mobile numbers only, returns E.164 or null.
const _operators = {'20', '33', '50', '55', '61', '62', '65', '66', '67', '69', '70', '71', '72', '73', '74', '75', '76', '77', '78', '79', '88', '90', '91', '93', '94', '95', '97', '98', '99'};

String? normalizeUzPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-()+.]'), '');
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
  String national;
  if (digits.length == 12 && digits.startsWith('998')) {
    national = digits.substring(3);
  } else if (digits.length == 9) {
    national = digits;
  } else {
    return null;
  }
  if (!_operators.contains(national.substring(0, 2))) return null;
  return '+998$national';
}

/// +998901234567 → +998 90 123 45 67
String prettyPhone(String e164) {
  final d = e164.replaceAll(RegExp(r'\D'), '');
  if (d.length != 12) return e164;
  return '+${d.substring(0, 3)} ${d.substring(3, 5)} ${d.substring(5, 8)} ${d.substring(8, 10)} ${d.substring(10)}';
}
