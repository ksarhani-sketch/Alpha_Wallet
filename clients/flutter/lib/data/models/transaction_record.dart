enum TransactionKind { expense, income, transfer }

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.kind,
    required this.timestamp,
    this.counterpartyWalletId,
    this.note,
    this.tags = const [],
    this.merchant,
    this.locationDescription,
    this.attachmentUrl,
    this.fxRate = 1,
    this.pending = false,
  });

  final String id;
  final String walletId;
  final double amount;
  final String currency;
  final String categoryId;
  final TransactionKind kind;
  final DateTime timestamp;
  final String? counterpartyWalletId;
  final String? note;
  final List<String> tags;
  final String? merchant;
  final String? locationDescription;
  final String? attachmentUrl;
  final double fxRate;
  final bool pending;

  TransactionRecord copyWith({
    String? id,
    String? walletId,
    double? amount,
    String? currency,
    String? categoryId,
    TransactionKind? kind,
    DateTime? timestamp,
    String? counterpartyWalletId,
    String? note,
    List<String>? tags,
    String? merchant,
    String? locationDescription,
    String? attachmentUrl,
    double? fxRate,
    bool? pending,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      kind: kind ?? this.kind,
      timestamp: timestamp ?? this.timestamp,
      counterpartyWalletId: counterpartyWalletId ?? this.counterpartyWalletId,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      merchant: merchant ?? this.merchant,
      locationDescription: locationDescription ?? this.locationDescription,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      fxRate: fxRate ?? this.fxRate,
      pending: pending ?? this.pending,
    );
  }
}
