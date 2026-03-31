class PaymentMethodModel {
  const PaymentMethodModel({
    required this.id,
    required this.label,
    required this.last4,
    required this.expiry,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String last4;
  final String expiry;
  final bool isDefault;

  String get maskedNumber => '**** **** **** $last4';

  PaymentMethodModel copyWith({
    String? id,
    String? label,
    String? last4,
    String? expiry,
    bool? isDefault,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      label: label ?? this.label,
      last4: last4 ?? this.last4,
      expiry: expiry ?? this.expiry,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'last4': last4,
      'expiry': expiry,
    };
  }

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: (json['id'] as String? ?? '').trim(),
      label: (json['label'] as String? ?? 'Card').trim(),
      last4: (json['last4'] as String? ?? '').trim(),
      expiry: (json['expiry'] as String? ?? '').trim(),
    );
  }
}
