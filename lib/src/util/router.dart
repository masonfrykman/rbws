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

  void register(RBWSMethod method, String path,
      {required FutureOr<RBWSResponse> Function(
              RBWSRequest, Map<String, String>)
          handler}) {
    if (path.isEmpty) return;
    if (path == "/") {
      rootHandler = (RBWSRequest request) => handler(request, {});
      return;
    }

    if (!_tree.containsKey(method)) {
      _tree[method] = {};
    }

    final components = path.split("/");

    // Try to find a top level entry that shares the same top component
    bool foundTopLevelEntry = false;

    for (final entry in _tree[method]!) {
      if (entry.component == components.first) {
        entry.insert(method, components, handler: handler);
        foundTopLevelEntry = true;
        break;
      }
    }

    if (!foundTopLevelEntry) {
      final _RTEntry tle = _RTEntry(components.first);
      tle.insert(method, components, handler: handler);
      _tree[method]!.add(tle);
    }
  }
}

class _RTEntry {
  String component; // ex. "/one/two/three" -> "two" or "three"
  Set<_RTEntry> children = {};
  FutureOr<RBWSResponse> Function(RBWSRequest, Map<String, String>)?
      endpointHandler;

  bool get isEndpoint => endpointHandler != null;

  _RTEntry(this.component, {this.endpointHandler});

  bool _isPlaceholderPattern(String component) =>
      component.startsWith("<") && component.endsWith(">") && component != "<>";

  FutureOr<RBWSResponse?> handleDown(RBWSRequest req, List<String> pathStack,
      Map<String, String> placeholders) async {
    if (pathStack.isEmpty) return null;

    final pop = pathStack.removeAt(0);
    if (!_isPlaceholderPattern(component) && pop != component) {
      return null; // not for us.
    }

    if (_isPlaceholderPattern(component)) {
      String key = component.substring(1, component.length - 1);
      placeholders[key] = pop;
    }

    if (pathStack.isEmpty && this.isEndpoint) {
      // we're the leaf
      return endpointHandler!(req, placeholders);
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

  void insert(RBWSMethod method, List<String> componentStack,
      {required FutureOr<RBWSResponse> Function(
              RBWSRequest, Map<String, String>)
          handler}) {
    if (componentStack.isEmpty) {}

    // Pop top component off the stack
    final pop = componentStack.removeAt(0);
    // TODO: finish writing this fn
  }
}
