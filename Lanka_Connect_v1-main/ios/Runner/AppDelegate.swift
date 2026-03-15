import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API key for iOS - restrict to Maps SDK for iOS.
    // Cloud Console restrictions:
    // - Application restriction: iOS apps
    // - Allowed bundle ID: com.example.lankaConnect
    GMSServices.provideAPIKey("AIzaSyBzSmMAIjHV0fV1hRtaEzBdn1GguOstvj0")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
