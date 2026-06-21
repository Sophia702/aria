import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let healthStore = HKHealthStore()
  private var heartRateChannel: FlutterMethodChannel?
  private var cadenceChannel: FlutterMethodChannel?

  // Cadence state
  private var cadenceQuery: HKAnchoredObjectQuery?
  private var stepAnchor: HKQueryAnchor?
  private var latestCadenceSPM: Double = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    // ── Heart rate channel ────────────────────────────────────────────────
    let hrCh = FlutterMethodChannel(name: "aria/heartrate", binaryMessenger: messenger)
    heartRateChannel = hrCh
    hrCh.setMethodCallHandler { [weak self] call, result in
      NSLog("[aria] heartrate: %@", call.method)
      guard let self = self else { return }
      switch call.method {
      case "requestAuth": self.requestHrAuth(result: result)
      case "latestBPM":   self.latestBPM(result: result)
      default:            result(FlutterMethodNotImplemented)
      }
    }

    // ── Cadence channel ───────────────────────────────────────────────────
    let cadCh = FlutterMethodChannel(name: "aria/cadence", binaryMessenger: messenger)
    cadenceChannel = cadCh
    cadCh.setMethodCallHandler { [weak self] call, result in
      NSLog("[aria] cadence: %@", call.method)
      guard let self = self else { return }
      switch call.method {
      case "requestAuth":  self.requestCadenceAuth(result: result)
      case "latestSPM":    result(self.latestCadenceSPM > 0 ? self.latestCadenceSPM : nil)
      case "startMonitor": self.startCadenceMonitor(result: result)
      case "stopMonitor":  self.stopCadenceMonitor(result: result)
      default:             result(FlutterMethodNotImplemented)
      }
    }

    NSLog("[aria] channels ready")
  }

  // MARK: – Heart Rate

  private func requestHrAuth(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    else { result(false); return }
    HealthKitWrapper.requestAuth(store: healthStore, readTypes: [hrType]) { success in
      NSLog("[aria] HR auth: %d", success)
      result(success)
    }
  }

  private func latestBPM(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    else { result(nil); return }
    let start = Date().addingTimeInterval(-7200)
    let predicate = HKQuery.predicateForSamples(
      withStart: start, end: Date(), options: .strictEndDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: hrType, predicate: predicate, limit: 1, sortDescriptors: [sort]
    ) { _, samples, error in
      DispatchQueue.main.async {
        if let error = error {
          NSLog("[aria] HR error: %@", error.localizedDescription)
          result(nil); return
        }
        guard let sample = samples?.first as? HKQuantitySample else { result(nil); return }
        let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        NSLog("[aria] HR: %.0f BPM", bpm)
        result(bpm)
      }
    }
    healthStore.execute(query)
  }

  // MARK: – Cadence (Apple Watch step count → SPM)

  private func requestCadenceAuth(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
    else { result(false); return }
    HealthKitWrapper.requestAuth(store: healthStore, readTypes: [stepType]) { success in
      NSLog("[aria] cadence auth: %d", success)
      result(success)
    }
  }

  private func startCadenceMonitor(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
    else { result(false); return }

    // Seed with the last 10 s to have an anchor; updates fire for new samples.
    let seedStart = Date().addingTimeInterval(-10)
    let predicate = HKQuery.predicateForSamples(
      withStart: seedStart, end: nil, options: .strictStartDate)

    let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
      [weak self] _, samples, _, newAnchor, error in
      guard let self = self else { return }
      if let error = error {
        NSLog("[aria] cadence query error: %@", error.localizedDescription); return
      }
      self.stepAnchor = newAnchor
      if let stepSamples = samples as? [HKQuantitySample], !stepSamples.isEmpty {
        self.processCadenceSamples(stepSamples)
      }
    }

    let query = HKAnchoredObjectQuery(
      type: stepType,
      predicate: predicate,
      anchor: stepAnchor,
      limit: HKObjectQueryNoLimit,
      resultsHandler: handler
    )
    query.updateHandler = handler
    cadenceQuery = query
    healthStore.execute(query)
    NSLog("[aria] cadence monitor started")
    result(true)
  }

  /// Apple Watch stores step samples in short intervals (~1–5 s while walking).
  /// SPM = steps / interval_duration × 60. Average across the batch for stability.
  private func processCadenceSamples(_ samples: [HKQuantitySample]) {
    let valid: [Double] = samples.compactMap { s in
      let steps = s.quantity.doubleValue(for: .count())
      let dur = s.endDate.timeIntervalSince(s.startDate)
      guard dur > 0, steps > 0 else { return nil }
      let spm = (steps / dur) * 60
      return (spm >= 30 && spm <= 250) ? spm : nil
    }
    guard !valid.isEmpty else { return }
    let avg = valid.reduce(0, +) / Double(valid.count)
    latestCadenceSPM = avg
    NSLog("[aria] cadence: %.0f SPM (%d samples)", avg, valid.count)
  }

  private func stopCadenceMonitor(result: @escaping FlutterResult) {
    if let q = cadenceQuery { healthStore.stop(q); cadenceQuery = nil }
    latestCadenceSPM = 0
    result(true)
  }
}

// MARK: – HealthKit authorization helper
//
// Thin wrapper around HKHealthStore.requestAuthorization so the channel handlers
// above stay readable. Read-only — aria never writes Health data.
enum HealthKitWrapper {
  static func requestAuth(
    store: HKHealthStore,
    readTypes: Set<HKObjectType>,
    completion: @escaping (Bool) -> Void
  ) {
    store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
      if let error = error {
        NSLog("[aria] HealthKit auth error: %@", error.localizedDescription)
      }
      DispatchQueue.main.async { completion(success) }
    }
  }

  /// Array overload — call sites pass `[hrType]` / `[stepType]`.
  static func requestAuth(
    store: HKHealthStore,
    readTypes: [HKObjectType],
    completion: @escaping (Bool) -> Void
  ) {
    requestAuth(store: store, readTypes: Set(readTypes), completion: completion)
  }
}
