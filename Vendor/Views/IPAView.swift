//
//  IPAView.swift
//  Vendor
//
//  Packages you imported yourself: pick a certificate, queue tweaks to inject,
//  then sign and install.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType {
	static let ipa = UTType(filenameExtension: "ipa") ?? .data
	static let dylib = UTType(filenameExtension: "dylib") ?? .data
	static let deb = UTType(filenameExtension: "deb") ?? .data
}

struct IPAView: View {
	@State private var store = IPAStore.shared
	@State private var certificates = CertificateStore.shared

	private enum Shelf: String, CaseIterable {
		case all
		case signed
		case imported

		var title: String {
			switch self {
			case .all:      return t("ipa.all")
			case .signed:   return t("ipa.signed")
			case .imported: return t("ipa.imported")
			}
		}

		func matches(_ item: ImportedIPA) -> Bool {
			switch self {
			case .all:      return true
			case .signed:   return item.isSigned
			case .imported: return !item.isSigned
			}
		}
	}

	@State private var expanded: UUID?
	@State private var shelf: Shelf = .all
	@State private var running: AppTask?
	/// The job the panel is showing, kept so it can be called off.
	@State private var job: Task<Void, Never>?
	@State private var failure: String?
	@State private var busy = false
	@State private var installer = Installer.shared
	@State private var router = Router.shared
	@State private var showingTrustSetup = false
	/// Archive produced by the last successful run, offered for install.
	@State private var signedFile: URL?
	/// The package that archive belongs to, needed to build the manifest.
	@State private var lastSigned: ImportedIPA?

