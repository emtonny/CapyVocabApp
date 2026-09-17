import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Reuse the Android channel already shipped for Library. Never probe Supabase.
Future<bool> chatNetworkAvailable() async {
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    return await const MethodChannel('com.capyvocab.app/network_status')
            .invokeMethod<bool>('isNetworkAvailable') ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
