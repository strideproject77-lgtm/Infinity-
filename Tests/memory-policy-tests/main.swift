import Foundation
let ids: Set<String> = ["com.example.strata", "com.example.strata.LiveProcess"]
precondition(StrataMemoryRequestPolicy.matchingTargets(registered: ["unrelated.app"] + Array(ids), allowed: ids) == ids)
precondition(StrataMemoryRequestPolicy.matchingTargets(registered: ["com.example.strata"], allowed: ids) == nil)
precondition(StrataMemoryRequestPolicy.matchingTargets(registered: ["other.account.app"], allowed: ids) == nil)
precondition(StrataMemoryRequestPolicy.matchingTargets(registered: ["com.example.strata"], allowed: ["com.example.strata"]) == nil)
precondition(StrataMemoryRequestPolicy.capabilities == ["INCREASED_MEMORY_LIMIT"])
print("PASS: capability plan includes only current host/guest App IDs; missing IDs rejected; unrelated apps untouched.")

precondition(StrataMemoryRequestPolicy.bundleIdentity(signedID: "TEAM.com.example.strata", team: "TEAM", fallback: "wrong") == "com.example.strata")
precondition(StrataMemoryRequestPolicy.bundleIdentity(signedID: "OTHER.com.example.strata", team: "TEAM", fallback: "installed") == "installed")
precondition(StrataMemoryRequestPolicy.bundleIdentity(signedID: "", team: "TEAM", fallback: "installed") == "installed")
precondition(StrataMemoryRequestPolicy.registrationMatches(bundleIdentifier: "com.example.strata", expectedBundle: "com.example.strata"))
precondition(StrataMemoryRequestPolicy.registrationMatches(bundleIdentifier: "com.example.*", expectedBundle: "com.example.strata.LiveProcess"))
precondition(StrataMemoryRequestPolicy.registrationMatches(bundleIdentifier: "*", expectedBundle: "com.example.strata"))
precondition(!StrataMemoryRequestPolicy.registrationMatches(bundleIdentifier: "com.other.strata", expectedBundle: "com.example.strata"))
precondition(!StrataMemoryRequestPolicy.registrationMatches(bundleIdentifier: "com.example.*", expectedBundle: "com.examples.strata"))
precondition(!StrataMemoryRequestPolicy.registrationMatches(bundleIdentifier: "", expectedBundle: "com.example.strata"))

let registrations: [(identifier: String, bundleIdentifier: String)] = [
    ("host-record", "com.example.strata"),
    ("guest-record", "com.example.strata.LiveProcess"),
    ("shared-record", "com.example.*"),
    ("unrelated-record", "com.other.app")
]
precondition(StrataMemoryRequestPolicy.selectedTargets(host: "host-record", guest: "guest-record", expectedHost: "com.example.strata", expectedGuest: "com.example.strata.LiveProcess", registrations: registrations) == ["host-record", "guest-record"])
precondition(StrataMemoryRequestPolicy.selectedTargets(host: "shared-record", guest: "shared-record", expectedHost: "com.example.strata", expectedGuest: "com.example.strata.LiveProcess", registrations: registrations) == ["shared-record"])
precondition(StrataMemoryRequestPolicy.selectedTargets(host: "unrelated-record", guest: "guest-record", expectedHost: "com.example.strata", expectedGuest: "com.example.strata.LiveProcess", registrations: registrations) == nil)
precondition(StrataMemoryRequestPolicy.selectedTargets(host: "host-record", guest: "unrelated-record", expectedHost: "com.example.strata", expectedGuest: "com.example.strata.LiveProcess", registrations: registrations) == nil)
precondition(StrataMemoryRequestPolicy.selectedTargets(host: "host-record", guest: "", expectedHost: "com.example.strata", expectedGuest: "com.example.strata.LiveProcess", registrations: registrations) == nil)
print("PASS: signed identity normalization, exact/wildcard registration matching, shared registration and wrong-ID rejection.")
