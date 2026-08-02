//
//  GuideContent.swift
//  Vendor
//
//  Help text shipped with the app. Steps were checked against Apple's own
//  documentation and current iOS behaviour — notably that iOS 18 and later
//  restart the device when you trust an enterprise developer, which earlier
//  releases did not.
//

import Foundation

struct GuideEntry: Identifiable {
	/// Fixed slug, not a UUID: these entries are rebuilt on every render so the
	/// language can change under them, and a fresh UUID each time would give
	/// ForEach a brand new identity on every pass.
	let id: String
	let title: String
	let detail: String
	let glyph: String
	let blocks: [GuideBlock]
}

enum GuideBlock: Identifiable {
	case heading(String)
	case paragraph(String)
	case steps([String])
	case note(String)
	case warning(String)

	var id: String {
		switch self {
		case .heading(let t):   return "h\(t)"
		case .paragraph(let t): return "p\(t)"
		case .steps(let s):     return "s\(s.first ?? "")"
		case .note(let t):      return "n\(t)"
		case .warning(let t):   return "w\(t)"
		}
	}

	/// Everything inside this block that somebody might search for.
	var searchText: String {
		switch self {
		case .heading(let t), .paragraph(let t), .note(let t), .warning(let t):
			return t
		case .steps(let items):
			return items.joined(separator: " ")
		}
	}
}

extension GuideEntry {
	/// Title, subtitle and every word of the body.
	///
	/// The search field used to look at the first two only, which meant the one
	/// place a reader goes when they are stuck could not find the sentence they
	/// were stuck on. Searching "kravasign" or "Developer Mode" returned
	/// nothing, though both are in the text.
	var searchText: String {
		([title, detail] + blocks.map(\.searchText)).joined(separator: " ")
	}
}

enum GuideContent {
	/// Getting a certificate comes first because nothing else works without one.
	static var all: [GuideEntry] { [certificate, installing, trusting, refreshing, faq] }

	// MARK: Certificate

	static var certificate: GuideEntry { GuideEntry(
		id: "certificate",
		title: t("guide.cert.title"),
		detail: t("guide.cert.detail"),
		glyph: "person.badge.key",
		blocks: [
			.paragraph(t("guide.cert.p1")),

			.heading(t("guide.cert.h1")),
			.steps([
				t("guide.cert.s1"),
				t("guide.cert.s2"),
			]),
			.note(t("guide.cert.note1")),

			.heading(t("guide.cert.h2")),
			.steps([
				t("guide.cert.s3"),
				t("guide.cert.s4"),
				t("guide.cert.s5"),
			]),

			.heading(t("guide.cert.h3")),
			.steps([
				t("guide.cert.s6"),
				t("guide.cert.s7"),
			]),

			.warning(t("guide.cert.warn")),
		]
	) }

	// MARK: Installing

	static var installing: GuideEntry { GuideEntry(
		id: "installing",
		title: t("guide.install.title"),
		detail: t("guide.install.detail"),
		glyph: "iphone",
		blocks: [
			.paragraph(t("guide.install.p1")),

			.heading(t("guide.install.h1")),
			.steps([
				t("guide.install.s1"),
				t("guide.install.s2"),
			]),

			.heading(t("guide.install.h2")),
			.steps([
				t("guide.install.s3"),
				t("guide.install.s4"),
				t("guide.install.s5"),
				t("guide.install.s6"),
			]),

			.note(t("guide.install.note")),

			.warning(t("guide.install.warn")),
		]
	) }

	// MARK: Trusting

	static var trusting: GuideEntry { GuideEntry(
		id: "trusting",
		title: t("guide.trust.title"),
		detail: t("guide.trust.detail"),
		glyph: "checkmark.shield",
		blocks: [
			.paragraph(t("guide.trust.p1")),

			.heading(t("guide.trust.h1")),
			.steps([
				t("guide.trust.s1"),
				t("guide.trust.s2"),
				t("guide.trust.s3"),
				t("guide.trust.s4"),
				t("guide.trust.s5"),
			]),

			.warning(t("guide.trust.warn")),

			.note(t("guide.trust.note")),
		]
	) }

	// MARK: Refreshing

	static var refreshing: GuideEntry { GuideEntry(
		id: "refreshing",
		title: t("guide.refresh.title"),
		detail: t("guide.refresh.detail"),
		glyph: "arrow.triangle.2.circlepath",
		blocks: [
			.paragraph(t("guide.refresh.p1")),

			.heading(t("guide.refresh.h1")),
			.steps([
				t("guide.refresh.s1"),
				t("guide.refresh.s2"),
				t("guide.refresh.s3"),
			]),

			.heading(t("guide.refresh.h2")),
			.steps([
				t("guide.refresh.s4"),
				t("guide.refresh.s5"),
				t("guide.refresh.s6"),
			]),

			.note(t("guide.refresh.note")),

			.warning(t("guide.refresh.warn")),
		]
	) }

	// MARK: FAQ

	static var faq: GuideEntry { GuideEntry(
		id: "faq",
		title: t("guide.faq.title"),
		detail: t("guide.faq.detail"),
		glyph: "questionmark.circle",
		blocks: [
			.heading(t("guide.faq.h1")),
			.paragraph(t("guide.faq.p1")),

			.heading(t("guide.faq.h2")),
			.paragraph(t("guide.faq.p2")),

			.heading(t("guide.faq.h3")),
			.paragraph(t("guide.faq.p3")),

			.heading(t("guide.faq.h4")),
			.paragraph(t("guide.faq.p4")),

			.heading(t("guide.faq.h5")),
			.paragraph(t("guide.faq.p5")),

			.warning(t("guide.faq.warn")),
		]
	) }
}
