import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.harukoto.app/app_version",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getVersion" else {
        result(FlutterMethodNotImplemented)
        return
      }
      var metadata: [String: String] = [:]
      metadata["version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      metadata["buildNumber"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      result(metadata)
    }
  }
}
