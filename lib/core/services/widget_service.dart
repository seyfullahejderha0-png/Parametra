import 'package:home_widget/home_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/health/services/health_service.dart';
import '../../features/smoking/services/smoking_service.dart';

final widgetServiceProvider = Provider((ref) => WidgetService(ref));

class WidgetService {
  final Ref _ref;

  WidgetService(this._ref);

  Future<void> updateWidgets() async {
    // Water Data
    final waterIntakes = await _ref.read(healthServiceProvider).getDailyWater(DateTime.now()).first;
    double totalWater = waterIntakes.fold(0.0, (sum, item) => sum + item.amount);
    
    await HomeWidget.saveWidgetData<double>('water_amount', totalWater);
    
    // Smoking Data
    final smokingData = await _ref.read(smokingServiceProvider).getSmokingData().first;
    if (smokingData != null) {
      final days = DateTime.now().difference(smokingData.startDate).inDays;
      await HomeWidget.saveWidgetData<int>('smoking_days', days);
    }

    await HomeWidget.updateWidget(
      name: 'AppWidgetProvider',
      androidName: 'AppWidgetProvider',
    );
  }
}
