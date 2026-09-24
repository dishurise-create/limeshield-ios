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
            packages = (offerings.current?.availablePackages ?? []).map {
                PurchasePackage(id: $0.identifier,
                                title: $0.storeProduct.localizedTitle,
                                priceString: $0.storeProduct.localizedPriceString,
                                period: Self.periodName(for: $0.packageType),
                                rcPackage: $0)
            }
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    #if canImport(RevenueCat)
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
        do {
            let result = try await Purchases.shared.purchase(package: package.rcPackage)
            isPro = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func restore() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPro = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }
}
