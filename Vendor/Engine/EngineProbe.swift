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
		// Asked about Vendor's own binary rather than a path that cannot exist.
		//
		// A missing path answered the question just as well — a symbol that had
		// not resolved would have stopped the launch — but the engine complained
		// about it on stderr every single time (`Failed to initialize ZMachO`),
		// which reads as a fault in the log when it was the probe's own doing.
		// The app's executable is a real Mach-O, so the same call proves the same
		// thing and says nothing.
		guard let executable = Bundle.main.executableURL else {
			linked = false
			detail = "no executable URL"
			return
		}
		let signed = SigningEngine.isSigned(executableAt: executable.path)
		linked = true
		detail = "checkSigned(self) → \(signed)"
	}
}
