import Foundation
import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
import Combine
#endif

/// RevenueCat integration (Shipaton requirement: at least one purchase powered by
/// the RevenueCat SDK).
///
/// Setup:
///  1. Create a free account at app.revenuecat.com, add this app, create a
///     subscription product + an entitlement named "pro" + a default offering.
///  2. Paste your public Apple API key below.
/// Until a key is set, the app runs in free mode so development isn't blocked.
@MainActor
final class PurchaseManager: ObservableObject {

    static let apiKey = "appl_YunmormUVViYYcUMOdYTEzEAQRU"
    static let entitlementID = "pro"
    private static let freeScanLimit = 2
    private static let freeLetterLimit = 2

    @Published var isPro = false
    @Published var packages: [PurchasePackage] = []
    @Published var isConfigured = false
    @Published var lastError: String?
    /// Published so the "free scans remaining" label refreshes immediately.
    @Published private(set) var scanCount: Int = UserDefaults.standard.integer(forKey: "scanCount")

    struct PurchasePackage: Identifiable {
        let id: String
        let title: String
        let priceString: String
        /// Billing period in plain words, e.g. "month". Empty when unknown.
        let period: String
        /// Length of the free trial in plain words, e.g. "1 week". Nil when the
        /// product has no free trial or this customer isn't eligible for it, so the
        /// paywall never promises a trial Apple won't give.
        var freeTrial: String? = nil
        #if canImport(RevenueCat)
        let rcPackage: Package
        #endif

        /// Apple requires the subscription length to appear alongside the price.
        var priceWithPeriod: String {
            period.isEmpty ? priceString : "\(priceString) per \(period)"
        }
    }

    /// Free tier: first scans are free; afterwards analysis requires Pro.
    /// `!isConfigured` = no RevenueCat key yet (development builds): never gate, or
    /// testing would dead-end at a paywall that can't complete a purchase.
    var canScan: Bool { isPro || !isConfigured || scanCount < Self.freeScanLimit }
    var freeScansRemaining: Int { max(0, Self.freeScanLimit - scanCount) }

    /// Bills a letter has been opened for. Letters have their own allowance, so a
    /// free user who spends their last scan can still get the letter for that bill.
    /// Reopening a letter already opened is always free.
    @Published private(set) var letterBillIDs: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: "letterBillIDs") ?? [])

    func canOpenLetter(for billID: UUID) -> Bool {
        isPro || !isConfigured || letterBillIDs.contains(billID.uuidString)
            || letterBillIDs.count < Self.freeLetterLimit
    }

    func recordLetter(for billID: UUID) {
        guard !isPro, letterBillIDs.insert(billID.uuidString).inserted else { return }
        UserDefaults.standard.set(Array(letterBillIDs), forKey: "letterBillIDs")
    }

    func recordScan() {
        scanCount += 1
        UserDefaults.standard.set(scanCount, forKey: "scanCount")
    }

    // MARK: Lifecycle

    func configure() {
        #if canImport(RevenueCat)
        guard Self.apiKey.hasPrefix("appl_") else { return }  // placeholder guard
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        isConfigured = true
        Task { await refresh() }
        #endif
    }

    func refresh() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements[Self.entitlementID]?.isActive == true
            let offerings = try await Purchases.shared.offerings()
            var loaded: [PurchasePackage] = []
            for package in offerings.current?.availablePackages ?? [] {
                let product = package.storeProduct
                loaded.append(PurchasePackage(
                    id: package.identifier,
                    title: product.localizedTitle,
                    priceString: product.localizedPriceString,
                    period: Self.periodName(for: package.packageType),
                    freeTrial: await Self.freeTrialLength(for: product),
                    rcPackage: package))
            }
            packages = loaded
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    #if canImport(RevenueCat)
    private static let unavailableMessage =
        "The App Store couldn't complete this purchase right now. Please try again in a moment."

    /// The free trial's length in plain words, only when Apple would actually grant
    /// it: the product has a free-trial introductory offer AND this customer is
    /// eligible (Apple gives one introductory offer per subscription group).
    private static func freeTrialLength(for product: StoreProduct) async -> String? {
        #if DEBUG
        // Launch with -previewFreeTrial to see the trial paywall before the offer
        // exists in App Store Connect. Never compiled into release builds.
        if ProcessInfo.processInfo.arguments.contains("-previewFreeTrial") { return "1 week" }
        #endif
        guard let offer = product.introductoryDiscount, offer.paymentMode == .freeTrial,
              await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product) == .eligible
        else { return nil }
        return trialWords(value: offer.subscriptionPeriod.value, unit: offer.subscriptionPeriod.unit)
    }

    /// "1 week", "3 days", "2 months". StoreKit reports a week-long trial as either
    /// 1 week or 7 days depending on the OS version, so whole weeks are normalised.
    static func trialWords(value: Int, unit: SubscriptionPeriod.Unit) -> String {
        var value = value
        var word: String
        switch unit {
        case .day:
            if value % 7 == 0 { value /= 7; word = "week" } else { word = "day" }
        case .week:  word = "week"
        case .month: word = "month"
        case .year:  word = "year"
        @unknown default: word = "day"
        }
        if value != 1 { word += "s" }
        return "\(value) \(word)"
    }

    private func buy(_ package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        guard !result.userCancelled else { return }
        isPro = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
    }

    /// Turns RevenueCat's package type into the wording Apple wants shown.
    private static func periodName(for type: PackageType) -> String {
        switch type {
        case .weekly:     return "week"
        case .monthly:    return "month"
        case .twoMonth:   return "2 months"
        case .threeMonth: return "3 months"
        case .sixMonth:   return "6 months"
        case .annual:     return "year"
        default:          return ""
        }
    }
    #endif

    func purchase(_ package: PurchasePackage) async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        lastError = nil
        do {
            try await buy(package.rcPackage)
        } catch ErrorCode.productNotAvailableForPurchaseError {
            // The product StoreKit handed out earlier can go stale. Fetch it again and
            // try once more before showing anything.
            await refresh()
            guard let fresh = packages.first(where: { $0.id == package.id }) else {
                lastError = Self.unavailableMessage
                return
            }
            do { try await buy(fresh.rcPackage) }
            catch ErrorCode.productNotAvailableForPurchaseError { lastError = Self.unavailableMessage }
            catch { lastError = error.localizedDescription }
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func restore() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPro = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }
}
