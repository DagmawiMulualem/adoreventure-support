//
//  FirebaseIdeasCallableREST.swift
//  AdoreVenture
//
//  Gen2 idea callables (`getIdeas`, `getSingleIdea`) are invoked via the official HTTPS callable protocol
//  using URLSession instead of `HTTPSCallable`. The Firebase iOS Functions client shares GTMSessionFetcher
//  across callables and Auth; with Gen2 + concurrent app work this often surfaces as
//  "GTMSessionFetcher … was already running" and bogus `UNAUTHENTICATED` (16) despite a valid user.
//
//  Spec: https://firebase.google.com/docs/functions/callable-reference
//
//  Do not link Firebase App Check here unless the **Firebase App Check API** is enabled in Google Cloud and
//  App Check is configured in Firebase Console; otherwise Auth/Firestore spam 403s and Callable auth breaks.

import Foundation

enum FirebaseIdeasCallableREST {
    /// Must match `IDEA_CALL_GEN2.region` in `functions/index.js`.
    private static let region = "us-central1"

    private static let projectId: String = {
        guard
            let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url) as? [String: Any],
            let pid = dict["PROJECT_ID"] as? String,
            !pid.isEmpty
        else { return "adoreventure" }
        return pid
    }()

    /// POST `https://<region>-<project>.cloudfunctions.net/<name>` with `{"data": …}` and Bearer ID token.
    static func invoke(
        functionName: String,
        data: [String: Any],
        bearerToken: String,
        timeoutSeconds: TimeInterval
    ) async throws -> Any? {
        let urlString = "https://\(region)-\(projectId).cloudfunctions.net/\(functionName)"
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "FirebaseIdeasCallableREST",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid callable URL."]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutSeconds

        let envelope: [String: Any] = ["data": data]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: envelope, options: [])
        } catch {
            throw NSError(
                domain: "FirebaseIdeasCallableREST",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to encode callable request.",
                    NSUnderlyingErrorKey: error
                ]
            )
        }

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "com.firebase.functions",
                code: 13,
                userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response from callable."]
            )
        }

        if respData.isEmpty {
            if http.statusCode == 401 {
                throw NSError(
                    domain: "com.firebase.functions",
                    code: 16,
                    userInfo: [NSLocalizedDescriptionKey: "UNAUTHENTICATED"]
                )
            }
            if !(200...299).contains(http.statusCode) {
                throw NSError(
                    domain: "com.firebase.functions",
                    code: 13,
                    userInfo: [NSLocalizedDescriptionKey: "Empty body (HTTP \(http.statusCode))."]
                )
            }
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: respData, options: [.fragmentsAllowed])
        } catch {
            if http.statusCode == 401 {
                throw NSError(
                    domain: "com.firebase.functions",
                    code: 16,
                    userInfo: [NSLocalizedDescriptionKey: "UNAUTHENTICATED"]
                )
            }
            let head = String(data: respData.prefix(240), encoding: .utf8) ?? ""
            throw NSError(
                domain: "com.firebase.functions",
                code: 13,
                userInfo: [
                    NSLocalizedDescriptionKey: "Callable returned non-JSON (HTTP \(http.statusCode)). \(head)"
                ]
            )
        }

        guard let root = jsonObject as? [String: Any] else {
            throw NSError(
                domain: "com.firebase.functions",
                code: 13,
                userInfo: [NSLocalizedDescriptionKey: "Callable JSON root is not an object."]
            )
        }

        if let err = root["error"] as? [String: Any] {
            throw makeFunctionsNSError(from: err, httpStatus: http.statusCode)
        }

        if let result = root["result"] {
            return result
        }
        // Doc sample uses `response` in one place; accept both.
        if let alt = root["response"] {
            return alt
        }

        throw NSError(
            domain: "com.firebase.functions",
            code: 13,
            userInfo: [NSLocalizedDescriptionKey: "Callable response missing result."]
        )
    }

    private static func makeFunctionsNSError(from error: [String: Any], httpStatus: Int) -> NSError {
        let message = error["message"] as? String ?? "Callable error"
        let statusStr = (error["status"] as? String ?? "INTERNAL").uppercased()
        let code = functionsErrorCode(fromGoogleStatus: statusStr)
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message,
            "HTTPStatus": httpStatus,
            "FunctionsErrorStatus": statusStr
        ]
        if let details = error["details"] {
            userInfo["FunctionsErrorDetails"] = details
        }
        return NSError(domain: "com.firebase.functions", code: code, userInfo: userInfo)
    }

    /// Maps `error.status` strings to `FIRFunctionsErrorCode` / client codes (e.g. UNAUTHENTICATED = 16).
    private static func functionsErrorCode(fromGoogleStatus status: String) -> Int {
        switch status {
        case "OK": return 0
        case "CANCELLED": return 1
        case "UNKNOWN": return 2
        case "INVALID_ARGUMENT": return 3
        case "DEADLINE_EXCEEDED": return 4
        case "NOT_FOUND": return 5
        case "ALREADY_EXISTS": return 6
        case "PERMISSION_DENIED": return 7
        case "RESOURCE_EXHAUSTED": return 8
        case "FAILED_PRECONDITION": return 9
        case "ABORTED": return 10
        case "OUT_OF_RANGE": return 11
        case "UNIMPLEMENTED": return 12
        case "INTERNAL": return 13
        case "UNAVAILABLE": return 14
        case "DATA_LOSS": return 15
        case "UNAUTHENTICATED": return 16
        default: return 13
        }
    }
}
