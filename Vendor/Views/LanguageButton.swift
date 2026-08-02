//
//  LanguageButton.swift
//  Vendor
//
//  The circle beside the Home title, and the panel it opens.
//

import SwiftUI

struct LanguageButton: View {
	@State private var localizer = Localizer.shared
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
	@State private var localizer = Localizer.shared
	var onClose: () -> Void

	var body: some View {
		ZStack {
			Color.black.opacity(0.22)
				.ignoresSafeArea()
				.onTapGesture(perform: onClose)

			panel
				.padding(.horizontal, 34)
		}
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
		.background {
			ZStack {
				RoundedRectangle(cornerRadius: 26, style: .continuous)
					.fill(.ultraThinMaterial)
				RoundedRectangle(cornerRadius: 26, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.brand.opacity(0.13), Color.mint.opacity(0.07)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)
				RoundedRectangle(cornerRadius: 26, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [.white.opacity(0.28), .white.opacity(0.05), Color.mint.opacity(0.18)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
		.shadow(color: .black.opacity(0.45), radius: 30, y: 16)
		.shadow(color: Color.brand.opacity(0.20), radius: 36, y: 20)
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
