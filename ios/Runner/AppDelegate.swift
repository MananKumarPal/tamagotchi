import Flutter
import UIKit
import WidgetKit

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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EgglingWidget") else {
      return
    }
    FlutterMethodChannel(name: "eggling/widget", binaryMessenger: registrar.messenger())
      .setMethodCallHandler(Self.handle)
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "readActions":
      result(WidgetStore.actionLines())
    case "ackActions":
      WidgetStore.ackActions(call.arguments as? Int ?? 0)
      result(nil)
    case "publish":
      let args = call.arguments as? [String: Any]
      if let sprites = args?["sprites"] as? [String: FlutterStandardTypedData] {
        for (pose, png) in sprites {
          WidgetStore.write(png.data, name: "pose_\(pose).png")
        }
      }
      if let json = args?["snapshot"] as? String, let data = json.data(using: .utf8) {
        WidgetStore.write(data, name: "snapshot.json")
      }
      WidgetCenter.shared.reloadAllTimelines()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
