//
//  TaskProgressSheet.swift
//  Vendor
//
//  Shown while an app is fetched, unpacked, signed and installed. The bar and
//  the badge share one gradient that travels green → purple, so the colour
//  itself tracks how far along the pipeline the job is.
//

import SwiftUI

/// One job moving through the pipeline.
final class AppTask: Identifiable, ObservableObject {
	let id = UUID()

	enum Stage: Int, CaseIterable {
		case downloading, extracting, signing, packaging, installing, done

		var title: String {
			switch self {
			case .downloading: return t("task.downloading")
			case .extracting:  return t("task.unpacking")
			case .signing:     return t("task.signing")
			case .packaging:   return t("task.packaging")
			case .installing:  return t("task.installing")
			case .done:        return t("task.done")
			}
		}

		var glyph: String {
			switch self {
			case .downloading: return "arrow.down"
			case .extracting:  return "shippingbox"
			case .signing:     return "signature"
			case .packaging:   return "shippingbox.and.arrow.backward"
			case .installing:  return "iphone"
			case .done:        return "checkmark"
			}
		}
	}

	let appName: String
	/// Icon shown inside the ring.
	let iconURL: URL?
	/// Stages this particular job passes through. Signing an already-imported
	/// package skips the download, and the bar should reach 100% at the end of
	/// the work that actually runs rather than at three quarters.
	let stages: [Stage]
	@Published var stage: Stage
	/// 0…1 within the current stage.
	@Published var fraction: Double = 0
	/// True while the job is parked on something outside the app — iOS's own
	/// install prompt. There is no progress to report during it, and the panel
	/// says so instead of showing a bar that has quietly stopped moving.
	@Published var awaitingSystem = false
	@Published var failure: String?
	/// Headline shown once the job lands.
	/// Overwritten by `finish(title:detail:)`, which is the only route to `.done`
	/// today. Localised anyway: a hardcoded English default in a bilingual app is
	/// a trap waiting for the first caller that reaches the stage another way.
	@Published var completionTitle = t("task.done")
	@Published var completionDetail: String?

	init(
		appName: String,
		iconURL: URL? = nil,
		stages: [Stage] = Stage.allCases
	) {
		self.appName = appName
		self.iconURL = iconURL
		self.stages = stages
		self.stage = stages.first ?? .downloading
	}

	/// Overall progress across this job's stages, which is what the ring shows.
	var overall: Double {
		guard let index = stages.firstIndex(of: stage), stages.count > 1 else { return 0 }
		let steps = Double(stages.count - 1)
		return min((Double(index) + fraction) / steps, 1)
	}

	var isFinished: Bool { stage == .done || failure != nil }

	@MainActor
	func advance(to stage: Stage, fraction: Double) {
		self.stage = stage
		self.fraction = fraction
	}

	@MainActor
	func finish(title: String, detail: String?) {
		completionTitle = title
		completionDetail = detail
		stage = .done
		fraction = 1
	}

	@MainActor
	func fail(_ message: String) {
		failure = message
	}
}

struct TaskProgressSheet: View {
	@ObservedObject var task: AppTask
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared
	/// Offered once the job lands, when the caller has a follow-up to suggest.
	var primaryAction: (title: String, run: () -> Void)?
	/// Called to give up on a job that is still running. Without it the panel
	/// is a dead end whenever the thing it waits on never arrives.
	var cancel: (() -> Void)?
	/// Called when the panel should go away.
	var dismiss: () -> Void

	var body: some View {
		ZStack {
			// No dimming layer, for the reason spelled out in GuideDetailSheet:
			// a veil across the whole screen darkens the strip beside the
			// Dynamic Island too, where it reads as a black sheet rather than as
			// depth. The blurred content and the panel's own material carry the
			// separation.
			Color.clear
				.ignoresSafeArea()

			panel
				.padding(.horizontal, 26)
		}
		// Same reason as `AppDetailSheet`: hiding the tab bar pulls its inset
		// out of the bottom of the safe area partway through the opening. A
		// centred panel measured against it slides down by half that as it
		// settles. Ignoring the bottom edge keeps it still.
		.ignoresSafeArea(edges: .bottom)
	}

