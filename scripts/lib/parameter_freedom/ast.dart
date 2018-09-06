class Signature {
  final List<Parameter> positional;
  final List<Parameter> named;

  List<Parameter> get required =>
      positional.where((p) => p.isRequired).toList();

  List<Parameter> get optional =>
      positional.where((p) => p.isOptional).toList();

  bool get hasRest => positional.any((p) => p.isRest);

  Signature(this.positional, this.named);

  int priority(Parameter param) {
    if (param.isRequired) return required.indexOf(param);
    if (param.isOptional) {
      return optional.indexOf(param) + required.length;
    }

    return positional.length - 1;
  }

  String toString() {
    var sections = <Object>[];
    var optionals = <Object>[];

    finishOptionals() {
      if (optionals.isNotEmpty) {
        sections.add("[${optionals.join(', ')}]");
        optionals.clear();
      }
    }

    for (var parameter in positional) {
      if (parameter.isOptional) {
        optionals.add(parameter);
      } else {
        finishOptionals();
        sections.add(parameter);
      }
    }

    finishOptionals();

    if (named.isNotEmpty) {
      sections.add("{${named.join(', ')}}");
    }

    return sections.join(", ");
  }
}

class Parameter {
  /// May be null. Would be actual type in real implementation.
  final String type;

  final String name;

  /// Only one parameter in a signature can set this.
  final bool isRest;

  final bool isOptional;

  bool get isRequired => !isOptional && !isRest;

  Parameter(
      this.type, this.name, this.isRest, this.isOptional);

  String toString() {
    var result = "";
    if (type != null) result = "$type ";

    if (isRest) result += "...";
    result += name;

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
