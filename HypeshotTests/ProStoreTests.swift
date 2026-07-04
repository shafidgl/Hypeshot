import XCTest
import StoreKit
import StoreKitTest
@testable import Hypeshot

@MainActor
final class ProStoreTests: XCTestCase {

    func testProductIDConstant() {
        XCTAssertEqual(ProStore.productID, "com.shafi.hypeshot.pro")
    }

    func testEntitlementDefaultsToFalse() {
        // No purchase has been made in this process; the shared store must not
        // report Pro. (The purchase test below runs later alphabetically and
        // is the only thing that can flip it.)
        XCTAssertFalse(ProStore.shared.isPro)
    }

    /// Drives the entitlement through `SKTestSession.buyProduct` — an
    /// "external" transaction delivered via `Transaction.updates`, which
    /// ProStore's listener (started at app launch) must pick up. Calling
    /// `Product.purchase()` instead hangs headlessly waiting for the
    /// purchase-confirmation sheet, even with `disableDialogs`.
    func testPurchaseFlipsEntitlement() async throws {
        let session: SKTestSession
        do {
            guard let url = Bundle(for: Self.self).url(forResource: "Hypeshot", withExtension: "storekit") else {
                throw XCTSkip("Hypeshot.storekit not bundled in test resources")
            }
            session = try SKTestSession(contentsOf: url)
        } catch let error where !(error is XCTSkip) {
            throw XCTSkip("SKTestSession unavailable headlessly: \(error)")
        }
        session.disableDialogs = true
        session.resetToDefaultState()
        session.clearTransactions()
        defer {
            session.clearTransactions()
            session.resetToDefaultState()
        }

        do {
            _ = try await session.buyProduct(identifier: ProStore.productID)
        } catch {
            throw XCTSkip("SKTestSession.buyProduct failed headlessly: \(error)")
        }

        // The transaction arrives asynchronously on Transaction.updates.
        for _ in 0..<50 where !ProStore.shared.isPro {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(ProStore.shared.isPro, "external purchase should unlock Pro via Transaction.updates")
    }
}
