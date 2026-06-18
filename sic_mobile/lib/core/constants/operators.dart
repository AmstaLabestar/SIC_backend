/// Operateurs Mobile Money supportes (code interne -> libelle d'affichage).
///
/// Liste canonique cote app, utilisee par les selecteurs d'operateur
/// (ajout/modification de puce, ecrans d'operation). Le mapping vers les
/// codes backend (`ORANGE`/`MOOV`/`TELECEL`/`MTN`) est gere par
/// [OperatorMapping] (`core/network/operator_mapping.dart`).
const Map<String, String> kAvailableOperators = {
  'OM': 'Orange Money',
  'MOOV': 'Moov Money',
  'TELECEL': 'Telecel Money',
  'MTN': 'MTN Money',
};
