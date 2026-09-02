//
//  CertificatesView.swift
//  Vendor
//

import SwiftUI

struct CertificatesView: View {
	@ObservedObject private var store = CertificateStore.shared
	@State private var isImporting = false
	/// Certificate a row was tapped for; drives the detail sheet.
	@State private var selected: StoredCertificate?
	/// Certificate the delete confirmation is asking about — set from inside
	/// the detail sheet, not by the swipe, which already commits on its own.
	@State private var confirmingDelete: StoredCertificate?
	@State private var showingGuide = false
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

	/// Certificates bucketed the way the design groups them.
	///
	/// Driven by `Group.allCases`, so a bucket cannot be left out by forgetting
	/// to add its name somewhere, and nothing depends on the display language.
	private var groups: [(group: StoredCertificate.Group, items: [StoredCertificate])] {
		let buckets = Dictionary(grouping: store.certificates, by: \.group)
		return StoredCertificate.Group.allCases.compactMap { key in
			guard let items = buckets[key], !items.isEmpty else { return nil }
			return (key, items)
		}
	}

	/// The identity Home is currently signing with — same rule as
	/// `HomeView.leadCertificate`, minus its fallback to the most recent
	/// import. That fallback exists so Home never shows a blank panel to
	/// someone who owns a rejected certificate; here it would mislabel a dead
	/// certificate "Main" when nothing is actually leading with it.
	private var leadCertificate: StoredCertificate? { store.leadCertificate() }

	/// Whether any floating window is up — every one of them blurs the list
	/// and hides the tab bar the same way, so they share one flag instead of
	/// each overlay computing its own version of the same condition.
	private var isPresenting: Bool { isImporting || selected != nil || showingGuide }

	var body: some View {
		Screen(
			t("tab.certificates"),
			toolbar: AnyView(addButton),
			contentBlur: isPresenting ? 16 : 0
		) {
			if store.certificates.isEmpty {
				emptyState
			} else {
				ForEach(groups, id: \.group) { group in
					VStack(alignment: .leading, spacing: 8) {
						SectionLabel(text: group.group.title)
							.scrollEdgeSoftening()
						VStack(spacing: 8) {
							ForEach(group.items) { item in
								SwipeToDelete { store.delete(item) } content: {
									row(for: item)
								}
								// Per row, not per group: a group of enough
								// certificates is taller than the screen, and a
								// block that never fits never comes into focus.
								.scrollEdgeSoftening()
							}
						}
					}
				}
			}
		}
		// Not a `.sheet`: a system sheet is presented in its own window, so the
		// screen behind it cannot be blurred, and it arrives by sliding up. Laid
		// over the content it matches every other window in the app.
		//
		// Two `.animation` modifiers, and both are needed. This one sits before
		// the overlay, so it reaches the screen underneath and carries the blur.
		.animation(.easeInOut(duration: 0.25), value: isPresenting)
		.overlay {
			if isImporting {
				NewCertificateView {
					isImporting = false
					store.reload()
				}
				.transition(.opacity)
			}
		}
		.overlay {
			if let cert = selected {
				CertificateDetailSheet(
					certificate: cert,
					isLead: cert.id == leadCertificate?.id,
					mood: mood(for: cert),
					tint: tint(for: cert),
					onDelete: { confirmingDelete = cert },
					dismiss: { selected = nil }
				)
				.transition(.opacity)
			}
		}
		.overlay {
			if showingGuide {
				GuideDetailSheet(guide: GuideContent.certificate) { showingGuide = false }
					.transition(.opacity)
			}
		}
		// And this one sits after them, so it reaches the overlays and carries
		// their fade. Without it the transition has nothing driving it: a panel
		// arrived in a single frame while the blur took a quarter of a second
		// behind it, and the two read as unrelated.
		.animation(.easeInOut(duration: 0.25), value: isPresenting)
		// A dialog rather than one of this app's own floating panels — the
		// system's own affordance for a destructive answer, same as IPA's.
		.confirmationDialog(
			t("certs.deleteConfirm"),
			isPresented: Binding(
				get: { confirmingDelete != nil },
				set: { if !$0 { confirmingDelete = nil } }
			),
			titleVisibility: .visible,
			presenting: confirmingDelete
		) { cert in
			Button(t("common.delete"), role: .destructive) {
				store.delete(cert)
				if selected?.id == cert.id { selected = nil }
			}
		} message: { _ in
			Text(t("certs.deleteConfirmDetail"))
		}
		// The tab bar is the TabView's, so it draws above anything a tab lays
		// over its own content.
		.tabBarVisibility(!isPresenting)
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
		// Announced as "plus" without this, which is the same thing the IPA
		// screen's identical circle says while doing something else.
		.accessibilityLabel(t("home.importCertificate"))
	}

