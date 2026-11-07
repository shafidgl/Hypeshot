import AppKit
import StoreKit
import SwiftUI

/// Single source of truth for the "Unlock Pro" entitlement.
/// All feature gating reads `isPro`; nothing else stores entitlement state.
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    static let productID = "com.shafi.hypeshot.pro"

    /// The GitHub / direct-download build (`-configuration Direct`, defines DIRECT_DOWNLOAD)
    /// has no StoreKit: Pro is sold only through the Mac App Store, so the paywall links there.
#if DIRECT_DOWNLOAD
    static let isDirectDownload = true
#else
    static let isDirectDownload = false
#endif
    static let macAppStoreURL = URL(string: "https://apps.apple.com/app/hypeshot-pro/id6787453009?mt=12")!

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var purchaseInProgress = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {}

    /// Called once at launch: load the product, check current entitlement,
    /// and keep listening for transaction updates (Ask to Buy, refunds,
    /// purchases from another device).
    func start() async {
#if FORCE_PRO
        // Personal build (SWIFT_ACTIVE_COMPILATION_CONDITIONS=FORCE_PRO):
        // Pro is unlocked at compile time and StoreKit is bypassed entirely.
        // Never defined in normal Debug/Release builds.
        isPro = true
#elseif DIRECT_DOWNLOAD
        isPro = false
#else
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
        await refreshEntitlement()
        await loadProduct()
#endif
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            lastError = "Could not load product info. Check your network connection."
        }
    }

    func purchase() async {
        if Self.isDirectDownload {
            NSWorkspace.shared.open(Self.macAppStoreURL)
            return
        }
        guard !purchaseInProgress else { return }
        if product == nil { await loadProduct() }
        guard let product else { return }

        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isPro = true
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restore() async {
        if Self.isDirectDownload {
            NSWorkspace.shared.open(Self.macAppStoreURL)
            return
        }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPro { lastError = "No previous purchase found for this Apple Account." }
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

#if DEBUG
    /// Marketing-screenshot showcase only — never reachable in release builds.
    func debugUnlockForShowcase() { isPro = true }
#endif

    private func refreshEntitlement() async {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                isPro = true
                return
            }
        }
        isPro = false
    }

    private func handle(_ update: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = update,
              transaction.productID == Self.productID else { return }
        isPro = transaction.revocationDate == nil
        await transaction.finish()
    }
}
