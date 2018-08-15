import 'ast.dart';

bool isSubtype(Signature a, Signature b) {
  // The subtype must have at least as many parameters.
  if (a.positional.length > b.positional.length) return false;

  // Every parameter in the supertype must match the one in the subtype.
  for (var i = 0; i < a.positional.length; i++) {
    var aParam = a.positional[i];
    var bParam = b.positional[i];

    // Types must match.
    // TODO: In a real implementation would do an actual type test.
    if (aParam.type != bParam.type) return false;

    // Rest must match.
    if (aParam.isRest != bParam.isRest) return false;

    // If optional in the supertype, must be optional in the subtype.
    // (Otherwise you could call it with too few arguments.
    // Note that this is not symmetric. It's OK for a parameter to be required
    // in the supertype and optional in the subtype as long as the binding
    // orders match (below).
    if (aParam.isOptional && !bParam.isOptional) return false;

    // Binding order must match.
    if (a.bindingOrder(aParam) != b.bindingOrder(bParam)) return false;
  }

  // If the supertype has a rest parameter, the subtype cannot add any
  // parameters.
  if (a.hasRest && b.positional.length > a.positional.length) return false;

  // Any additional parameters must be optional or rest.
  for (var i = a.positional.length; i < b.positional.length; i++) {
    if (b.positional[i].isRequired) return false;
  }

  return true;
}
