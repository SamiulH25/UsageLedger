import 'package:flutter/services.dart';

const deviceActionsChannel = MethodChannel('usageledger/device');

Future<bool> consumeSyncShortcut() async {
  try {
    return await deviceActionsChannel.invokeMethod<bool>('consumeSyncNow') ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<bool> openBatterySettings() async {
  try {
    return await deviceActionsChannel.invokeMethod<bool>(
          'openBatterySettings',
        ) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
