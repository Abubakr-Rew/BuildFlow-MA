/// Form validators returning null on success, error string on failure.
abstract final class Validators {
  static String? email(String? value, {required String requiredMsg, required String invalidMsg}) {
    if (value == null || value.trim().isEmpty) return requiredMsg;
    final regex = RegExp(r'^[\w\-.+]+@[\w\-]+\.[\w\-]{2,}$');
    if (!regex.hasMatch(value.trim())) return invalidMsg;
    return null;
  }

  static String? password(String? value, {required String requiredMsg, required String shortMsg, int minLength = 6}) {
    if (value == null || value.isEmpty) return requiredMsg;
    if (value.length < minLength) return shortMsg;
    return null;
  }

  static String? required(String? value, {required String message}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }
}
