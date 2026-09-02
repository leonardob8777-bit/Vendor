//
//  SourcesSheet.swift
//  Vendor
//
//  Add and remove repositories. Follows the floating-window pattern the rest of
//  the app uses: no veil, blur handled by the caller through `Screen`, tab bar
//  hidden while it is open, and the bottom safe area ignored so hiding that bar
//  cannot move the panel.
//

import SwiftUI

struct SourcesSheet: View {
	/// Called on close. The caller reloads then, rather than after each edit.
	var dismiss: () -> Void

	@ObservedObject private var store = SourceStore.shared
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared
	@State private var address = ""
	@State private var checking = false
	@State private var failure: String?
	@State private var successMessage: String?
	@FocusState private var addressFocused: Bool

	/// How a repository the user added answered the last time it was asked.
	///
	/// Kept here rather than on `CustomSource` itself: it is what this screen
	/// found out by re-reading the feed just now, not a fact about the
	/// repository worth writing to disk, and it should not linger once the
	/// sheet closes.
	private struct SourceStatus {
		var checking = false
		var appCount: Int?
		var lastChecked: Date?
		var failed = false
	}
	@State private var statuses: [URL: SourceStatus] = [:]
	/// Bumped per URL every time `check(_:)` is asked to look at it again.
	/// The per-row auto-check on appear and “Recheck All” can both have a
	/// fetch for the same repository in flight at once — without this, an
	/// older check's answer landing after a newer one's silently rolls the
	/// row back to stale data with no sign a fresher check ever ran.
	@State private var checkGeneration: [URL: Int] = [:]
	@State private var confirmingRemoval: CustomSource?

