import Flutter
import UIKit
import UserNotifications
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets reminders show as banners while the app is open.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerAppIconChannel(messenger: engineBridge.applicationRegistrar.messenger())
    registerLabelOcrChannel(messenger: engineBridge.applicationRegistrar.messenger())
    registerShortcutsChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  /// Siri and Shortcuts (LogbiteShortcuts.swift). The intents call "request"
  /// on Dart when they leave a "log this" request while the app runs; Dart
  /// calls "itemsChanged" after publishing new meals or foods, so Siri learns
  /// their names.
  private func registerShortcutsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "logbite/shortcuts", binaryMessenger: messenger)
    ShortcutsStore.notifyApp = {
      DispatchQueue.main.async { channel.invokeMethod("request", arguments: nil) }
    }
    channel.setMethodCallHandler { call, result in
      guard call.method == "itemsChanged" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 16.0, *) {
        LogbiteShortcuts.updateAppShortcutParameters()
      }
      result(nil)
    }
  }

  /// The nutrition label scan: "recognize" takes the path of a photo and
  /// returns its lines of text with their positions, read on the device by
  /// Vision. The Dart side (core/label_scan.dart) turns them into a table.
  private func registerLabelOcrChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "logbite/label_ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String,
        let image = UIImage(contentsOfFile: path),
        let cgImage = image.cgImage
      else {
        result(FlutterError(code: "unreadable", message: "The photo could not be opened", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let lines = try AppDelegate.recognizeLabelText(
            cgImage, orientation: AppDelegate.cgOrientation(image.imageOrientation))
          DispatchQueue.main.async { result(lines) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  /// Each line of text in the image as "text", the middle of its left edge
  /// ("x1", "y1") and of its right edge ("x2", "y2"), and its "height", in
  /// pixels from the top left of the upright image.
  private static func recognizeLabelText(
    _ image: CGImage, orientation: CGImagePropertyOrientation
  ) throws -> [[String: Any]] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Numbers and units, not prose: language correction would "fix" them.
    request.usesLanguageCorrection = false
    try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
      .perform([request])
    let sideways = [.left, .leftMirrored, .right, .rightMirrored].contains(orientation)
    let w = Double(sideways ? image.height : image.width)
    let h = Double(sideways ? image.width : image.height)
    return (request.results ?? []).compactMap { o in
      guard let candidate = o.topCandidates(1).first else { return nil }
      // Vision's points are 0...1 from the bottom left.
      return [
        "text": candidate.string,
        "x1": Double(o.topLeft.x + o.bottomLeft.x) / 2 * w,
        "y1": (1 - Double(o.topLeft.y + o.bottomLeft.y) / 2) * h,
        "x2": Double(o.topRight.x + o.bottomRight.x) / 2 * w,
        "y2": (1 - Double(o.topRight.y + o.bottomRight.y) / 2) * h,
        "height": hypot(
          Double(o.topLeft.x - o.bottomLeft.x) * w, Double(o.topLeft.y - o.bottomLeft.y) * h),
      ]
    }
  }

  private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }

  /// The app icon picker (Pro): "get" returns the alternate icon's name or
  /// nil for the primary icon; "set" takes a name, or nil to go back to it.
  /// The names are the alternate icon sets in Assets.xcassets.
  private func registerAppIconChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "logbite/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "get":
        result(UIApplication.shared.alternateIconName)
      case "set":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(code: "unsupported", message: "Alternate icons are not supported", details: nil))
          return
        }
        UIApplication.shared.setAlternateIconName(call.arguments as? String) { error in
          if let error = error {
            result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
