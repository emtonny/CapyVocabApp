import 'package:web/web.dart' as web;

Future<bool> friendsNetworkAvailable() async => web.window.navigator.onLine;
