/// Correspondance entre les codes operateur du backend Django
/// (`ORANGE`, `MOOV`, `TELECEL`, `CORIS`) et ceux utilises par le mobile.
class OperatorMapping {
  const OperatorMapping._();

  /// Backend -> (code mobile, nom affiche).
  static ({String code, String name}) fromBackend(String backendOperator) {
    switch (backendOperator.toUpperCase()) {
      case 'ORANGE':
        return (code: 'OM', name: 'Orange Money');
      case 'MOOV':
        return (code: 'MOOV', name: 'Moov Money');
      case 'TELECEL':
        return (code: 'TELECEL', name: 'Telecel Money');
      case 'CORIS':
        return (code: 'CORIS', name: 'Coris Money');
      default:
        return (code: backendOperator.toUpperCase(), name: backendOperator);
    }
  }

  /// Code mobile -> code backend (pour l'envoi).
  static String toBackend(String code) {
    switch (code.toUpperCase()) {
      case 'OM':
        return 'ORANGE';
      default:
        return code.toUpperCase();
    }
  }
}
