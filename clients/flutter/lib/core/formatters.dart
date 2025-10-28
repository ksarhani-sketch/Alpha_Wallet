import 'package:intl/intl.dart';

final _currencyFormatters = <String, NumberFormat>{};

String formatCurrency(double value, String currency) {
  final formatter = _currencyFormatters.putIfAbsent(
    currency,
    () => NumberFormat.currency(locale: Intl.defaultLocale, symbol: currency),
  );
  return formatter.format(value);
}

String formatDate(DateTime date) {
  return DateFormat.yMMMMd().format(date);
}

String formatShortDate(DateTime date) {
  return DateFormat.MMMd().format(date);
}

String formatTime(DateTime date) {
  return DateFormat.Hm().format(date);
}