	var body: some View {
		ZStack {
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture { if !checking { dismiss() } }

			panel
				.padding(.horizontal, 26)
				.padding(.vertical, 100)
		}
		.ignoresSafeArea(edges: .bottom)
		// A dialog rather than one of this app's floating panels, same as the
		// IPA screen's delete confirmation: it is the system's own affordance
		// for a destructive answer, and it supplies its own Cancel.
		.confirmationDialog(
			confirmingRemoval.map { String(format: t("sources.removeConfirm"), $0.displayName) } ?? "",
			isPresented: Binding(
				get: { confirmingRemoval != nil },
				set: { if !$0 { confirmingRemoval = nil } }
			),
			titleVisibility: .visible,
			presenting: confirmingRemoval
		) { source in
			Button(t("sources.remove"), role: .destructive) {
				store.remove(source)
				statuses[source.url] = nil
			}
		} message: { _ in
			Text(t("sources.removeConfirmDetail"))
		}
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 14) {
					header
					field
					if let successMessage { successNote(successMessage) }
					if let failure { failureNote(failure) }
					builtIns
					list
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 26)
			}
			.scrollBounceBehaviorCompat()
			.mask(
				LinearGradient(
					stops: [
						.init(color: .black, location: 0),
						.init(color: .black, location: 0.90),
						.init(color: .black.opacity(0), location: 1),
					],
					startPoint: .top,
					endPoint: .bottom
				)
			)

			Button(action: dismiss) {
				Image(systemName: "xmark")
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
					.glassCircle(size: 34)
			}
			.padding(.top, 14)
			.padding(.trailing, 14)
			.accessibilityLabel(t("common.close"))
		}
		.sheetPanelBackground()
	}

	// MARK: Header

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			GlyphTile(systemName: "tray.full", size: 46)

			Text(t("sources.title"))
				.font(.system(size: 22, weight: .bold))
				.foregroundStyle(Color.inkPrimary)

			Text(t("sources.detail"))
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.trailing, 40) // clears the close button
	}

	// MARK: Adding

	private var field: some View {
		VStack(alignment: .leading, spacing: 10) {
			SectionLabel(text: t("sources.addTitle"))

			HStack(spacing: 8) {
				Image(systemName: "link")
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(Color.inkSecondary)

				TextField(t("sources.placeholder"), text: $address)
					.font(.system(size: 13))
					.foregroundStyle(Color.inkPrimary)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.keyboardType(.URL)
					.submitLabel(.go)
					.focused($addressFocused)
					.onSubmit(submit)
					.disabled(checking)

				if !address.isEmpty {
					Button {
						Haptics.tap()
						address = ""
					} label: {
						Image(systemName: "xmark.circle.fill")
							.font(.system(size: 14))
							.foregroundStyle(Color.inkSecondary)
					}
					.buttonStyle(.plain)
					.accessibilityLabel(t("sources.clearField"))
				}
			}
			.padding(11)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

			Button(action: submit) {
				HStack(spacing: 7) {
					if checking {
						ProgressView().controlSize(.small).tint(.white)
					}
					Text(checking ? t("sources.checking") : t("sources.add"))
						.font(.system(size: 14, weight: .bold))
						.foregroundStyle(.white)
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 11)
				.background(Capsule().fill(LinearGradient.actionFlow))
			}
			.buttonStyle(.plain)
			.disabled(checking || address.trimmingCharacters(in: .whitespaces).isEmpty)
			.opacity(checking || address.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
		}
	}

	private func submit() {
		let text = address
		guard !text.trimmingCharacters(in: .whitespaces).isEmpty, !checking else { return }
		addressFocused = false
		checking = true
		failure = nil
		successMessage = nil

		Task {
			defer { checking = false }
			do {
				// The address is read before it is kept, so a typo is refused
				// here rather than becoming a permanent broken row in the list.
				let added = try await store.add(text)
				address = ""
				Haptics.success()
				withAnimation(.easeInOut(duration: 0.2)) {
					successMessage = String(format: t("sources.addedOK"), added.displayName)
				}
				// Long enough to read, short enough not to still be sitting
				// there the next time this sheet is opened.
				try? await Task.sleep(nanoseconds: 3_000_000_000)
				withAnimation(.easeInOut(duration: 0.2)) { successMessage = nil }
			} catch {
				failure = error.localizedDescription
				Haptics.failure()
			}
		}
	}

	private func failureNote(_ message: String) -> some View {
		HStack(alignment: .top, spacing: 8) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 12, weight: .bold))
				.foregroundStyle(Color.warn)
			VStack(alignment: .leading, spacing: 2) {
				Text(t("sources.failTitle"))
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
				Text(message)
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			Spacer(minLength: 0)
		}
		.padding(10)
		.background(Color.warnSoft)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}

	private func successNote(_ message: String) -> some View {
		HStack(alignment: .top, spacing: 8) {
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 12, weight: .bold))
				.foregroundStyle(Color.ok)
			Text(message)
				.font(.system(size: 12))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.padding(10)
		.background(Color.okSoft)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}

	// MARK: Shipped repositories

	/// Only the ones that need a decision. A repository that is simply on has
	/// nothing to ask about, and a row for it would be noise.
	@ViewBuilder
	private var builtIns: some View {
		let optIn = SourceLoader.defaultSources.filter(\.optIn)

		if !optIn.isEmpty {
			SectionLabel(text: t("sources.builtIn"))

			ForEach(optIn, id: \.url) { entry in
				let on = Binding(
					get: { store.includes(entry.url) },
					set: { store.setIncluded($0, for: entry.url) }
				)

				VStack(alignment: .leading, spacing: 6) {
					HStack(spacing: 10) {
						Image(systemName: "shippingbox.fill")
							.font(.system(size: 13, weight: .light))
							.foregroundStyle(Color.brand)

						VStack(alignment: .leading, spacing: 1) {
							Text(entry.url.host ?? entry.url.absoluteString)
								.font(.system(size: 13, weight: .medium))
								.foregroundStyle(Color.inkPrimary)
								.lineLimit(1)
							Text(store.includes(entry.url) ? t("sources.on") : t("sources.off"))
								.font(.system(size: 10))
								.foregroundStyle(store.includes(entry.url) ? Color.ok : Color.inkSecondary)
						}

						Spacer(minLength: 0)

						Toggle("", isOn: on)
							.labelsHidden()
							.tint(Color.brand)
							.accessibilityLabel(entry.url.host ?? entry.url.absoluteString)
					}

					Text(store.includes(entry.url) ? t("sources.showAllOn") : t("sources.showAllNote"))
						.font(.system(size: 10))
						.foregroundStyle(Color.inkSecondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				.padding(10)
				.background(.ultraThinMaterial)
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
			}
		}
	}

	// MARK: List

	@ViewBuilder
	private var list: some View {
		HStack {
			SectionLabel(text: t("sources.added"))

			if !store.sources.isEmpty {
				Spacer(minLength: 8)
				Button(action: recheckAll) {
					HStack(spacing: 4) {
						Image(systemName: "arrow.clockwise")
							.font(.system(size: 10, weight: .semibold))
						Text(t("sources.recheck"))
							.font(.system(size: 11, weight: .semibold))
					}
					.foregroundStyle(Color.brand)
				}
				.buttonStyle(.plain)
			}
		}

		if store.sources.isEmpty {
			emptyState
		} else {
			ForEach(store.sources) { source in
				sourceRow(source)
			}
		}
	}

	private var emptyState: some View {
		VStack(spacing: 8) {
			GlyphTile(systemName: "tray", size: 40)
			Text(t("sources.emptyTitle"))
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
			Text(t("sources.emptyDetail"))
				.font(.system(size: 12))
				.foregroundStyle(Color.inkSecondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 18)
	}

	private func sourceRow(_ source: CustomSource) -> some View {
		HStack(spacing: 10) {
			Image(systemName: "shippingbox")
				.font(.system(size: 13, weight: .light))
				.foregroundStyle(Color.mint)

			VStack(alignment: .leading, spacing: 1) {
				Text(source.displayName)
					.font(.system(size: 13, weight: .medium))
					.foregroundStyle(Color.inkPrimary)
					.lineLimit(1)
				Text(source.url.absoluteString)
					.font(.system(size: 10))
					.foregroundStyle(Color.inkSecondary)
					.lineLimit(1)
					.truncationMode(.middle)
				Text(statusLine(for: source))
					.font(.system(size: 10))
					.foregroundStyle(Color.inkSecondary)
					.lineLimit(1)
			}

			Spacer(minLength: 0)

			Button {
				Haptics.tap()
				confirmingRemoval = source
			} label: {
				Image(systemName: "trash")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(Color.bad)
					// The glyph alone is a 13x15pt target, well under the
					// 44pt Apple asks for. Enlarged on that ground rather
					// than to fix a bug: a long chase through a button
					// that would not respond to a synthesised click ended
					// with the click being too brief, not the target too
					// small. A finger was never the problem — but 13pt is
					// still too little to aim at.
					.frame(width: 44, height: 44)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.accessibilityLabel(t("sources.remove"))
		}
		.padding(10)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		// Once per row rather than once for the whole list on appear: a
		// source added this session already has a status, and reopening the
		// sheet should not refetch every repository a second time.
		.task(id: source.url) {
			guard statuses[source.url] == nil else { return }
			check(source.url)
		}
	}

	// MARK: Status

	private func check(_ url: URL) {
		statuses[url, default: SourceStatus()].checking = true
		checkGeneration[url, default: 0] += 1
		let generation = checkGeneration[url]
		Task {
			let result: SourceStatus
			do {
				let source = try await SourceLoader.load(from: url)
				result = SourceStatus(
					checking: false, appCount: source.apps.count, lastChecked: Date(), failed: false
				)
			} catch {
				result = SourceStatus(checking: false, appCount: nil, lastChecked: Date(), failed: true)
			}
			// A newer check for this same repository started while this one
			// was still in flight, so this answer is stale by definition.
			guard checkGeneration[url] == generation else { return }
			statuses[url] = result
		}
	}

	private func recheckAll() {
		for source in store.sources { check(source.url) }
	}

	private func statusLine(for source: CustomSource) -> String {
		let status = statuses[source.url]
		if status?.checking == true { return t("sources.checkingNow") }

		guard let status, let lastChecked = status.lastChecked else {
			return String(format: t("sources.addedOnDate"), Self.dateText(source.addedAt))
		}
		if status.failed { return t("sources.didNotRespond") }

		let countText: String
		switch status.appCount ?? 0 {
		case 0:  countText = t("sources.noApps")
		case 1:  countText = t("sources.oneApp")
		default: countText = String(format: t("sources.appsCount"), status.appCount ?? 0)
		}

		// Under a minute reads as "checked just now" rather than "checked 12
		// seconds ago" — the exact second nobody asked for.
		let elapsed = Date().timeIntervalSince(lastChecked)
		let checkedText = elapsed < 60
			? t("sources.checkedNow")
			: String(format: t("sources.checkedAgo"), Self.agoText(lastChecked))
		return "\(countText) · \(checkedText)"
	}

	/// "3 minutes ago" / "hace 3 minutos" — already carries "ago"/"hace" in
	/// the right place for each language, so it drops straight into
	/// `sources.checkedAgo`'s placeholder without this file having to decide
	/// where that word goes.
	private static func agoText(_ date: Date) -> String {
		let formatter = RelativeDateTimeFormatter()
		formatter.locale = Localizer.shared.language.locale
		formatter.dateTimeStyle = .named
		return formatter.localizedString(for: date, relativeTo: Date())
	}

	/// Matches `SourceApp.releasedOn`: the app's own language, not the
	/// device's, so the field order stays right no matter what region the
	/// phone is set to.
	private static func dateText(_ date: Date) -> String {
		let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
			.locale(Localizer.shared.language.locale)
		return date.formatted(style)
	}
}
