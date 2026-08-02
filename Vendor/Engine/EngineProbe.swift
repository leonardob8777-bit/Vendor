//
//  EngineProbe.swift
//  Vendor
//
//  Confirms at runtime that the signing engine is linked into the binary.
//

import Foundation

@Observable
final class EngineProbe {
	private(set) var linked = false
	private(set) var detail: String?

	func run() {
		// Calling into the engine with a path that cannot exist is a cheap way to
		// prove the symbol resolved: a missing symbol would fail to launch at all.
		let probePath = NSTemporaryDirectory() + "vendor-engine-probe"
		let signed = SigningEngine.isSigned(executableAt: probePath)
		linked = true
		detail = "checkSigned(probe) → \(signed)"
	}
}
