import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../features/finance/services/finance_service.dart';
import '../../features/finance/models/finance_models.dart';
import '../../features/finance/models/recurring_payment_model.dart';
import '../../features/health/services/health_service.dart';
import '../../features/smoking/services/smoking_service.dart';
import '../../features/debts/services/debt_service.dart';
import '../../features/debts/models/debt_model.dart';
import '../../features/goals/services/goal_service.dart';
import '../../features/ai_assistant/services/ai_assistant_service.dart';
import '../../features/profile/services/profile_service.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../localization/locale_provider.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/services/auth_service.dart';

final reportingServiceProvider = Provider((ref) => ReportingService(ref));

class ReportingService {
  final Ref _ref;

  ReportingService(this._ref);

  Future<T> _getProviderData<T>(dynamic provider) async {
    final val = _ref.read(provider);
    if (val is AsyncValue<T>) {
      if (val.hasValue) {
        return val.value!;
      }
    }
    return await _ref.read(provider.future);
  }

  Future<void> generateMonthlyReport({
    void Function(double progress, String status)? onProgress,
  }) async {
    final now = DateTime.now();
    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);
    final currency = "TL";

    // Verileri çek
    onProgress?.call(0.1, l10n.translate('report_loading_data') ?? "Veriler okunuyor...");
    final financeActions = await _getProviderData(actionsProvider);
    final debts = await _getProviderData(debtsStreamProvider);
    final goals = await _getProviderData(goalsStreamProvider);
    final waterIntakes = await _ref.read(healthServiceProvider).getDailyWater(now).first;
    final smokingData = await _ref.read(smokingServiceProvider).getSmokingData().first;
    final paymentMethods = await _getProviderData(paymentMethodsProvider);
    final subscriptions = await _getProviderData(recurringPaymentsProvider);
    final userProfile = await _ref.read(userProfileProvider.future);
    final userName = userProfile != null ? "${userProfile.firstName} ${userProfile.lastName}" : "";

    // Metrikleri hesapla
    onProgress?.call(0.3, l10n.translate('report_analyzing_finance') ?? "Finansal veriler analiz ediliyor...");
    final currentMonth = DateFormat('MM.yyyy').format(now);
    final thisMonthActions = financeActions.where((a) => DateFormat('MM.yyyy').format(a.date) == currentMonth).toList();
    
    double monthlyExpense = thisMonthActions
        .where((a) => a.type == FinanceType.expense && a.categoryId != 'cat_goal_savings')
        .fold(0.0, (sum, a) => sum + a.amount);
    double monthlyIncome = thisMonthActions
        .where((a) => a.type == FinanceType.income)
        .fold(0.0, (sum, a) => sum + a.amount);
    
    double totalWater = waterIntakes.fold(0.0, (sum, a) => sum + a.amount);
    double savingsRate = monthlyIncome > 0 ? ((monthlyIncome - monthlyExpense) / monthlyIncome * 100) : 0;
    
    final totalDebt = debts.where((d) => d.type != DebtType.alacak && !d.isPaid).fold(0.0, (sum, d) => sum + d.remainingAmount);
    final totalReceivable = debts.where((d) => d.type == DebtType.alacak && !d.isPaid).fold(0.0, (sum, d) => sum + d.remainingAmount);

    // Borc adedini gruplandir (Taksitleri tek kalem say)
    final activeDebtsList = debts.where((d) => d.type != DebtType.alacak && !d.isPaid).toList();
    final uniqueDebtGroups = <String>{};
    for (var d in activeDebtsList) {
      uniqueDebtGroups.add(d.parentId ?? d.personName);
    }
    final uniqueDebtCount = uniqueDebtGroups.length;

    // Sağlık Skoru Hesapla
    onProgress?.call(0.5, l10n.translate('report_calculating_health') ?? "Sağlık ve alışkanlıklar hesaplanıyor...");
    int healthScore = _calculateFinancialHealthScore(savingsRate, totalDebt, monthlyIncome, totalWater, goals, uniqueDebtCount);

