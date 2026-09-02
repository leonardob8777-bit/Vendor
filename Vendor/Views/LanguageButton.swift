//
//  LanguageButton.swift
//  Vendor
//
//  The circle beside the Home title, and the panel it opens.
//

import SwiftUI

struct LanguageButton: View {
	@ObservedObject private var localizer = Localizer.shared
	@Binding var isPresented: Bool

	var body: some View {
		Button { isPresented = true } label: {
			Text(localizer.language.shortCode)
				.font(.system(size: 12, weight: .bold))
				.kerning(0.3)
				.foregroundStyle(Color.inkPrimary)
				.glassCircle(size: 34)
		}
		.accessibilityLabel(t("language.title"))
	}
}

/// Floating panel, matching the other overlays rather than a system sheet.
struct LanguagePicker: View {
	@ObservedObject private var localizer = Localizer.shared
	var onClose: () -> Void

	var body: some View {
		ZStack {
			// No dimming layer, for the reason spelled out in GuideDetailSheet:
			// a veil across the whole screen darkens the strip beside the
			// Dynamic Island too, where it reads as a black sheet laid over the
			// display rather than as depth.
			Color.clear
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.onTapGesture(perform: onClose)

			panel
				.padding(.horizontal, 34)
		}
		// Same reason as `AppDetailSheet`: hiding the tab bar pulls its inset
		// out of the bottom of the safe area partway through the opening. A
		// centred panel measured against it slides down by half that as it
		// settles. Ignoring the bottom edge keeps it still.
		.ignoresSafeArea(edges: .bottom)
	}

	private var panel: some View {
		VStack(spacing: 14) {
			VStack(spacing: 5) {
				Text(t("language.title"))
					.font(.system(size: 19, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
				Text(t("language.detail"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.multilineTextAlignment(.center)
			}
			.padding(.top, 4)

			VStack(spacing: 8) {
				ForEach(Language.allCases) { option in
					row(option)
				}
			}

			Button(action: onClose) {
				Text(t("task.doneButton"))
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(.white)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 11)
					.background(Capsule().fill(LinearGradient.actionFlow))
			}
			.padding(.top, 2)
		}
		.padding(18)
		.sheetPanelBackground(radius: 26)
	}

	private func row(_ option: Language) -> some View {
		let selected = localizer.language == option

		return Button {
			withAnimation(.easeInOut(duration: 0.2)) {
				localizer.language = option
			}
		} label: {
			HStack(spacing: 11) {
				Text(option.flag)
					.font(.system(size: 20))

				Text(option.name)
					.font(.system(size: 15, weight: .medium))
					.foregroundStyle(Color.inkPrimary)

				Spacer(minLength: 0)

				Image(systemName: selected ? "largecircle.fill.circle" : "circle")
					.font(.system(size: 17))
					.foregroundStyle(selected ? Color.brand : Color.inkSecondary)
			}
			.padding(.horizontal, 13)
			.padding(.vertical, 11)
			.background {
				if selected {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.brandSoft)
				} else {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(.ultraThinMaterial)
				}
			}
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.strokeBorder(
						selected ? Color.brand.opacity(0.45) : Color.clear,
						lineWidth: 1
					)
			)
		}
		.buttonStyle(.plain)
	}
}
