//
//  CertificatesView.swift
//  Vendor
//

import SwiftUI

struct CertificatesView: View {
	@State private var store = CertificateStore.shared
	@State private var isImporting = false

	/// Certificates bucketed the way the design groups them.
	private var groups: [(title: String, items: [StoredCertificate])] {
		let order = ["Enterprise", "Developer", "Revoked"]
		let buckets = Dictionary(grouping: store.certificates, by: \.group)
		return order.compactMap { key in
			guard let items = buckets[key], !items.isEmpty else { return nil }
			return (key, items)
		}
	}

	var body: some View {
		Screen(t("tab.certificates"), toolbar: AnyView(addButton)) {
			if store.certificates.isEmpty {
				emptyState
			} else {
				ForEach(groups, id: \.title) { group in
					VStack(alignment: .leading, spacing: 8) {
						SectionLabel(text: group.title)
						VStack(spacing: 8) {
							ForEach(group.items) { item in
								SwipeToDelete { store.delete(item) } content: {
									row(for: item)
								}
							}
						}
					}
				}
			}
		}
		.sheet(isPresented: $isImporting) {
			NewCertificateView()
		}
		.onAppear { store.reload() }
	}

	private var addButton: some View {
		Button { isImporting = true } label: {
			Image(systemName: "plus")
				.font(.system(size: 15, weight: .bold))
				.foregroundStyle(.white)
				.frame(width: 34, height: 34)
				.background(Circle().fill(LinearGradient.brand))
		}
	}

	// MARK: Row

	private func row(for item: StoredCertificate) -> some View {
		HStack(spacing: 12) {
			FaceGlyph(mood: mood(for: item), tint: tint(for: item), size: 44)

			VStack(alignment: .leading, spacing: 3) {
				Text(item.name)
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
					.lineLimit(1)
				Text(item.issuer ?? t("certs.unknownTeam"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.lineLimit(1)
				stateLabel(for: item)
			}

			Spacer(minLength: 8)

			expiryBlock(for: item)
		}
		.statusCard(padding: 11, glow: tint(for: item))
	}

	@ViewBuilder
	private func stateLabel(for item: StoredCertificate) -> some View {
		switch item.health() {
		case .valid:
			Text(t("home.active"))
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(Color.ok)
		case .expiring:
			// Must not read "Active" in green while everything else on the
			// row is amber.
			Text(t("home.expiringSoon"))
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(Color.warn)
		case .expired:
			Text(t("home.expired"))
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(Color.bad)
		case .rejected:
			Text(t("home.rejected"))
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(Color.bad)
		}
	}

	@ViewBuilder
	private func expiryBlock(for item: StoredCertificate) -> some View {
		switch item.health() {
		case .valid(let days):
			expiry(caption: "Expires in", value: "\(days) days", tint: .ok)
		case .expiring(let days):
			expiry(caption: "Expires in", value: "\(days) days", tint: .warn)
		case .expired(let days):
			expiry(caption: "Expired", value: "\(days) days ago", tint: .bad)
		case .rejected:
			expiry(caption: "Engine", value: "Rejected", tint: .bad)
		}
	}

	private func expiry(caption: String, value: String, tint: Color) -> some View {
		VStack(alignment: .trailing, spacing: 1) {
			Text(caption)
				.font(.system(size: 10))
				.foregroundStyle(Color.inkSecondary)
			Text(value)
				.font(.system(size: 13, weight: .bold))
				.foregroundStyle(tint)
		}
	}

	private func mood(for item: StoredCertificate) -> FaceGlyph.Mood {
		switch item.health() {
		case .valid:              return .happy
		case .expiring:           return .neutral
		case .expired, .rejected: return .sad
		}
	}

	/// Green while it can still sign, amber as the deadline closes, red once
	/// it cannot — same language as the Home panel.
	private func tint(for item: StoredCertificate) -> Color {
		switch item.health() {
		case .valid:    return .ok
		case .expiring: return .warn
		default:        return .bad
		}
	}

	// MARK: Empty

	private var emptyState: some View {
		VStack(spacing: 10) {
			GlyphTile(systemName: "shield", size: 54)
			Text(t("certs.empty"))
				.font(.system(size: 17, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
			Text(t("certs.emptyDetail"))
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
				.multilineTextAlignment(.center)
			Button { isImporting = true } label: {
				Text(t("home.importCertificate"))
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(.white)
					.padding(.horizontal, 22)
					.padding(.vertical, 10)
					.background(Capsule().fill(LinearGradient.brand))
			}
			.padding(.top, 4)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 34)
		.card()
	}
}
