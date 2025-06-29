import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // iOS-specific configurations
    if #available(iOS 13.0, *) {
      // Set preferred status bar style
      window?.overrideUserInterfaceStyle = .unspecified
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // iOS-specific status bar handling
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .default
  }
  
  override var prefersStatusBarHidden: Bool {
    return false
  }
}
