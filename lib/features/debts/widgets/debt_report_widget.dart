import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/glass_card.dart';
import '../models/debt_model.dart';

class DebtReportWidget extends StatelessWidget {
  final List<Debt> debts;
  final String currencyCode;

  const DebtReportWidget({
    super.key,
    required this.debts,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    double totalBorc = 0;
    double totalAlacak = 0;

    for (var debt in debts) {
      if (!debt.isPaid) {
        if (debt.type == DebtType.borc || debt.type == DebtType.kredi) {
          totalBorc += debt.remainingAmount * debt.exchangeRate;
        } else {
          totalAlacak += debt.remainingAmount * debt.exchangeRate;
        }
      }
    }

    final total = totalBorc + totalAlacak;
    final borcRatio = total > 0 ? totalBorc / total : 0.0;
    
    // Healthy debt ratio: Usually if debt is less than 40% of total flow it's "healthy"
    // But here we just compare debt vs receivable. 
    // If debt > receivable, it's orange/red.
    final isHealthy = totalAlacak >= totalBorc;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  context.l10n('debt_receivable_balance'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isHealthy ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isHealthy ? context.l10n('balanced') : context.l10n('attention'),
                  style: TextStyle(
                    color: isHealthy ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStatItem(
                context,
                context.l10n('remaining_debt'),
                CurrencyFormatter.format(totalBorc, context, currencyCode),
                Colors.redAccent,
                Icons.arrow_upward,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                context,
                context.l10n('remaining_receivable'),
                CurrencyFormatter.format(totalAlacak, context, currencyCode),
                Colors.blueAccent,
                Icons.arrow_downward,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: borcRatio,
                  minHeight: 12,
                  backgroundColor: Colors.blueAccent.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                ),
              ),
              if (total > 0)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "%${(borcRatio * 100).toInt()} ${context.l10n('debt_label')}",
                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                "%${((1 - borcRatio) * 100).toInt()} ${context.l10n('receivable_label')}",
                style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }
}
