//
//  GetButton.swift
//  Vendor
//
//  The Get control and the ring it turns into while downloading — the spinner
//  replaces the button in place rather than opening a sheet.
//

import SwiftUI

struct GetButton: View {
	/// Identifier the downloader tracks this app under.
	let id: String
	let downloadURL: URL?
	let fileName: String
	/// Name of a package shipped inside Vendor, when there is one.
	var bundledFile: String? = nil

	@ObservedObject private var downloader = Downloader.shared
	@ObservedObject private var store = IPAStore.shared
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

	private var progress: Double? { downloader.progress[id] }
	private var failure: String? { downloader.failures[id] }

	/// The package this row already put on the shelf, if it did.
	///
	/// Matched on the catalogue entry it was fetched for. The file name used to
	/// be the key, and two apps in the feed ship theirs as `Runner.ipa` — so
	/// downloading one lit up the other's button and sent the user to install
	/// the wrong app. The name is still consulted for packages filed before the
	/// source was recorded.
	private var imported: ImportedIPA? {
		if let match = store.packages.first(where: { $0.sourceID == id }) { return match }
		let bundledName = bundledFile.map { "\($0).ipa" }
		return store.packages.first {
			$0.sourceID == nil && ($0.fileName == fileName || $0.fileName == bundledName)
		}
	}

	var body: some View {
		Group {
			if let progress {
				ring(progress)
			} else if let imported {
				installButton(imported)
			} else {
				button
			}
		}
		.animation(.easeInOut(duration: 0.2), value: progress == nil)
		.animation(.easeInOut(duration: 0.2), value: imported?.id)
		// A download that dies silently looks like a button that does nothing.
		.alert(t("apps.downloadFailed"), isPresented: .constant(failure != nil)) {
			Button(t("task.doneButton")) { downloader.clearFailure(id) }
		} message: {
			Text(failure ?? "")
		}
	}

	private var button: some View {
		Button {
			if let bundledFile {
				downloader.adopt(id: id, bundledResource: bundledFile)
			} else if let downloadURL {
				downloader.fetch(id: id, from: downloadURL, named: fileName)
			}
		} label: {
			Text(t("apps.get"))
				.font(.system(size: 13, weight: .bold))
				.foregroundStyle(.white)
				.padding(.horizontal, 18)
				.padding(.vertical, 7)
				.background(Capsule().fill(LinearGradient.actionGet))
				.shadow(color: Color.mint.opacity(0.40), radius: 6, y: 2)
		}
		.disabled(downloadURL == nil && bundledFile == nil)
		.opacity(downloadURL == nil && bundledFile == nil ? 0.4 : 1)
	}

	/// Shown once the package is on the shelf. It hands off to the IPA tab with
	/// that package open rather than installing on the spot: iOS will not take
	/// an unsigned build, so the honest next step is the one screen where the
	/// certificate is picked and the signing and installing actually happen.
	private func installButton(_ item: ImportedIPA) -> some View {
		Button {
			Haptics.tap()
			Router.shared.reveal(item.id)
		} label: {
			HStack(spacing: 4) {
				Image(systemName: "arrow.down.circle.fill")
					.font(.system(size: 11, weight: .semibold))
				Text(t("ipa.install"))
					.font(.system(size: 13, weight: .bold))
			}
			.foregroundStyle(.white)
			.padding(.horizontal, 13)
			.padding(.vertical, 7)
			.background(InstallBackground())
			.shadow(color: Color.installGlow.opacity(0.50), radius: 8, y: 3)
		}
		.buttonStyle(.plain)
	}

	/// Occupies the same footprint as the button so the row does not reflow.
	private func ring(_ value: Double) -> some View {
		Button { downloader.cancel(id) } label: {
			ZStack {
				Circle()
					.stroke(Color.inkSecondary.opacity(0.22), lineWidth: 3)

				Circle()
					.trim(from: 0, to: max(value, 0.02))
					.stroke(
						LinearGradient.actionGet,
						style: StrokeStyle(lineWidth: 3, lineCap: .round)
					)
					.rotationEffect(.degrees(-90))
					.animation(.easeInOut(duration: 0.2), value: value)

				Image(systemName: "xmark")
					.font(.system(size: 9, weight: .bold))
					.foregroundStyle(Color.inkSecondary)
			}
			.frame(width: 30, height: 30)
			.frame(width: 62, height: 30)
		}
		.accessibilityLabel(t("apps.cancelDownload"))
	}
}
