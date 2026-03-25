import Foundation

/// Boxes `HTTPSCallableResult.data` so we can pass it through serialization without `Sendable` issues.
final class AnyCallablePayloadBox: @unchecked Sendable {
    var value: Any?
    init(_ value: Any?) { self.value = value }
}

/// Type-erased `@MainActor` callable body so the serial queue’s operation closure can be `@Sendable`.
private final class MainActorCallableBodyBox: @unchecked Sendable {
    let run: @MainActor () async throws -> Any?
    init(_ run: @escaping @MainActor () async throws -> Any?) { self.run = run }
}

/// Serializes all Firebase HTTPS Callable `.call()` traffic in the process.
///
/// **Why not a Swift `actor`?** Actors are *re-entrant* across `await`: while one caller is suspended
/// inside e.g. `await Task { @MainActor in … }.value`, another caller can enter the same actor and start
/// a second `.call()`. The iOS Functions client shares `GTMSessionFetcher` across callables — overlapping
/// calls produce “GTMSessionFetcher … was already running”, “Result accumulator timeout”, and bogus
/// `UNAUTHENTICATED` (16) even when the user is signed in.
///
/// This gate uses a **chained `Task` queue** so only one operation runs end-to-end at a time.
final class FirebaseHTTPSCallableGate: @unchecked Sendable {
    static let shared = FirebaseHTTPSCallableGate()

    private let lock = NSLock()
    /// Completes after all work scheduled before it on this gate has finished (success or failure).
    private var tail: Task<Void, Never> = Task {}

    private init() {}

    private func runSerialized<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let predecessor: Task<Void, Never>
        lock.lock()
        predecessor = tail
        let thisTask = Task {
            await predecessor.value
            return try await operation()
        }
        tail = Task {
            _ = try? await thisTask.value
        }
        lock.unlock()
        return try await thisTask.value
    }

    func perform<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) async throws -> T {
        try await runSerialized(body)
    }

    /// Use for Callable results whose `.data` is not `Sendable` in Swift 6 strict mode.
    func performCallableData(_ body: @escaping @Sendable () async throws -> Any?) async throws -> Any? {
        let box: AnyCallablePayloadBox = try await runSerialized {
            AnyCallablePayloadBox(try await body())
        }
        return box.value
    }

    /// Serializes globally, then runs the Callable on the **main actor** (Auth + Functions expect main-runloop behavior).
    func performCallableDataOnMainActor(_ body: @escaping @MainActor () async throws -> Any?) async throws -> Any? {
        let boxed = MainActorCallableBodyBox(body)
        return try await runSerialized {
            try await Task { @MainActor in
                try await boxed.run()
            }.value
        }
    }
}
