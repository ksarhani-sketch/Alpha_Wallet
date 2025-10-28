enum WalletType { cash, bank, card, crypto }

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    required this.type,
    this.isArchived = false,
    this.isShared = false,
  });

  final String id;
  final String name;
  final String currency;
  final double balance;
  final WalletType type;
  final bool isArchived;
  final bool isShared;

  Wallet copyWith({
    String? id,
    String? name,
    String? currency,
    double? balance,
    WalletType? type,
    bool? isArchived,
    bool? isShared,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      isArchived: isArchived ?? this.isArchived,
      isShared: isShared ?? this.isShared,
    );
  }
}