	/// Square floating card, same glass treatment as the Home panels.
	private var panel: some View {
		VStack(spacing: 16) {
			InstallRing(
				progress: task.overall,
				iconURL: task.iconURL,
				diameter: 132,
				failed: task.failure != nil
			)

			VStack(spacing: 6) {
				Text(headline)
					.font(.system(size: 18, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
					.multilineTextAlignment(.center)

				Text(subtitle)
					.font(.system(size: 13))
					.foregroundStyle(Color.inkSecondary)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(.horizontal, 8)

			if task.failure == nil && task.stage != .done {
				// A percentage that sits still for as long as the user takes to
				// answer iOS looks like a hang. Nothing is being counted during
				// that wait, so nothing is claimed.
				if task.awaitingSystem {
					ProgressView()
						.progressViewStyle(.circular)
						.tint(Color.inkSecondary)
				} else {
					Text("\(Int(task.overall * 100))%")
						.font(.system(size: 15, weight: .bold))
						.foregroundStyle(Color.inkPrimary)
						.monospacedDigit()
				}
			}

			footer
		}
		.padding(20)
		.frame(maxWidth: .infinity)
		.aspectRatio(1, contentMode: .fit)
		.background {
			ZStack {
				RoundedRectangle(cornerRadius: 30, style: .continuous)
					.fill(.ultraThinMaterial)

				RoundedRectangle(cornerRadius: 30, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.brand.opacity(0.13), Color.mint.opacity(0.07)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)

				RoundedRectangle(cornerRadius: 30, style: .continuous)
					.strokeBorder(
						LinearGradient(
							colors: [.white.opacity(0.30), .white.opacity(0.05), Color.mint.opacity(0.18)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
		.shadow(color: .black.opacity(0.45), radius: 30, y: 16)
		.shadow(color: Color.brand.opacity(0.22), radius: 36, y: 20)
	}

	// MARK: Copy

	private var headline: String {
		if task.failure != nil { return t("task.failed") }
		return task.stage == .done ? task.completionTitle : "\(task.stage.title) \(task.appName)"
	}

	private var subtitle: String {
		if let failure = task.failure { return failure }
		if task.stage == .done {
			// Every route to `.done` supplies a detail today, so this fallback is
			// latent — which is exactly how the sibling above it acquired the
			// same fault and kept it.
			return task.completionDetail ?? String(format: t("task.readyDetail"), task.appName)
		}
		// While iOS owns the screen, saying "keep Vendor open" is no help — the
		// user is looking at a system prompt and needs to know it is theirs to
		// answer.
		if task.awaitingSystem { return t("task.confirmPrompt") }
		return t("task.keepOpen")
	}




	/// Small dots showing which stages are behind, current, and still ahead.

	// MARK: Footer

	@ViewBuilder
	private var footer: some View {
		if task.isFinished {
			VStack(spacing: 12) {
				if task.stage == .done, let action = primaryAction {
					Button {
						action.run()
					} label: {
						Text(action.title)
							.font(.system(size: 15, weight: .semibold))
							.foregroundStyle(.white)
							.frame(maxWidth: .infinity)
							.padding(.vertical, 12)
							.background(Capsule().fill(LinearGradient.actionFlow))
							.shadow(color: Color.brand.opacity(0.4), radius: 12, y: 4)
					}
				}

				Button { dismiss() } label: {
					Text(t("task.doneButton"))
						.font(.system(size: 15, weight: .semibold))
						.foregroundStyle(Color.ok)
				}
			}
		} else if let cancel, task.awaitingSystem {
			// The way out, offered only while the job waits on iOS — the one
			// stretch where Vendor is not doing the work and giving up costs
			// nothing, and exactly where a dismissed prompt used to leave the
			// panel with no way off the screen.
			//
			// Telling the user not to close the app would be the wrong thing to
			// say beside it, and the same plain style as the dismiss button on a
			// finished job is what keeps the card square in both states.
			Button { cancel() } label: {
				Text(t("task.cancelButton"))
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.bad)
			}
		} else {
			Text(t("task.dontClose"))
				.font(.system(size: 12))
				.foregroundStyle(Color.inkSecondary)
		}
	}
}
