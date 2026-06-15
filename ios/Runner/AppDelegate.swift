import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let healthStore = HKHealthStore()
  // Retained as a property so ARC doesn't deallocate the channel.
  private var heartRateChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // applicationRegistrar is the correct API for app-level (non-plugin) channels.
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: "aria/heartrate", binaryMessenger: messenger)
    heartRateChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      NSLog("[aria] channel call: %@", call.method)
      guard let self = self else { return }
      switch call.method {
      case "requestAuth": self.requestAuth(result: result)
      case "latestBPM":   self.latestBPM(result: result)
      default:            result(FlutterMethodNotImplemented)
      }
    }
    NSLog("[aria] heart rate channel ready on applicationRegistrar")
  }

  // MARK: – HealthKit

  private func requestAuth(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      NSLog("[aria] HealthKit not available")
      result(false)
      return
    }
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      result(false)
      return
    }
    NSLog("[aria] requesting HealthKit authorization…")
    HealthKitWrapper.requestAuth(
      store: healthStore,
      readTypes: [hrType]
    ) { success in
      NSLog("[aria] HealthKit auth result: %d", success)
      result(success)
    }
  }

  private func latestBPM(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    else {
      result(nil)
      return
    }
    let start = Date().addingTimeInterval(-7200)
    let predicate = HKQuery.predicateForSamples(
      withStart: start, end: Date(), options: .strictEndDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: hrType, predicate: predicate, limit: 1, sortDescriptors: [sort]
    ) { _, samples, error in
      DispatchQueue.main.async {
        if let error = error {
          NSLog("[aria] HR query error: %@", error.localizedDescription)
          result(nil)
          return
        }
        guard let sample = samples?.first as? HKQuantitySample else {
          NSLog("[aria] no HR samples found in last 2 hours")
          result(nil)
          return
        }
        let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        NSLog("[aria] HR reading: %.0f BPM", bpm)
        result(bpm)
      }
    }
    healthStore.execute(query)
  }
}
