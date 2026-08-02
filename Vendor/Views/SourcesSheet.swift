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

	@State private var store = SourceStore.shared
	@State private var address = ""
	@State private var checking = false
	@State private var failure: String?
	@FocusState private var addressFocused: Bool

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
	}

	private var panel: some View {
		ZStack(alignment: .topTrailing) {
			ScrollView {
				VStack(alignment: .leading, spacing: 14) {
					header
					field
					if let failure { failureNote(failure) }
					list
				}
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 26)
			}
			.scrollBounceBehavior(.basedOnSize)
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
		.background {
			ZStack {
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(.ultraThinMaterial)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.brand.opacity(0.13), Color.mint.opacity(0.07)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [.white.opacity(0.28), .white.opacity(0.05), Color.mint.opacity(0.18)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
		.shadow(color: .black.opacity(0.45), radius: 30, y: 16)
		.shadow(color: Color.brand.opacity(0.20), radius: 36, y: 20)
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
		VStack(spacing: 10) {
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

		Task {
			defer { checking = false }
			do {
				// The address is read before it is kept, so a typo is refused
				// here rather than becoming a permanent broken row in the list.
				try await store.add(text)
				address = ""
				Haptics.success()
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
			Text(message)
				.font(.system(size: 12))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.padding(10)
		.background(Color.warnSoft)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}

	// MARK: List

	@ViewBuilder
	private var list: some View {
		SectionLabel(text: t("sources.added"))

		if store.sources.isEmpty {
			Text(t("sources.none"))
				.font(.system(size: 12))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)
		} else {
			ForEach(store.sources) { source in
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
					}

					Spacer(minLength: 0)

					Button {
						Haptics.tap()
						store.remove(source)
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
			}
		}
	}
}
