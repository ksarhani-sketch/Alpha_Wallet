enum BudgetPeriod { weekly, monthly, quarterly, yearly }

class Budget {
  const Budget({
    required this.id,
    required this.currency,
    required this.limit,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    this.categoryId,
    this.alertThreshold = 0.9,
    this.rollover = false,
  });

  final String id;
  final String currency;
  final double limit;
  final BudgetPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? categoryId;
  final double alertThreshold;
  final bool rollover;

  bool get isOverall => categoryId == null;

  Budget copyWith({
    String? id,
    String? currency,
    double? limit,
    BudgetPeriod? period,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? categoryId,
    double? alertThreshold,
    bool? rollover,
  }) {
    return Budget(
      id: id ?? this.id,
      currency: currency ?? this.currency,
      limit: limit ?? this.limit,
      period: period ?? this.period,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      categoryId: categoryId ?? this.categoryId,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      rollover: rollover ?? this.rollover,
    );
  }
}