	var body: some View {
		Screen(
			t("tab.ipa"),
			toolbar: AnyView(addButton),
			contentBlur: running == nil && !showingTrustSetup ? 0 : 16
		) {
			shelfPicker

			if busy {
				HStack(spacing: 10) {
					ProgressView()
					Text(t("ipa.importing"))
						.font(.system(size: 13))
						.foregroundStyle(Color.inkSecondary)
					Spacer(minLength: 0)
				}
				.padding(14)
				.card(padding: 0)
			}

			if visible.isEmpty {
				emptyState
			} else {
				ForEach(visible) { item in
					// Same gesture the certificates use: swipe left to reveal
					// the red panel, keep going to delete. Withdrawn while the
					// card is open — a package being prepared for signing is
					// not one to delete by accident, and the drag would
					// otherwise swallow every scroll through its options.
					SwipeToDelete(isEnabled: expanded != item.id) {
						store.delete(item)
					} content: {
						packageCard(item)
					}
				}
			}

			if let failure {
				calloutRow(failure)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: running == nil && !showingTrustSetup)
		.overlay {
			if let task = running {
				TaskProgressSheet(
					task: task,
					// Offered only when the app registers a way in; a button
					// that silently does nothing is worse than no button.
					primaryAction: lastSigned?.urlScheme == nil
						? nil
						: (title: t("task.openApp"), run: openInstalled),
					cancel: cancelRunningJob
				) { running = nil }
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: running?.id)
		.overlay {
			if showingTrustSetup {
				TrustSetupSheet { showingTrustSetup = false }
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: showingTrustSetup)
		// The tab bar is the TabView's, so it draws above whatever a tab lays
		// over its own content. Hiding it is what stops sharp chrome sitting on
		// top of a panel that is meant to be floating free of the screen.
		.toolbar(running == nil && !showingTrustSetup ? .visible : .hidden, for: .tabBar)
		.onChange(of: router.revealPackage) { _, _ in revealRequestedPackage() }
		.onAppear {
			store.reload()
			certificates.reload()
			revealRequestedPackage()
			#if DEBUG
			// Opens the first card automatically so the expanded state can be
			// screenshotted without a tap.
			if ProcessInfo.processInfo.environment["VENDOR_EXPAND_FIRST"] != nil {
				expanded = store.packages.first?.id
			}
			#endif
		}
	}

	/// Opens the card another tab asked for — the Install button on an Apps row
	/// sends you here. The shelf is reset to All first, since a freshly
	/// downloaded package is unsigned and would be hidden behind Signed.
	private func revealRequestedPackage() {
		guard let id = router.revealPackage else { return }
		router.revealPackage = nil
		store.reload()
		certificates.reload()
		shelf = .all

		// A package that has just been downloaded carries no certificate. If
		// there is a usable one, put it on now: arriving at Install only to be
		// told to pick a certificate — when there is exactly one to pick — is a
		// question the app can answer itself.
		if let package = store.packages.first(where: { $0.id == id }),
		   package.signedWithCertificateID == nil,
		   let usable = certificates.certificates.first(where: { $0.isUsable }) {
			store.setCertificate(usable.id, for: package)
		}

		withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
			expanded = id
		}
	}

	/// Packages on the selected shelf.
	private var visible: [ImportedIPA] {
		// Signed first when showing everything: a package that is ready to
		// install is the one worth reaching.
		store.packages
			.filter(shelf.matches)
			.sorted { lhs, rhs in
				guard shelf == .all, lhs.isSigned != rhs.isSigned else {
					return lhs.importedAt > rhs.importedAt
				}
				return lhs.isSigned
			}
	}

	private var shelfPicker: some View {
		HStack(spacing: 6) {
			ForEach(Shelf.allCases, id: \.self) { option in
				let count = store.packages.filter(option.matches).count
				Button {
					withAnimation(.easeInOut(duration: 0.2)) { shelf = option }
				} label: {
					HStack(spacing: 6) {
						Text(option.title)
							.font(.system(size: 13, weight: .semibold))
						Text("\(count)")
							.font(.system(size: 11, weight: .bold))
							.padding(.horizontal, 6)
							.padding(.vertical, 1)
							.background(Capsule().fill(Color.black.opacity(0.18)))
					}
					.foregroundStyle(shelf == option ? .white : Color.inkSecondary)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 9)
					.background {
						if shelf == option {
							Capsule().fill(LinearGradient.actionFlow)
						} else {
							Capsule().fill(.ultraThinMaterial)
						}
					}
				}
				.buttonStyle(.plain)
			}
		}
	}


	// MARK: Picking

	private func pickPackage() {
		DocumentPicker.present(contentTypes: [.data], allowsMultiple: true) { urls in
			ingest(urls) { url in
				guard url.pathExtension.lowercased() == "ipa" else {
					throw IPAStoreError.wrongType(t("ipa.pickIpaOnly"))
				}
				try await store.importPackage(from: url)
			}
		}
	}

	private func pickTweak(for item: ImportedIPA) {
		DocumentPicker.present(contentTypes: [.data], allowsMultiple: true) { urls in
			ingest(urls) { url in
				let ext = url.pathExtension.lowercased()
				guard ext == "dylib" || ext == "deb" else {
					throw IPAStoreError.wrongType(t("ipa.tweakTypeOnly"))
				}
				try await store.addTweak(url, to: item)
			}
		}
	}

	private func ingest(_ urls: [URL], each: @escaping (URL) async throws -> Void) {
		guard !urls.isEmpty else { return }
		Task {
			busy = true
			defer { busy = false }
			failure = nil
			for url in urls {
				do { try await each(url) } catch { failure = error.localizedDescription }
			}
		}
	}

	// MARK: Actions


	/// Signs and then installs as one job. The user asked for one action and
	/// one bar: the stages continue into each other rather than the progress
	/// resetting the moment the signature lands.
	private func sign(_ item: ImportedIPA) {
		guard let certID = item.signedWithCertificateID,
			  let certificate = certificates.certificates.first(where: { $0.id == certID })
		else {
			failure = String(format: t("ipa.pickCertFirst"), item.name)
			return
		}
		guard certificate.isUsable else {
			failure = String(format: t("ipa.certRejected"), certificate.name)
			return
		}

		failure = nil
		let task = AppTask(
			appName: item.name,
			iconURL: artwork(for: item),
			stages: [.extracting, .signing, .packaging, .installing, .done]
		)
		running = task
		signedFile = nil
		lastSigned = nil

		job = Task {
			let destination = store.signedURL(for: item)
			let signed: ImportedIPA

			do {
				let output = try await SigningPipeline.sign(
					package: store.packageURL(for: item),
					tweaks: store.tweakURLs(for: item),
					certificate: certificate,
					certificateP12: certificates.p12URL(for: certID),
					certificateProfile: certificates.provisionURL(for: certID),
					options: item.options,
					customIcon: store.customIconURL(for: item),
					into: destination,
					progress: { stage, fraction in task.advance(to: stage, fraction: fraction) }
				)
				// The identifier comes back out of the signed bundle rather than
				// from the options: it is what the manifest has to declare, and
				// declaring the original while the archive carries an override
				// installs over the copy this was meant to sit beside.
				store.markSigned(item, with: certID, identifier: output.bundleIdentifier)
				signed = store.packages.first { $0.id == item.id } ?? item
				signedFile = output.archive
				lastSigned = signed
				expanded = nil
			} catch {
				// Only a failed signature leaves a build worth throwing away.
				try? FileManager.default.removeItem(at: destination)
				Haptics.failure()
				task.fail(error.localizedDescription)
				return
			}

			// The install is a separate matter. It can be refused or cancelled
			// without that saying anything about the signature, and deleting a
			// perfectly good signed build over it — as this used to — sent the
			// card back to Sign and made the user pay for the whole pipeline
			// again just because they tapped Cancel.
			do {
				try await handOff(signed, task: task)
			} catch {
				Haptics.failure()
				task.fail(error.localizedDescription)
			}
		}
	}

	/// Installs an already-signed package, reusing the same bar.
	private func installSigned(item: ImportedIPA) {
		failure = nil
		let task = AppTask(
			appName: item.name,
			iconURL: artwork(for: item),
			stages: [.installing, .done]
		)
		running = task
		lastSigned = item
		signedFile = store.signedURL(for: item)

		job = Task {
			do {
				try await handOff(item, task: task)
			} catch {
				Haptics.failure()
				task.fail(error.localizedDescription)
			}
		}
	}

	/// Gives up on the job the panel is showing. Offered only while it waits on
	/// iOS's own prompt, where stopping costs nothing: the signature is already
	/// on disk and the install is the system's to run or refuse.
	private func cancelRunningJob() {
		job?.cancel()
		job = nil
		installer.abort()
		running = nil
	}

	/// Hands the package to iOS and holds the bar until the system has taken
	/// it. There is no completion callback from installd, so the signal is the
	/// user coming back to Vendor once the system prompt is answered.
	private func handOff(_ item: ImportedIPA, task: AppTask) async throws {
		task.advance(to: .installing, fraction: 0.15)
		try await installer.install(store.signedURL(for: item), item: item)

		// Waiting on the system prompt is its own state: the bar has nothing to
		// count while iOS holds the screen, and a ring that simply stopped read
		// as a hang.
		task.awaitingSystem = true
		task.advance(to: .installing, fraction: 0.55)
		defer { task.awaitingSystem = false }

		// Coming back to Vendor is not the same as having said yes: Cancel
		// returns here just as Install does. Only a package that installd
		// actually pulled means the prompt was accepted.
		guard await installer.awaitOutcome() == .accepted else {
			throw InstallerError.cancelled
		}

		Haptics.success()
		task.finish(
			title: t("task.installedOK"),
			detail: String(format: t("task.installedDetail"), item.name)
		)
	}

	private func installLastSigned() {
		guard let lastSigned else { return }
		installSigned(item: lastSigned)
	}

	/// Launches what was just installed, when the app registers a way in.
	private func openInstalled() {
		guard let scheme = lastSigned?.urlScheme,
			  let url = URL(string: "\(scheme)://")
		else { return }
		UIApplication.shared.open(url)
	}

	// MARK: Chrome

	private var addButton: some View {
		Button { pickPackage() } label: {
			Image(systemName: "plus")
				.font(.system(size: 15, weight: .bold))
				.foregroundStyle(.white)
				.frame(width: 34, height: 34)
				.background(Circle().fill(LinearGradient.brand))
		}
	}

	// MARK: Package card

	private func packageCard(_ item: ImportedIPA) -> some View {
		let isOpen = expanded == item.id
		let ready = isReady(item)

		return VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 12) {
				packageIcon(item)

				VStack(alignment: .leading, spacing: 3) {
					Text(item.name)
						.font(.system(size: 15, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
						.lineLimit(1)

					HStack(spacing: 4) {
						if let version = item.version {
							Text(version)
							Text("·")
						}
						Text(item.bundleIdentifier ?? item.displaySize)
							.lineLimit(1)
							.truncationMode(.middle)
					}
					.font(.system(size: 11))
					.foregroundStyle(Color.inkSecondary)

					// State line, so the row says where the package stands
					// without having to be opened.
					HStack(spacing: 4) {
						Image(systemName: ready ? "checkmark.seal.fill" : "square.and.arrow.down")
							.font(.system(size: 10, weight: .semibold))
						Text(ready ? t("ipa.stateSigned") : t("ipa.stateImported"))
							.font(.system(size: 11, weight: .medium))
					}
					.foregroundStyle(ready ? Color.ok : Color.mint)
				}

				Spacer(minLength: 6)

				actionPill(item, ready: ready)
			}
			.contentShape(Rectangle())
			.onTapGesture { toggle(item, isOpen: isOpen) }

			if isOpen {
				Divider().overlay(Color.inkSecondary.opacity(0.2))
				certificatePicker(item)
				SignOptionsSection(item: item)
				tweakSection(item)
				preflight(item)
				actions(item)
			}
		}
		.statusCard(padding: 12, glow: ready ? .ok : .brand)
	}

	private func toggle(_ item: ImportedIPA, isOpen: Bool) {
		withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
			expanded = isOpen ? nil : item.id
		}
	}