    onProgress?.call(0.7, l10n.translate('report_fetching_ai') ?? "Yapay Zeka analizi hazırlanıyor...");
    String aiSummary = await _getAISummary(
      income: monthlyIncome,
      expense: monthlyExpense,
      water: totalWater,
      smokingData: smokingData,
      l10n: l10n,
      totalDebt: totalDebt,
      uniqueDebtCount: uniqueDebtCount,
      totalReceivable: totalReceivable,
      financeActions: financeActions,
      thisMonthActions: thisMonthActions,
      goals: goals,
    );
    if (aiSummary == "AI_QUOTA_REACHED" || aiSummary.length < 10) {
      aiSummary = _getRuleBasedSummary(monthlyIncome, monthlyExpense, totalWater, l10n);
    }

    // AI Ozetini temizle ([ACTION: ...] etiketlerini kaldir)
    aiSummary = aiSummary.replaceAll(RegExp(r'\[ACTION:.*?\]'), '').trim();
    aiSummary = _t(aiSummary);

    // Fontları Yükle (Inter - Premium & Turkish Support)
    onProgress?.call(0.85, l10n.translate('report_generating_pdf') ?? "PDF raporu oluşturuluyor...");
    final fontRegular = await _loadFont('https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Regular.otf');
    final fontBold = await _loadFont('https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Bold.otf');
    final fontMedium = await _loadFont('https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Medium.otf');

