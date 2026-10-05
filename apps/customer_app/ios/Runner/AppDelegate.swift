import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String,
       !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       !apiKey.hasPrefix("REPLACE_WITH_"),
       !apiKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(apiKey)
    } else {
      NSLog("GOOGLE_MAPS_API_KEY is missing from the app configuration")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
