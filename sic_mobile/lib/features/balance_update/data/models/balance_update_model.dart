import '../../domain/entities/balance_update.dart';

class BalanceUpdateModel extends BalanceUpdate {
  const BalanceUpdateModel({
    required super.puceId,
    required super.newBalance,
    required super.updatedAt,
  });

  /// Construit le resultat a partir de la reponse
  /// `POST /puces/{id}/set_balance/` (`{message, balance}`). Le `puceId` est
  /// connu du client (la puce ciblee).
  factory BalanceUpdateModel.fromResponse(
    String puceId,
    Map<String, dynamic> json,
  ) {
    return BalanceUpdateModel(
      puceId: puceId,
      newBalance: (json['balance'] as num).toDouble(),
      updatedAt: DateTime.now(),
    );
  }
}
