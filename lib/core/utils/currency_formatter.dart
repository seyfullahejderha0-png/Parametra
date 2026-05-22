import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, BuildContext context, String currencyCode) {
    final localeCode = Localizations.localeOf(context).languageCode == 'tr' ? 'tr_TR' : 'en_US';
    final symbol = getSymbol(currencyCode);
    
    final formatter = NumberFormat.currency(
      locale: localeCode,
      symbol: symbol,
      decimalDigits: amount.truncateToDouble() == amount ? 0 : 2, // Tam sayıysa virgül koyma
    );
    
    return formatter.format(amount);
  }

  static String getSymbol(String currencyCode) {
    if (currencyCode == 'USD') return '\$';
    if (currencyCode == 'EUR') return '€';
    return '₺';
  }
}
