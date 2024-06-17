import 'autorelease_cache.dart';

class HTTPServerInstance {
  dynamic host;
  int port;
  String? generalServeRoot;
  Map<String, String?>? staticRoutes;

  AutoreleasingCache _storage = AutoreleasingCache();

  HTTPServerInstance(this.host, this.port,
      {this.generalServeRoot, this.staticRoutes});
}