	// MARK: Row

	private func row(for item: StoredCertificate) -> some View {
		Button {
			Haptics.tap()
			selected = item
		} label: {
			HStack(spacing: 12) {
				FaceGlyph(mood: mood(for: item), tint: tint(for: item), size: 44)

				VStack(alignment: .leading, spacing: 3) {
					HStack(spacing: 6) {
						Text(item.name)
							.font(.system(size: 15, weight: .semibold))
							.foregroundStyle(Color.inkPrimary)
							.lineLimit(1)
						// The certificate Home actually signs with — see
						// `leadCertificate`. Nothing else on this row says
						// so, and the badge alone doesn't explain why; the
						// detail sheet this opens does.
						if item.id == leadCertificate?.id {
							Badge(text: t("certs.lead"), tone: .brand)
						}
					}
					Text(item.issuer ?? t("certs.unknownTeam"))
						.font(.system(size: 12))
						.foregroundStyle(Color.inkSecondary)
						.lineLimit(1)
					stateLabel(for: item)
				}

				Spacer(minLength: 8)

				expiryBlock(for: item)
			}
			.statusCard(padding: 11, aura: CertificateAura(item))
		}
		.buttonStyle(.plain)
		.accessibilityHint(t("certs.details"))
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
			expiry(caption: t("certs.expiresIn"), value: dayCount(days), tint: .ok)
		case .expiring(let days):
			expiry(caption: t("certs.expiresIn"), value: dayCount(days), tint: .warn)
		case .expired(let days):
			expiry(
				caption: t("certs.expiredCaption"),
				value: String(format: t("certs.ago"), dayCount(days)),
				tint: .bad
			)
		case .rejected:
			expiry(caption: t("certs.engineCaption"), value: t("home.rejected"), tint: .bad)
		}
	}

	/// "1 day" / "292 days", in the display language.
	private func dayCount(_ days: Int) -> String {
		"\(days) " + (days == 1 ? t("home.day") : t("home.days"))
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
		VStack(spacing: 14) {
			VStack(spacing: 10) {
				GlyphTile(systemName: "shield", size: 54)
				Text(t("certs.empty"))
					.font(.system(size: 17, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
				Text(t("certs.emptyDetail"))
					.font(.system(size: 13))
					.foregroundStyle(Color.inkSecondary)
					.multilineTextAlignment(.center)
			}

			// Nobody can use a single thing in the app from here, so the
			// route matters more than the fact that the list is empty —
			// three sentences, in the order they actually happen.
			VStack(alignment: .leading, spacing: 10) {
				emptyStep(1, t("certs.emptyStep1"))
				emptyStep(2, t("certs.emptyStep2"))
				emptyStep(3, t("certs.emptyStep3"))
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(14)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

			HStack(alignment: .top, spacing: 10) {
				Image(systemName: "gift")
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(Color.brand)
				Text(t("certs.emptyFree"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			Button { isImporting = true } label: {
				Text(t("home.importCertificate"))
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(.white)
					.padding(.horizontal, 22)
					.padding(.vertical, 10)
					.background(Capsule().fill(LinearGradient.brand))
			}
			.padding(.top, 2)

			Button { showingGuide = true } label: {
				Text(t("certs.emptyGuide"))
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(Color.brand)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 28)
		.padding(.horizontal, 20)
		.card()
	}

	private func emptyStep(_ number: Int, _ text: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Text("\(number)")
				.font(.system(size: 11, weight: .bold))
				.foregroundStyle(.white)
				.frame(width: 20, height: 20)
				.background(Circle().fill(LinearGradient.actionFlow))

			Text(text)
				.font(.system(size: 13))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)

			Spacer(minLength: 0)
		}
	}
}
