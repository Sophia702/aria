import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let healthStore = HKHealthStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupHeartRateChannel(registry: engineBridge.pluginRegistry)
  }

  // MARK: – Heart Rate method channel

  private func setupHeartRateChannel(registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AriaHeartRate") else { return }
    let channel = FlutterMethodChannel(
      name: "aria/heartrate",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "requestAuth":
        self.requestAuth(result: result)
      case "latestBPM":
        self.latestBPM(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestAuth(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      result(false)
      return
    }
    // Use the ObjC wrapper so NSExceptions (e.g. missing purpose strings on iOS 26)
    // are caught with @try/@catch rather than crashing the process.
    HealthKitWrapper.requestAuth(
      store: healthStore,
      readTypes: [hrType]
    ) { success in
      result(success)
    }
  }

  private func latestBPM(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    else {
      NSLog("[aria] HealthKit not available")
      result(nil)
      return
    }
    // Search the last 2 hours so we catch even infrequent watch syncs.
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
          NSLog("[aria] No HR samples found in last 2 hours")
          result(nil)
          return
        }
        let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        NSLog("[aria] HR reading: %.0f BPM from %@", bpm, sample.endDate.description)
        result(bpm)
      }
    }
    healthStore.execute(query)
  }
}
