class Signature {
  final List<Parameter> positional;
  final List<Parameter> named;

  List<Parameter> get required =>
      positional.where((p) => p.isRequired).toList();

  List<Parameter> get optional =>
      positional.where((p) => p.isOptional).toList();

  bool get hasRest => positional.any((p) => p.isRest);

  Signature(this.positional, this.named);

  String toString() {
    var result = positional.join(", ");
    if (named.isNotEmpty) {
      if (positional.isNotEmpty) result += ", ";
      result += "{${named.join(', ')}}";
    }
    return result;
  }
}

class Parameter {
  /// May be null. Would be actual type in real implementation.
  final String type;

  final String name;

  /// Only one parameter in a signature can set this.
  final bool isRest;

  final bool isOptional;

  final Object defaultValue;

  bool get isRequired => !isOptional && !isRest;

  Parameter(
      this.type, this.name, this.isRest, this.isOptional, this.defaultValue);

  String toString() {
    var result = "";
    if (type != null) result = "$type ";

    if (isRest) result += "*";
    result += name;

    if (isOptional) result += " = $defaultValue";

    return result;
  }
}

class Argument {
  /// Optional. Null if positional argument.
  final String name;

  final Object value;

  // TODO: Type.

  Argument(this.name, this.value);

  String toString() {
    var result = "";
    if (name != null) result = "$name: ";
    return "$result$value";
  }
}