	/// Artwork for the install ring and the card.
	///
	/// A chosen icon wins over the one read out of the package: it is what the
	/// app is being signed to look like, so showing the old one through the whole
	/// job says the choice did not take.
	private func artwork(for item: ImportedIPA) -> URL? {
		if let custom = store.customIconURL(for: item) { return custom }
		return item.hasIcon ? store.iconURL(for: item.id) : nil
	}

	private func isReady(_ item: ImportedIPA) -> Bool {
		item.isSigned && FileManager.default.fileExists(atPath: store.signedURL(for: item).path)
	}

	/// The one control that carries the row: Sign until the package is signed,
	/// Install from then on.
	private func actionPill(_ item: ImportedIPA, ready: Bool) -> some View {
		// Signing without a usable certificate cannot succeed, so the button says
		// so by going flat rather than by letting the job start and fail.
		let blocked = !ready && !check(item).canSign

		return Button {
			Haptics.tap()
			ready ? installSigned(item: item) : sign(item)
		} label: {
			HStack(spacing: 5) {
				if ready {
					Image(systemName: "arrow.down.circle.fill")
						.font(.system(size: 12, weight: .semibold))
				}
				Text(ready ? t("ipa.install") : t("ipa.sign"))
					.font(.system(size: 13, weight: .bold))
			}
			.foregroundStyle(.white)
			.padding(.horizontal, ready ? 13 : 18)
			.frame(height: 34)
			.background {
				if ready {
					InstallBackground()
				} else {
					Capsule().fill(LinearGradient.actionFlow)
				}
			}
			.shadow(
				color: (ready ? Color.installGlow : Color.brand).opacity(blocked ? 0 : 0.46),
				radius: 8, y: 3
			)
			.saturation(blocked ? 0 : 1)
			.opacity(blocked ? 0.45 : 1)
		}
		.buttonStyle(.plain)
		.disabled(blocked)
	}

