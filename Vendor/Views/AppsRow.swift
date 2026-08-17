//
//  AppsRow.swift
//  Vendor
//
//  One app out of a repository feed, the surface it sits on, and the
//  placeholder drawn in its shape while the feed is still on its way.
//
//  The three live together on purpose. A skeleton is only worth drawing if it
//  occupies the room the real row is about to take, and the surface is what
//  guarantees that — keeping them in separate files is how the two drift apart
//  and the list jumps the moment it loads.
//

import SwiftUI

struct AppsRow: View {
	let app: SourceApp
	var onOpen: () -> Void

	private var iconShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: 12, style: .continuous)
	}

	var body: some View {
		Button(action: onOpen) {
			HStack(spacing: 12) {
				icon

				VStack(alignment: .leading, spacing: 2) {
					Text(app.name)
						.font(.system(size: 15, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
						.lineLimit(1)

					attribution

					// Version and size used to sit under the Get button, at ten
					// points, in the one column the eye goes to for the action.
					// Read down the left edge instead they line up across every
					// row, which is what makes a column of them scannable.
					if let facts {
						Text(facts)
							.font(.system(size: 10))
							.foregroundStyle(Color.inkSecondary)
							.lineLimit(1)
					}
				}

				Spacer(minLength: 8)

				// Fetching is always green; the colour only shifts towards purple
				// once the package moves further down the pipeline.
				GetButton(
					id: app.bundleIdentifier,
					downloadURL: app.downloadLink,
					fileName: app.suggestedFileName
				)
			}
			.appsRowSurface()
		}
		.buttonStyle(.plain)
	}

	/// Who published it — or, failing that, what it calls itself.
	///
	/// A feed of 8342 entries written by as many uploaders leaves the author
	/// blank often enough that skipping the line would leave the list ragged.
	/// The bundle identifier is the one field the format makes mandatory, so it
	/// is what an entry with no author still has to offer, and for an audience
	/// that sideloads it says a good deal more than a dash would.
	@ViewBuilder
	private var attribution: some View {
		Group {
			if let developer = Self.text(app.developerName) {
				Text(developer)
			} else {
				// Middle, not tail: the end of a reverse-DNS identifier is the
				// part that names the app, and it is the part tail truncation
				// throws away first.
				Text(app.bundleIdentifier).truncationMode(.middle)
			}
		}
		.font(.system(size: 11))
		.foregroundStyle(Color.inkSecondary)
		.lineLimit(1)
	}

	/// Version and size on one line, with no separator left dangling when only
	/// one of them arrived — which, across a feed this size, is most rows.
	private var facts: String? {
		var parts: [String] = []
		if let version = Self.text(app.displayVersion) {
			// Some feeds publish git-describe strings. Cut rather than let a
			// forty-character tag push the size off the row.
			parts.append(version.count > 14 ? String(version.prefix(14)) + "…" : version)
		}
		if let size = app.displaySize {
			parts.append(size)
		}
		return parts.isEmpty ? nil : parts.joined(separator: " · ")
	}

	private var icon: some View {
		CachedImage(url: app.iconLink) {
			ZStack {
				Color.brandSoft
				Image(systemName: "square.dashed")
					.font(.system(size: 18, weight: .medium))
					.foregroundStyle(Color.brand)
			}
		}
		.frame(width: 46, height: 46)
		.clipShape(iconShape)
		// The app's own tint, floored to something legible by `SourceApp.accent`
		// and used nowhere until now. A hairline of it is enough to give a
		// column of otherwise identical tiles somewhere for the eye to catch,
		// and it costs one stroke a row.
		.overlay(iconShape.strokeBorder(app.accent.opacity(0.45), lineWidth: 1))
	}

	/// Trimmed, and nil when whatever is left is empty. A feed field that holds
	/// a single space is not a value, and drawn as one it opens a gap.
	private static func text(_ raw: String?) -> String? {
		guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
			  !trimmed.isEmpty
		else { return nil }
		return trimmed
	}
}

// MARK: - Surface

/// Row background, deliberately lighter than `.card()`.
///
/// `card` stacks a blur material, a gradient wash, a gradient rim and — in
/// light mode — two shadows. That is nothing on a screen holding six cards and
/// it is the entire cost of this one, where a single repository can put
/// hundreds of rows through it on one scroll.
///
/// What it drops is what a row is too small to show. The wash travels 68 points
/// here, over which a gradient and its own average are the same picture; the
/// rim's journey from white through to mint has no room to read as anything but
/// a hairline; and the second shadow exists to draw a contact edge under a large
/// panel, which at this size the first one already does. The glass, the brand
/// tint and the lift all survive — there is just one layer each of them.
private struct AppsRowSurface: ViewModifier {
	@Environment(\.colorScheme) private var scheme

	private var shape: RoundedRectangle {
		RoundedRectangle(cornerRadius: 16, style: .continuous)
	}

	func body(content: Content) -> some View {
		content
			.padding(11)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background {
				ZStack {
					shape.fill(.ultraThinMaterial)
					shape.fill(Color.brand.opacity(scheme == .dark ? 0.09 : 0.05))
					shape.strokeBorder(
						Color.white.opacity(scheme == .dark ? 0.12 : 0.55),
						lineWidth: 1
					)
				}
			}
			.clipShape(shape)
			.shadow(color: .black.opacity(scheme == .dark ? 0.24 : 0.07), radius: 8, y: 3)
	}
}

extension View {
	/// The panel a feed row sits on. Shared with the loading placeholder so the
	/// list occupies exactly the space it is about to fill.
	func appsRowSurface() -> some View { modifier(AppsRowSurface()) }
}

// MARK: - Loading

/// A row that has not arrived yet.
///
/// Drawn in the shape of the real thing rather than as a spinner in the middle
/// of the screen: a spinner says only that something is happening, while five of
/// these say what is coming and put it where it will land, so nothing shifts
/// under the thumb when the feed answers.
struct AppsRowSkeleton: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	/// Position in the run of placeholders. Only used to vary the bar widths —
	/// five identical rows read as a table someone forgot to fill in.
	let index: Int

	@State private var swept = false

	private var shape: RoundedRectangle {
		RoundedRectangle(cornerRadius: 16, style: .continuous)
	}

	/// Fractions of the text column, cycled so no two neighbours match.
	private var widths: (name: CGFloat, meta: CGFloat) {
		let table: [(CGFloat, CGFloat)] = [(112, 74), (86, 96), (132, 62), (98, 84), (120, 70)]
		let pair = table[index % table.count]
		return (pair.0, pair.1)
	}

	var body: some View {
		HStack(spacing: 12) {
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(Color.inkSecondary.opacity(0.20))
				.frame(width: 46, height: 46)

			VStack(alignment: .leading, spacing: 6) {
				bar(width: widths.name, height: 11)
				bar(width: widths.meta, height: 9)
				bar(width: widths.meta * 0.6, height: 8)
			}

			Spacer(minLength: 8)

			Capsule()
				.fill(Color.inkSecondary.opacity(0.20))
				.frame(width: 62, height: 30)
		}
		.appsRowSurface()
		.overlay { if !reduceMotion { sweep } }
		// After the sweep, so the light stops at the panel's edge instead of
		// running out over the aurora.
		.clipShape(shape)
	}

	private func bar(width: CGFloat, height: CGFloat) -> some View {
		Capsule()
			.fill(Color.inkSecondary.opacity(0.20))
			.frame(width: width, height: height)
	}

	/// The same shine that crosses the Install pill, slowed down and dimmed.
	/// It is what separates "still loading" from "loaded, and this is what the
	/// feed had to say" — which is otherwise the same grey rectangle.
	private var sweep: some View {
		GeometryReader { geo in
			LinearGradient(
				colors: [.clear, .white.opacity(0.20), .clear],
				startPoint: .leading,
				endPoint: .trailing
			)
			.frame(width: geo.size.width * 0.42)
			.offset(x: swept ? geo.size.width : -geo.size.width * 0.42)
		}
		.allowsHitTesting(false)
		.onAppear {
			// A frame late, so SwiftUI has a settled value to animate from.
			DispatchQueue.main.async {
				withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
					swept = true
				}
			}
		}
	}
}
