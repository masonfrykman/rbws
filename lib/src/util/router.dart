import 'package:rbws/src/http_helpers/http_method.dart';
import 'package:rbws/src/http_helpers/http_response.dart';
import 'package:rbws/src/http_helpers/http_request.dart';

import 'dart:async';

class RouteTree {
  Map<RBWSMethod, Set<_RTEntry>> _tree = {};
  FutureOr<RBWSResponse> Function(RBWSRequest)?
      rootHandler; // Special handler for "/", any method.

  FutureOr<RBWSResponse?> handle(RBWSRequest req) async {
    // Handle "/"
    if (req.path == "/") {
      if (rootHandler == null) {
        return null;
      }
      return rootHandler!(req);
    }

    // Handle no registered paths for the given method.
    if (!_tree.containsKey(req.method)) {
      return null;
    }

    // Pass it to the root entry for the method.
    for (_RTEntry entry in _tree[req.method]!) {
      final stack = req.path.split("/");
      final attempt = await entry.handleDown(req, stack, {});
      if (attempt != null) {
        return attempt;
      }
    }
    return null;
  }
}

class _RTEntry {
  String component; // ex. "/one/two/three" -> "two" or "three"
  Set<_RTEntry> children = {};
  FutureOr<RBWSResponse> Function(RBWSRequest, String, Map<String, String>)?
      endpointHandler;

  bool get isEndpoint => endpointHandler != null;

  _RTEntry(this.component);

  bool _isWildcardPattern(String component) =>
      component.startsWith("<") && component.endsWith(">") && component != "<>";

  FutureOr<RBWSResponse?> handleDown(RBWSRequest req, List<String> pathStack,
      Map<String, String> placeholders) async {
    if (pathStack.isEmpty) return null;

    final pop = pathStack.removeAt(0);
    if (!_isWildcardPattern(component) && pop != component) {
      return null; // not for us.
    }

    if (_isWildcardPattern(component)) {
      String key = component.substring(1, component.length - 1);
      placeholders[key] = pop;
    }

    if (pathStack.isEmpty && this.isEndpoint) {
      // we're the leaf
      return endpointHandler!(req, pop, placeholders);
    }

    _RTEntry? wildcard;

    // if we're not the leaf (or we're not an endpoint), try to resolve w/ children.
    for (var entry in children) {
      // Put the wildcard on hold for last.
      if (entry.component == "*") {
        wildcard = entry;
        continue;
      }

      final attempt = await entry.handleDown(req, pathStack, placeholders);
      if (attempt != null) {
        return attempt;
      }
    }

    // Last ditch wildcard
    if (wildcard != null) {
      final attempt = wildcard.handleDown(req, pathStack, placeholders);
      return attempt;
    }

    return null;
  }
}