	/// Artwork pulled out of the package at import time, with the generic
	/// package glyph as a fallback.
	@ViewBuilder
	private func packageIcon(_ item: ImportedIPA) -> some View {
		let tint: Color = item.isSigned ? .ok : .brand

		if let url = artwork(for: item), let image = UIImage(contentsOfFile: url.path) {
			Image(uiImage: image)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.frame(width: 46, height: 46)
				.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 11, style: .continuous)
						.strokeBorder(tint.opacity(0.35), lineWidth: 1)
				)
		} else {
			GlyphTile(
				systemName: item.isSigned ? "checkmark.seal" : "doc.zipper",
				tint: tint,
				size: 46
			)
		}
	}

	// MARK: Pre-sign check

	/// The two things worth knowing before the button is pressed. Deliberately
	/// two and not a screenful: a check nobody reads costs the same room as one
	/// they do.
	private struct Preflight {
		var hasCertificate: Bool
		var freeBytes: Int64
		var neededBytes: Int64

		/// Space is a warning rather than a block — the estimate is a rule of
		/// thumb, and refusing to sign over it would be wrong more often than
		/// the failure it prevents.
		var spaceIsTight: Bool { freeBytes > 0 && freeBytes < neededBytes }
		var canSign: Bool { hasCertificate }
	}

	private func check(_ item: ImportedIPA) -> Preflight {
		let usable = item.signedWithCertificateID
			.flatMap { id in certificates.certificates.first { $0.id == id } }
			.map(\.isUsable) ?? false

		// Unpacked bundle plus the archive written back out, alongside the
		// original that is never touched: about three times the package.
		return Preflight(
			hasCertificate: usable,
			freeBytes: store.availableBytes() ?? 0,
			neededBytes: item.sizeBytes * 3
		)
	}

	@ViewBuilder
	private func preflight(_ item: ImportedIPA) -> some View {
		let state = check(item)

		if !state.canSign || state.spaceIsTight {
			VStack(alignment: .leading, spacing: 6) {
				if !state.canSign {
					checkRow(t("preflight.noCert"), glyph: "xmark.circle.fill", tone: .bad)
				}
				if state.spaceIsTight {
					checkRow(
						String(
							format: t("preflight.lowSpace"),
							byteText(state.freeBytes),
							byteText(state.neededBytes)
						),
						glyph: "exclamationmark.triangle.fill",
						tone: .warn
					)
				}
			}
		}
	}

	private func checkRow(_ text: String, glyph: String, tone: Color) -> some View {
		HStack(alignment: .top, spacing: 7) {
			Image(systemName: glyph)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(tone)
			Text(text)
				.font(.system(size: 11))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.padding(8)
		.background(tone.opacity(0.10))
		.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
	}

	private func byteText(_ bytes: Int64) -> String {
		let f = ByteCountFormatter()
		f.countStyle = .file
		f.allowedUnits = [.useMB, .useGB]
		return f.string(fromByteCount: bytes)
	}

	// MARK: Certificate

	private func certificatePicker(_ item: ImportedIPA) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("ipa.certificate"))

			if certificates.certificates.isEmpty {
				Text(t("ipa.noCertificates"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
			} else {
				ForEach(certificates.certificates) { cert in
					Button {
						store.setCertificate(
							item.signedWithCertificateID == cert.id ? nil : cert.id,
							for: item
						)
					} label: {
						HStack(spacing: 10) {
							Image(systemName: item.signedWithCertificateID == cert.id
								  ? "largecircle.fill.circle" : "circle")
								.font(.system(size: 16))
								.foregroundStyle(item.signedWithCertificateID == cert.id
												 ? Color.brand : Color.inkSecondary)

							VStack(alignment: .leading, spacing: 1) {
								Text(cert.name)
									.font(.system(size: 13, weight: .medium))
									.foregroundStyle(Color.inkPrimary)
									.lineLimit(1)
								if let issuer = cert.issuer {
									Text(issuer)
										.font(.system(size: 10))
										.foregroundStyle(Color.inkSecondary)
										.lineLimit(1)
								}
							}
							Spacer(minLength: 0)
							if !cert.isUsable {
								Badge(text: t("home.rejected"), tone: .bad)
							}
						}
						.padding(9)
						.background(.ultraThinMaterial)
						.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
					}
					.buttonStyle(.plain)
					.disabled(!cert.isUsable)
					.opacity(cert.isUsable ? 1 : 0.5)
				}
			}
		}
	}

	// MARK: Tweaks

	private func tweakSection(_ item: ImportedIPA) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				SectionLabel(text: t("ipa.tweaks"))
				Spacer()
				Button { pickTweak(for: item) } label: {
					Text(t("ipa.add"))
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(Color.brand)
						.padding(.horizontal, 12)
						.padding(.vertical, 5)
						.background(Capsule().fill(Color.brandSoft))
				}
			}

			if item.tweakFileNames.isEmpty {
				Text(t("ipa.noTweaks"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			} else {
				ForEach(item.tweakFileNames, id: \.self) { name in
					HStack(spacing: 9) {
						Image(systemName: "puzzlepiece.extension")
							.font(.system(size: 13, weight: .light))
							.foregroundStyle(Color.mint)
						Text(name)
							.font(.system(size: 12))
							.foregroundStyle(Color.inkPrimary)
							.lineLimit(1)
						Spacer(minLength: 0)
						Button { store.removeTweak(named: name, from: item) } label: {
							Image(systemName: "xmark")
								.font(.system(size: 10, weight: .bold))
								.foregroundStyle(Color.inkSecondary)
						}
					}
					.padding(9)
					.background(.ultraThinMaterial)
					.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
				}
			}
		}
	}

	// MARK: Actions

	/// One primary action that follows the package's state: a package that has
	/// not been signed offers Sign, and the moment it has been, the same slot
	/// becomes Install. Everything else is demoted so the next step is never in
	/// doubt.
	private func actions(_ item: ImportedIPA) -> some View {
		let ready = item.isSigned
			&& FileManager.default.fileExists(atPath: store.signedURL(for: item).path)

		return VStack(spacing: 10) {
			HStack(spacing: 10) {
				Button {
					Haptics.tap()
					ready ? installSigned(item: item) : sign(item)
				} label: {
					HStack(spacing: 7) {
						Image(systemName: ready ? "arrow.down.app" : "signature")
							.font(.system(size: 14, weight: .semibold))
						Text(ready ? t("ipa.install") : t("ipa.sign"))
							.font(.system(size: 15, weight: .bold))
					}
					.foregroundStyle(.white)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 13)
					.background {
						if ready {
							InstallBackground()
						} else {
							Capsule().fill(LinearGradient.actionFlow)
						}
					}
					.shadow(
						color: (ready ? Color.installGlow : Color.brand).opacity(0.48),
						radius: 11, y: 4
					)
				}

				Button {
					Haptics.tap()
					store.delete(item)
				} label: {
					Image(systemName: "trash")
						.font(.system(size: 14, weight: .medium))
						.foregroundStyle(Color.bad)
						.frame(width: 44, height: 44)
						.background(Circle().fill(Color.badSoft))
				}
			}

			if ready {
				// Secondary once the package is signed: re-signing is for a
				// changed certificate, exporting for a different device.
				HStack(spacing: 18) {
					Button { sign(item) } label: {
						secondary(t("ipa.signAgain"), glyph: "arrow.triangle.2.circlepath")
					}
					Button { ShareSheet.present(items: [store.signedURL(for: item)]) } label: {
						secondary(t("ipa.export"), glyph: "square.and.arrow.up")
					}
				}
				.padding(.top, 2)
			}
		}
		.animation(.spring(response: 0.3, dampingFraction: 0.85), value: ready)
	}

	private func secondary(_ text: String, glyph: String) -> some View {
		HStack(spacing: 5) {
			Image(systemName: glyph)
				.font(.system(size: 11, weight: .semibold))
			Text(text)
				.font(.system(size: 12, weight: .medium))
		}
		.foregroundStyle(Color.inkSecondary)
	}

	// MARK: Empty & errors

	private var emptyState: some View {
		VStack(spacing: 10) {
			GlyphTile(systemName: "doc.zipper", size: 54)
			Text(shelf == .signed ? t("ipa.nothingSigned") : t("ipa.noPackages"))
				.font(.system(size: 17, weight: .semibold))
				.foregroundStyle(Color.inkPrimary)
			Text(shelf == .signed
				 ? t("ipa.signedEmptyDetail")
				 : t("ipa.emptyDetail"))
				.font(.system(size: 13))
				.foregroundStyle(Color.inkSecondary)
				.multilineTextAlignment(.center)
			Button { pickPackage() } label: {
				Text(t("ipa.import"))
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

	private func calloutRow(_ text: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: "exclamationmark.triangle")
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.warn)
			Text(text)
				.font(.system(size: 12))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.padding(12)
		.background(Color.warnSoft)
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}
