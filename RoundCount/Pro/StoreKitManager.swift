import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case purchased
        case cancelled
        case failed(String)
    }

    // ✅ Only monthly + yearly
    static let proMonthlyID = "roundcount.pro.monthly"
    static let proYearlyID  = "roundcount.pro.yearly"

    private let productIDs: [String] = [
        StoreKitManager.proMonthlyID,
        StoreKitManager.proYearlyID
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    var monthly: Product? { products.first(where: { $0.id == Self.proMonthlyID }) }
    var yearly: Product?  { products.first(where: { $0.id == Self.proYearlyID }) }

    private var updatesTask: Task<Void, Never>?

    deinit { updatesTask?.cancel() }

    func start() {
        if updatesTask == nil {
            updatesTask = Task { await listenForTransactions() }
        }
    }

    func loadProducts() async {
        print("🧾 StoreKit: loading products for ids:", productIDs)

        do {
            let fetched = try await Product.products(for: productIDs)

            print("🧾 StoreKit: fetched count =", fetched.count)
            print("🧾 StoreKit: fetched ids =", fetched.map(\.id))

            products = fetched.sorted(by: { $0.displayName < $1.displayName })
        } catch {
            print("❌ loadProducts failed: \(error)")
            products = []
        }
    }

    func purchase(_ product: Product) async -> Transaction? {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await tx.finish()
                purchaseState = .purchased
                return tx

            case .userCancelled:
                purchaseState = .cancelled
                return nil

            case .pending:
                purchaseState = .idle
                return nil

            @unknown default:
                purchaseState = .failed("Unknown purchase result.")
                return nil
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
            return nil
        }
    }

    func restorePurchases() async {
        do { try await AppStore.sync() }
        catch { print("❌ restore failed: \(error)") }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let tx = try checkVerified(result)
                await tx.finish()
            } catch {
                print("❌ Transaction update failed verification: \(error)")
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreKitError.notEntitled
        }
    }
}