    final pdfTheme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontRegular,
    );

    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeroSection(healthScore, now, l10n, aiSummary, userName),
          pw.SizedBox(height: 24),
          _buildKPIGrid(monthlyIncome, monthlyExpense, savingsRate, totalDebt, totalReceivable, currency, l10n),
          pw.SizedBox(height: 24),
          _buildChartsSection(financeActions, currency, l10n),
          pw.SizedBox(height: 24),
          _buildDebtAnalysisSection(debts, l10n, currency),
          pw.SizedBox(height: 24),
          _buildReceivableAnalysisSection(debts, l10n, currency),
          pw.SizedBox(height: 24),
          _buildAccountsSection(paymentMethods, financeActions, l10n, currency),
          pw.SizedBox(height: 24),
          _buildSubscriptionsSection(subscriptions, l10n, currency),
          pw.SizedBox(height: 24),
          _buildGoalTrackingSection(goals, l10n, currency),
          pw.SizedBox(height: 24),
          _buildHealthAndHabitsSection(totalWater, smokingData, l10n),
          pw.SizedBox(height: 20),
          _buildFooter(l10n),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Parametra_Premium_Report_${now.millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());

    onProgress?.call(1.0, l10n.translate('report_completed') ?? "Tamamlandı!");
    await Share.shareXFiles([XFile(file.path)], text: _replaceTurkishChars(l10n.translate('share_report_text')));
  }

  String _t(String? text) => _replaceTurkishChars(text ?? "");

  int _calculateFinancialHealthScore(double savingsRate, double totalDebt, double income, double water, List<dynamic> goals, int uniqueDebtCount) {
    double score = 50; // Başlangıç
    
    // Tasarruf etkisi
    if (savingsRate > 20) score += 20;
    else if (savingsRate > 0) score += 10;
    else score -= 10;
    
    // Borç etkisi
    if (income > 0) {
      double debtRatio = totalDebt / (income * 12); // Yıllık gelire oran
      if (debtRatio > 0.5) score -= 20;
      else if (debtRatio > 0.2) score -= 10;
      else score += 10;
    }

    // Borc Adedi Etkisi (Yeni)
    if (uniqueDebtCount > 5) score -= 10;
    else if (uniqueDebtCount == 0) score += 5;
    
    // Su etkisi
    if (water >= 2.0) score += 5;
    
    // Hedef etkisi
    if (goals.isNotEmpty) {
      double avgProgress = goals.fold(0.0, (sum, g) => sum + g.progress) / goals.length;
      score += (avgProgress * 15);
    }
    
    return score.clamp(0, 100).toInt();
  }

  Future<pw.Font> _loadFont(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return pw.Font.ttf(response.bodyBytes.buffer.asByteData());
      }
    } catch (e) {
      debugPrint("Font yukleme hatasi ($url): $e");
    }
    return pw.Font.helvetica(); // Fallback
  }

  pw.Widget _buildHeroSection(int score, DateTime date, AppLocalizations l10n, String aiSummary, String userName) {
    final monthName = DateFormat('MMMM yyyy', l10n.locale.languageCode).format(date);
    final scoreColor = score > 75 ? PdfColors.green600 : (score > 40 ? PdfColors.orange600 : PdfColors.red600);
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColor.fromInt(0xff0f172a), PdfColor.fromInt(0xff1e293b)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (userName.isNotEmpty) ...[
                  pw.Text(
                    _t(userName).toUpperCase(),
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _t("PARAMETRA AI YASAM ANALIZI"),
                    style: pw.TextStyle(color: PdfColors.blue300, fontSize: 8, letterSpacing: 1.5),
                  ),
                  pw.SizedBox(height: 16),
                ],
                pw.Text(
                  _t(monthName).toUpperCase(),
                  style: pw.TextStyle(color: PdfColors.blue300, fontSize: 9, letterSpacing: 2, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _t(l10n.translate('monthly_life_report') ?? "AYLIK YASAM RAPORU"),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  aiSummary, // Zaten _t() ile temizlenmis olarak geliyor
                  style: pw.TextStyle(color: PdfColors.blueGrey100, fontSize: 9, fontStyle: pw.FontStyle.italic, lineSpacing: 1.4),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Column(
            children: [
              pw.Container(
                width: 70,
                height: 70,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: scoreColor, width: 4),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  "$score",
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _t(l10n.translate('health_score') ?? "SAGLIK SKORU"),
                style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildKPIGrid(double income, double expense, double savingsRate, double debt, double receivable, String currency, AppLocalizations l10n) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: currency, decimalDigits: 0);
    
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _buildKPICard(_t(l10n.translate('total_income')), formatter.format(income), const PdfColor.fromInt(0xff059669)),
            pw.SizedBox(width: 12),
            _buildKPICard(_t(l10n.translate('total_expense')), formatter.format(expense), const PdfColor.fromInt(0xffe11d48)),
            pw.SizedBox(width: 12),
            _buildKPICard(_t(l10n.translate('net_balance') ?? "Net Durum"), formatter.format(income - expense), PdfColors.blue600),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            _buildKPICard(_t(l10n.translate('savings_rate') ?? "Tasarruf Orani"), "%${savingsRate.toInt()}", PdfColors.cyan600),
            pw.SizedBox(width: 12),
            _buildKPICard(_t(l10n.translate('total_debt') ?? "Toplam Borc"), formatter.format(debt), PdfColors.orange600),
            pw.SizedBox(width: 12),
            _buildKPICard(_t(l10n.translate('total_receivable') ?? "Toplam Alacak"), formatter.format(receivable), PdfColors.indigo600),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildKPICard(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey200),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_t(title).toUpperCase(), style: pw.TextStyle(color: PdfColors.grey600, fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(_t(value), style: pw.TextStyle(color: color, fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildChartsSection(List<dynamic> actions, String currency, AppLocalizations l10n) {
    // Son 5 ayın verisini topla
    final now = DateTime.now();
    final List<Map<String, double>> monthlyData = [];
    final List<String> monthLabels = [];

    for (int i = 4; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i);
      final monthStr = DateFormat('MM.yyyy').format(targetDate);
      final monthName = DateFormat('MMM').format(targetDate);
      monthLabels.add(monthName);

      final monthActions = actions.where((a) => DateFormat('MM.yyyy').format(a.date) == monthStr).toList();
      final income = monthActions.where((a) => a.type == FinanceType.income).fold(0.0, (sum, a) => sum + a.amount);
      final expense = monthActions.where((a) => a.type == FinanceType.expense && a.categoryId != 'cat_goal_savings').fold(0.0, (sum, a) => sum + a.amount);
      
      monthlyData.add({'income': income, 'expense': expense});
    }

    double maxVal = 1000;
    for (var data in monthlyData) {
      if (data['income']! > maxVal) maxVal = data['income']!;
      if (data['expense']! > maxVal) maxVal = data['expense']!;
    }
    maxVal *= 1.2;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColors.grey100),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_t(l10n.translate('income_expense_trend')).toUpperCase(), style: pw.TextStyle(color: PdfColors.grey800, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Container(
            height: 120,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  List.generate(5, (i) => i.toDouble()),
                  buildLabel: (v) => pw.Text(_t(monthLabels[v.toInt()]), style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400)),
                ),
                yAxis: pw.FixedAxis(
                  List.generate(5, (i) => (maxVal / 4 * i)),
                  buildLabel: (v) => pw.Text(v.toInt().toString(), style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400)),
                ),
              ),
              datasets: [
                pw.BarDataSet(
                  color: const PdfColor.fromInt(0xff34d399),
                  width: 10,
                  offset: -6,
                  data: List<pw.PointChartValue>.generate(5, (i) => pw.PointChartValue(i.toDouble(), monthlyData[i]['income']!)),
                ),
                pw.BarDataSet(
                  color: const PdfColor.fromInt(0xfffb7185),
                  width: 10,
                  offset: 6,
                  data: List<pw.PointChartValue>.generate(5, (i) => pw.PointChartValue(i.toDouble(), monthlyData[i]['expense']!)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _buildLegend(_t(l10n.translate('total_income')), const PdfColor.fromInt(0xff34d399)),
              pw.SizedBox(width: 16),
              _buildLegend(_t(l10n.translate('total_expense')), const PdfColor.fromInt(0xfffb7185)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLegend(String label, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(width: 8, height: 8, color: color),
        pw.SizedBox(width: 4),
        pw.Text(_t(label), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildDebtAnalysisSection(List<dynamic> debts, AppLocalizations l10n, String currency) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: currency, decimalDigits: 0);
    final activeDebts = debts.where((d) => d.type != DebtType.alacak && !d.isPaid).toList();
    
    if (activeDebts.isEmpty) return pw.SizedBox.shrink();

    // Gruplandırma Mantığı
    final Map<String, List<dynamic>> groups = {};
    for (var d in activeDebts) {
      final key = d.parentId ?? d.personName;
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(d);
    }

    final List<pw.Widget> debtRows = [];
    groups.forEach((key, group) {
      final first = group.first;
      final totalInstallments = group.map((e) => e.totalInstallments).fold(1, (max, e) => e > max ? e : max);
      
      String label = _t(first.personName);
      String value = "";

      if (totalInstallments > 1) {
        final actualTotal = group.fold(0.0, (sum, e) => sum + e.amount);
        final paidCount = group.where((e) => e.isPaid).length;
        final remainingAmount = group.where((e) => !e.isPaid).fold(0.0, (sum, e) => sum + e.remainingAmount);
        
        label = "${_t(first.personName)} ($totalInstallments Ay)";
        value = "Top: ${formatter.format(actualTotal)} / $paidCount Ay Odendi / Kalan: ${formatter.format(remainingAmount)}";
      } else {
        value = formatter.format(group.fold(0.0, (sum, e) => sum + e.remainingAmount));
      }

      debtRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xffe11d48))),
            ],
          ),
        ),
      );
    });

    final totalRemaining = activeDebts.fold(0.0, (sum, d) => sum + d.remainingAmount);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xfffff1f2),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_t(l10n.translate('debts_loans_tab')).toUpperCase(), style: pw.TextStyle(color: PdfColor.fromInt(0xff9f1239), fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ...debtRows,
          pw.Divider(color: PdfColor.fromInt(0xfffecdd3), thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_t(l10n.translate('total_debt') ?? "Toplam Borc"), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xff9f1239))),
              pw.Text(formatter.format(totalRemaining), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xffe11d48))),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 6,
                  height: 6,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xffe11d48),
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    _t("AI Onerisi: En dusuk bakiyeli borcunu kapatmak uzere 500 TL ayirarak Snowball etkisini baslatabilirsin."),
                    style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceivableAnalysisSection(List<dynamic> debts, AppLocalizations l10n, String currency) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: currency, decimalDigits: 0);
    final activeReceivables = debts.where((d) => d.type == DebtType.alacak && !d.isPaid).toList();
    
    if (activeReceivables.isEmpty) return pw.SizedBox.shrink();

    final totalRemaining = activeReceivables.fold(0.0, (sum, d) => sum + d.remainingAmount);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xfff0fdf4),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_t(l10n.translate('receivables_tab')).toUpperCase(), style: pw.TextStyle(color: PdfColor.fromInt(0xff166534), fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ...activeReceivables.map((d) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_t(d.personName), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                pw.Text(formatter.format(d.remainingAmount), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xff16a34a))),
              ],
            ),
          )),
          pw.Divider(color: PdfColor.fromInt(0xffbbf7d0), thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_t(l10n.translate('total_receivable') ?? "Toplam Alacak"), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xff166534))),
              pw.Text(formatter.format(totalRemaining), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xff16a34a))),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAccountsSection(List<PaymentMethod> accounts, List<FinanceAction> actions, AppLocalizations l10n, String currency) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: currency, decimalDigits: 0);
    if (accounts.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_t(l10n.translate('accounts_balance')).toUpperCase(), style: pw.TextStyle(color: PdfColors.blueGrey800, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ...accounts.map((acc) {
            double currentBalance = acc.openingBalance;
            final accountActions = actions.where((a) => a.paymentMethodId == acc.id && a.isBalanceEffect);
            for (var a in accountActions) {
              if (a.type == FinanceType.income) currentBalance += a.amount;
              else currentBalance -= a.amount;
            }

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blueGrey400,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(_t(acc.name), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                    ],
                  ),
                  pw.Text(formatter.format(currentBalance), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: currentBalance >= 0 ? PdfColors.green700 : PdfColors.red700)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildSubscriptionsSection(List<dynamic> subs, AppLocalizations l10n, String currency) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: currency, decimalDigits: 0);
    if (subs.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_t(l10n.translate('subscriptions_title')).toUpperCase(), style: pw.TextStyle(color: PdfColors.indigo800, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ...subs.map((s) {
            final periodLabel = s.period == RecurringPeriod.monthly 
                ? (l10n.locale.languageCode == 'tr' ? "Ay" : "Month") 
                : (l10n.locale.languageCode == 'tr' ? "Yil" : "Year");

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.indigo400,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(_t(s.name), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                    ],
                  ),
                  pw.Text("${formatter.format(s.amount)} / $periodLabel", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildGoalTrackingSection(List<dynamic> goals, AppLocalizations l10n, String currency) {
    if (goals.isEmpty) return pw.SizedBox.shrink();
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: currency, decimalDigits: 0);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_t(l10n.translate('active_goals_count')).toUpperCase(), style: pw.TextStyle(color: PdfColors.grey800, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        ...goals.map((g) {
          final progress = g.progress.clamp(0.0, 1.0);
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: PdfColors.grey100)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(_t(g.title), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text("%${(progress * 100).toInt()}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue600)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.LinearProgressIndicator(value: progress, backgroundColor: PdfColors.grey100, valueColor: PdfColors.blue600, minHeight: 6),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "${_t(l10n.translate('current_savings_label'))}: ${formatter.format(g.currentAmount)}",
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      "${_t(l10n.translate('target_amount_label'))}: ${formatter.format(g.targetAmount)}",
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey800, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildHealthAndHabitsSection(double water, dynamic smokingData, AppLocalizations l10n) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 24,
                  height: 24,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue400,
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text("W", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_t(l10n.translate('water_consumed_today')), style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
                    pw.Text("${water.toStringAsFixed(1)} Litre", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        if (smokingData != null)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xffecfdf5), borderRadius: pw.BorderRadius.circular(12)),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 24,
                    height: 24,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xff10b981),
                      shape: pw.BoxShape.circle,
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text("S", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_t(l10n.translate('smoke_free_days')), style: pw.TextStyle(color: PdfColor.fromInt(0xff065f46), fontSize: 8)),
                      pw.Text("${DateTime.now().difference(smokingData.startDate).inDays} Gun", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xff064e3b))),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildFooter(AppLocalizations l10n) {
    return pw.SizedBox(height: 20); // Alt kisimda biraz bosluk birak
  }

  String _getRuleBasedSummary(double income, double expense, double water, AppLocalizations l10n) {
    final isTr = l10n.locale.languageCode == 'tr';
    final savings = income - expense;
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL', decimalDigits: 2);
    
    String summary = isTr 
      ? "Finansal durumun incelendiginde; " 
      : "Based on your financial data; ";

    if (savings > 0) {
      summary += isTr 
        ? "bu ay ${currencyFormat.format(savings)} tasarruf yapmayi basarmissin, harika! " 
        : "you managed to save ${currencyFormat.format(savings)} this month, great! ";
    } else {
      summary += isTr 
        ? "giderlerin gelirinden fazla gorunuyor, harcamalarini biraz daha kontrol etmelisin. " 
        : "your expenses are higher than your income, you should monitor your spending. ";
    }

    summary += isTr 
      ? "Su tuketimin $water L seviyesinde. Sagligin icin gunluk 2L hedefine odaklanmalisin. " 
      : "Your water intake is $water L. Focus on the 2L daily goal for your health. ";

    summary += isTr 
      ? "Parametra AI her zaman yaninda!" 
      : "Parametra AI is always with you!";

    return summary;
  }

  List<String> _groupDebts(List<Debt> allDebts, AppLocalizations l10n) {
    final Map<String, List<Debt>> groups = {};
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL', decimalDigits: 2);
    final isTr = l10n.locale.languageCode == 'tr';

    for (var d in allDebts) {
      final key = d.parentId ?? d.personName;
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(d);
    }

    final List<String> results = [];
    groups.forEach((key, group) {
      final first = group.first;
      final totalInstallments = group.map((e) => e.totalInstallments).fold(1, (max, e) => e > max ? e : max);
      
      if (totalInstallments > 1) {
        // Taksitli Islem
        final totalAmount = group.fold(0.0, (sum, e) => sum + (e.amount * (e.totalInstallments / group.length))); 
        // Note: amount in our model is usually per installment if it's auto-generated, 
        // but let's assume it represents the total if it's the parent.
        // Actually, if they are separate records, each has its own amount.
        
        final actualTotal = group.fold(0.0, (sum, e) => sum + e.amount);
        final paidCount = group.where((e) => e.isPaid).length;
        final remainingAmount = group.where((e) => !e.isPaid).fold(0.0, (sum, e) => sum + e.remainingAmount);
        
        if (remainingAmount > 0) {
          final label = isTr ? "Ay Odendi" : "Months Paid";
          final totalLabel = isTr ? "Toplam" : "Total";
          final remainingLabel = isTr ? "Kalan" : "Remaining";
          
          results.add(
            "${first.personName}: $totalLabel ${currencyFormat.format(actualTotal)}, $totalInstallments Ay, $paidCount $label, $remainingLabel: ${currencyFormat.format(remainingAmount)}"
          );
        }
      } else {
        // Tek seferlik borc
        final unpaid = group.where((e) => !e.isPaid).toList();
        for (var d in unpaid) {
          results.add("${d.personName}: ${currencyFormat.format(d.remainingAmount)}");
        }
      }
    });

    return results;
  }

  Future<String> _getAISummary({
    required double income,
    required double expense,
    required double water,
    required dynamic smokingData,
    required AppLocalizations l10n,
    required double totalDebt,
    required int uniqueDebtCount,
    required double totalReceivable,
    required List<FinanceAction> financeActions,
    required List<FinanceAction> thisMonthActions,
    required List<dynamic> goals,
  }) async {
    try {
      final userId = _ref.read(authStateProvider).value?.uid;
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      // 1. Check Firestore Cache
      if (userId != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('cached_reports')
              .doc(dateStr)
              .get();
          if (doc.exists) {
            final cachedText = doc.data()?['summary'] as String?;
            if (cachedText != null && cachedText.isNotEmpty) {
              debugPrint("ReportingService: Using Firestore cached report for $dateStr");
              return cachedText;
            }
          }
        } catch (e) {
          debugPrint("ReportingService Cache Read Error: $e");
        }
      }

      // 2. Perform Local Calculations (AI must not do calculations)
      // Category Breakdown
      final Map<String, double> categorySums = {};
      double totalExpenseForBreakdown = 0;
      for (var a in thisMonthActions) {
        if (a.type == FinanceType.expense && a.categoryId != 'cat_goal_savings') {
          categorySums[a.categoryId] = (categorySums[a.categoryId] ?? 0) + a.amount;
          totalExpenseForBreakdown += a.amount;
        }
      }

      String topCategoryName = "Diğer";
      double topCategoryPercent = 0;
      try {
        final categories = await _ref.read(financeServiceProvider).getCategories().first;
        final Map<String, String> categoryNames = {for (var c in categories) c.id: c.name};
        
        if (totalExpenseForBreakdown > 0 && categorySums.isNotEmpty) {
          final sortedCategories = categorySums.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topCatId = sortedCategories.first.key;
          topCategoryName = categoryNames[topCatId] ?? "Diğer";
          topCategoryPercent = (sortedCategories.first.value / totalExpenseForBreakdown) * 100;
        }
      } catch (e) {
        debugPrint("ReportingService Category Load Error: $e");
      }

      // Expense Trend (Comparison with last month)
      final prevMonth = DateFormat('MM.yyyy').format(DateTime(now.year, now.month - 1));
      final prevMonthActions = financeActions.where((a) => DateFormat('MM.yyyy').format(a.date) == prevMonth).toList();
      double prevMonthExpense = prevMonthActions
          .where((a) => a.type == FinanceType.expense && a.categoryId != 'cat_goal_savings')
          .fold(0.0, (sum, a) => sum + a.amount);
      
      String expenseTrend = "stable";
      if (prevMonthExpense > 0) {
        final diffPercent = ((expense - prevMonthExpense) / prevMonthExpense) * 100;
        if (diffPercent > 5) {
          expenseTrend = "increasing";
        } else if (diffPercent < -5) {
          expenseTrend = "decreasing";
        }
      }

      // Average Goal Progress
      double avgGoalProgressPercent = 0;
      if (goals.isNotEmpty) {
        avgGoalProgressPercent = (goals.fold(0.0, (sum, g) => sum + g.progress) / goals.length) * 100;
      }

      // Smoke free days
      int smokeFreeDays = 0;
      if (smokingData != null) {
        smokeFreeDays = now.difference(smokingData.startDate).inDays;
      }

      // Construct JSON payload
      final payload = {
        "monthlyIncome": income.toInt(),
        "monthlyExpense": expense.toInt(),
        "savings": (income - expense).toInt(),
        "savingsRate": income > 0 ? ((income - expense) / income * 100).toInt() : 0,
        "topCategoryName": topCategoryName,
        "topCategoryPercent": topCategoryPercent.toInt(),
        "expenseTrend": expenseTrend,
        "totalDebt": totalDebt.toInt(),
        "totalReceivable": totalReceivable.toInt(),
        "uniqueDebtCount": uniqueDebtCount,
        "avgGoalProgressPercent": avgGoalProgressPercent.toInt(),
        "waterIntakeLiters": water,
        "smokeFreeDays": smokeFreeDays
      };

      final payloadJson = const JsonEncoder.withIndent('  ').convert(payload);

      // 3. Prepare AI Prompt
      final isTr = l10n.locale.languageCode == 'tr';
      final languageInstruction = isTr 
          ? "Lütfen CEVABINI SADECE TÜRKÇE OLARAK YAZ." 
          : "Please WRITE YOUR RESPONSE ONLY IN ENGLISH.";

      final aiService = _ref.read(aiAssistantServiceProvider);
      final promptTemplate = l10n.translate('ai_report_prompt');
      final prompt = "$promptTemplate\n\n$languageInstruction\n"
          "Pre-calculated User Summary Data (JSON):\n"
          "$payloadJson\n\n"
          "Important: Do not perform any calculations. Interpret the data, highlight achievements, and give motivational advice.";
      
      final response = await aiService.getChatResponse([], prompt, isAnalysis: true);
      
      if (response.contains("AI_QUOTA_REACHED") || response.contains("kota") || response.contains("limit") || response.contains("429")) {
        return "AI_QUOTA_REACHED"; 
      }
      
      // 4. Save to Firestore Cache
      if (userId != null && response.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('cached_reports')
              .doc(dateStr)
              .set({
                'summary': response,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          debugPrint("ReportingService: Successfully saved cached report for $dateStr");
        } catch (e) {
          debugPrint("ReportingService Cache Write Error: $e");
        }
      }

      return response;
    } catch (e) {
      debugPrint("ReportingService _getAISummary Error: $e");
      return "AI_QUOTA_REACHED";
    }
  }

  String _replaceTurkishChars(String text) {
    // Sadece PDF fontunun desteklemedigi sembolleri ve kritik karakterleri degistir
    return text
        .replaceAll('₺', 'TL')
        .replaceAll('İ', 'I')
        .replaceAll('ı', 'i')
        .replaceAll('Ş', 'S')
        .replaceAll('ş', 's')
        .replaceAll('Ğ', 'G')
        .replaceAll('ğ', 'g')
        .replaceAll('Ç', 'C')
        .replaceAll('ç', 'c')
        .replaceAll('Ö', 'O')
        .replaceAll('ö', 'o')
        .replaceAll('Ü', 'U')
        .replaceAll('ü', 'u');
  }
}
