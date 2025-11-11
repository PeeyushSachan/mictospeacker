import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  private let METHOD = "mic_to_speaker/audio"
  private let EVENT = "mic_to_speaker/level"
  private var eventSink: FlutterEventSink?
  private let audioEngine = AudioEngineIOS.shared

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let messenger = controller.binaryMessenger

    audioEngine.setLevelCallback { [weak self] level in
      self?.emitLevel(level)
    }

    let method = FlutterMethodChannel(name: METHOD, binaryMessenger: messenger)
    method.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "no_app_delegate", message: "AppDelegate deallocated", details: nil))
        return
      }
      switch call.method {
      case "start":
        self.startAudio(result: result)
      case "stop":
        self.audioEngine.stop()
        result(nil)
      case "apply":
        do {
          let params = try self.decodeParams(from: call.arguments)
          self.audioEngine.apply(params)
          result(nil)
        } catch {
          result(FlutterError(code: "invalid_params", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let event = FlutterEventChannel(name: EVENT, binaryMessenger: messenger)
    event.setStreamHandler(self)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startAudio(result: @escaping FlutterResult) {
    requestMicPermission { [weak self] granted in
      guard let self = self else {
        result(false)
        return
      }
      guard granted else {
        result(false)
        return
      }
      do {
        try self.audioEngine.start()
        result(true)
      } catch {
        result(FlutterError(code: "ios_start_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func requestMicPermission(completion: @escaping (Bool) -> Void) {
    let session = AVAudioSession.sharedInstance()
    switch session.recordPermission {
    case .granted:
      completion(true)
    case .denied:
      completion(false)
    case .undetermined:
      session.requestRecordPermission { granted in
        DispatchQueue.main.async {
          completion(granted)
        }
      }
    @unknown default:
      completion(false)
    }
  }

  private func decodeParams(from arguments: Any?) throws -> DspParams {
    guard let dict = arguments as? [String: Any] else {
      throw NSError(domain: "mic_to_speaker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid arguments"])
    }
    let data = try JSONSerialization.data(withJSONObject: dict, options: [])
    return try JSONDecoder().decode(DspParams.self, from: data)
  }

  private func emitLevel(_ level: Double) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(level)
    }
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
