import 'transaction_record.dart';

enum RecurrenceFrequency { daily, weekly, monthly, quarterly, yearly, custom }

class RecurringTemplate {
  const RecurringTemplate({
    required this.id,
    required this.name,
    required this.frequency,
    required this.nextRun,
    required this.template,
    this.customExpression,
    this.reminderMinutesBefore,
    this.endsOn,
  });

  final String id;
  final String name;
  final RecurrenceFrequency frequency;
  final DateTime nextRun;
  final TransactionRecord template;
  final String? customExpression;
  final int? reminderMinutesBefore;
  final DateTime? endsOn;

  RecurringTemplate copyWith({
    String? id,
    String? name,
    RecurrenceFrequency? frequency,
    DateTime? nextRun,
    TransactionRecord? template,
    String? customExpression,
    int? reminderMinutesBefore,
    DateTime? endsOn,
  }) {
    return RecurringTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      nextRun: nextRun ?? this.nextRun,
      template: template ?? this.template,
      customExpression: customExpression ?? this.customExpression,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      endsOn: endsOn ?? this.endsOn,
    );
  }
}
