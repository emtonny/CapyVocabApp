import 'package:web/web.dart' as web;

Future<bool> chatNetworkAvailable() async => web.window.navigator.onLine;
