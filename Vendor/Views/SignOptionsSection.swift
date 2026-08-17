//
//  SignOptionsSection.swift
//  Vendor
//
//  The edits a package can be given before it is signed. Lives inside the
//  expanded package card, above the actions.
//
//  The draft is held here rather than written straight to the store on every
//  keystroke: `IPAStore.setOptions` reloads the shelf, and a reload on each
//  character rebuilds the row underneath the field being typed into.
//

import SwiftUI

struct SignOptionsSection: View {
	let item: ImportedIPA

	@State private var draft: SignOptions
	@State private var advancedOpen = false
	@State private var components: [String] = []
	@State private var pickingPhoto = false
	@FocusState private var focused: Field?
	/// Not read directly — its presence keeps this view subscribed to
	/// `Localizer.shared`, so every `t(...)` call below redraws when the
	/// language flips.
	@ObservedObject private var localizer = Localizer.shared

	private enum Field: Hashable { case name, identifier, version }

	@ObservedObject private var store = IPAStore.shared

	init(item: ImportedIPA) {
		self.item = item
		_draft = State(initialValue: item.options)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			optionsHeader

			// Nothing left to summarize in a badge, so the reassurance is spelled
			// out instead — the whole point of `changeCount` is not making anyone
			// read every field below to find that out.
			if draft.changeCount == 0 {
				Text(t("sign.untouched"))
					.font(.system(size: 10))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			groupHeader(t("sign.groupIdentity"))

			field(t("sign.name"), text: $draft.displayName,
				  placeholder: item.name, field: .name, why: t("sign.nameWhy"))
			field(t("sign.bundleID"), text: $draft.bundleIdentifier,
				  placeholder: item.bundleIdentifier ?? "—", field: .identifier,
				  why: t("sign.bundleIDWhy"), error: identifierError)
			field(t("sign.version"), text: $draft.version,
				  placeholder: item.version ?? "—", field: .version, why: t("sign.versionWhy"))

			iconRow

			groupHeader(t("sign.groupInstall"))

			optionToggle(
				title: t("sign.duplicate"),
				note: t("sign.duplicateWhy"),
				glyph: "square.on.square",
				isOn: $draft.installAsDuplicate
			)
			.onChange(of: draft.installAsDuplicate) { on in
				applyDuplicate(on)
			}

			optionToggle(
				title: t("sign.jit"),
				note: t("sign.jitWhy"),
				glyph: "bolt",
				isOn: $draft.enableJIT
			)
			.onChange(of: draft.enableJIT) { _ in commit() }

			advanced
		}
		.onChange(of: focused) { now in
			// Committing when the field is left rather than on every keystroke.
			if now == nil { commit() }
		}
		.onDisappear { commit() }
	}

	// MARK: Header

	/// The label the card shows before it is opened — `changeCount` is what
	/// lets that row say this without the fields underneath ever being read.
	private var optionsHeader: some View {
		HStack(spacing: 8) {
			SectionLabel(text: t("sign.options"))
			Spacer(minLength: 0)
			if draft.changeCount > 0 {
				Badge(text: changeSummary, tone: .brand)
				Button(action: resetAll) {
					Text(t("sign.resetAll"))
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(Color.bad)
				}
				.buttonStyle(.plain)
			}
		}
	}

	private var changeSummary: String {
		draft.changeCount == 1
			? t("sign.changeOne")
			: String(format: t("sign.changeMany"), "\(draft.changeCount)")
	}

	/// Sub-heading inside the options block, one weight down from
	/// `SectionLabel` so "How it looks" and "How it installs" read as
	/// subdivisions of "Before signing" rather than sections of their own.
	private func groupHeader(_ text: String) -> some View {
		Text(text)
			.font(.system(size: 11, weight: .semibold))
			.foregroundStyle(Color.inkSecondary)
			.frame(maxWidth: .infinity, alignment: .leading)
	}

	/// Whether the bundle ID as typed has a shape iOS will accept. Nil once
	/// the field is empty — that means keep the package's own, which is
	/// always fine.
	private var identifierError: String? {
		guard !draft.bundleIdentifier.isEmpty else { return nil }
		return SignOptions.identifierIsAcceptable(draft.bundleIdentifier) ? nil : t("sign.badIdentifier")
	}

	// MARK: Text fields

	private func field(
		_ label: String,
		text: Binding<String>,
		placeholder: String,
		field: Field,
		why: String,
		error: String? = nil
	) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 10) {
				Text(label)
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)
					.frame(width: 78, alignment: .leading)

				// The package's own value is the placeholder, so an untouched field
				// shows what will be signed in without pretending it is an edit.
				TextField(placeholder, text: text)
					.font(.system(size: 12.5))
					.foregroundStyle(Color.inkPrimary)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.submitLabel(.done)
					.focused($focused, equals: field)
					.onSubmit { commit() }

				if !text.wrappedValue.isEmpty {
					Button {
						text.wrappedValue = ""
						commit()
					} label: {
						Image(systemName: "arrow.uturn.backward")
							.font(.system(size: 10, weight: .bold))
							.foregroundStyle(Color.inkSecondary)
					}
					.buttonStyle(.plain)
					.accessibilityLabel(t("sign.revertField"))
				}
			}
			.padding(9)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

			Text(error ?? why)
				.font(.system(size: 10))
				.foregroundStyle(error != nil ? Color.bad : Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.leading, 4)
		}
	}

	// MARK: Icon

	private var iconRow: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 10) {
				Group {
					if let url = store.customIconURL(for: item),
					   let image = UIImage(contentsOfFile: url.path) {
						Image(uiImage: image)
							.resizable()
							.aspectRatio(contentMode: .fill)
					} else {
						ZStack {
							Color.brandSoft
							Image(systemName: "photo")
								.font(.system(size: 13, weight: .light))
								.foregroundStyle(Color.brand)
						}
					}
				}
				.frame(width: 34, height: 34)
				.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

				Text(t("sign.icon"))
					.font(.system(size: 12))
					.foregroundStyle(Color.inkSecondary)

				Spacer(minLength: 0)

				if draft.customIconName != nil {
					Button {
						store.deleteCustomIcon(for: item)
						draft.customIconName = nil
						commit()
					} label: {
						Text(t("sign.iconClear"))
							.font(.system(size: 11, weight: .semibold))
							.foregroundStyle(Color.inkSecondary)
					}
					.buttonStyle(.plain)
				}

				Button {
					pickingPhoto = true
				} label: {
					Text(t("sign.iconChoose"))
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(Color.brand)
						.padding(.horizontal, 11)
						.padding(.vertical, 5)
						.background(Capsule().fill(Color.brandSoft))
				}
			}
			.padding(9)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
			.sheet(isPresented: $pickingPhoto) {
				SystemImagePicker { data in
					guard let data, let name = try? store.saveCustomIcon(data, for: item) else { return }
					draft.customIconName = name
					commit()
				}
			}

			Text(t("sign.iconWhy"))
				.font(.system(size: 10))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.leading, 4)
		}
	}

	// MARK: Toggles

	private func optionToggle(
		title: String,
		note: String,
		glyph: String,
		isOn: Binding<Bool>
	) -> some View {
		HStack(spacing: 10) {
			Image(systemName: glyph)
				.font(.system(size: 13, weight: .light))
				.foregroundStyle(isOn.wrappedValue ? Color.brand : Color.inkSecondary)
				.frame(width: 18)

			VStack(alignment: .leading, spacing: 1) {
				Text(title)
					.font(.system(size: 12.5, weight: .medium))
					.foregroundStyle(Color.inkPrimary)
				Text(note)
					.font(.system(size: 10))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 0)

			Toggle("", isOn: isOn)
				.labelsHidden()
				.tint(Color.brand)
		}
		.padding(9)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
	}

	// MARK: Advanced

	private var advanced: some View {
		DisclosureCard(
			title: t("sign.advanced"),
			badge: draft.removedComponents.isEmpty ? nil : "\(draft.removedComponents.count)",
			isOpen: $advancedOpen
		) {
			VStack(alignment: .leading, spacing: 8) {
				Text(t("sign.components"))
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(Color.inkSecondary)
				Text(t("sign.componentsWhy"))
					.font(.system(size: 10))
					.foregroundStyle(Color.inkSecondary)
					.fixedSize(horizontal: false, vertical: true)

				if components.isEmpty {
					Text(t("sign.noComponents"))
						.font(.system(size: 11))
						.foregroundStyle(Color.inkSecondary)
						.fixedSize(horizontal: false, vertical: true)
				} else {
					ForEach(components, id: \.self) { name in
						componentRow(name)
					}
				}
			}
		}
		.task(id: advancedOpen) {
			// Read on first open rather than when the card expands: walking the
			// archive's directory is cheap but not free, and most packages are
			// signed without this section ever being unfolded.
			guard advancedOpen, components.isEmpty else { return }
			let url = store.packageURL(for: item)
			components = await Task.detached(priority: .userInitiated) {
				IPAInspector.embeddedComponents(of: url)
			}.value
		}
	}

	private func componentRow(_ name: String) -> some View {
		let removed = draft.removedComponents.contains(name)
		// The label names the tap, not the current state: a component already
		// marked for removal reads "Keep" — what tapping it again would do —
		// rather than repeating "Drop" back at someone who already chose that.
		let action = String(format: t(removed ? "sign.componentKeep" : "sign.componentRemove"), name)

		return Button {
			if removed {
				draft.removedComponents.removeAll { $0 == name }
			} else {
				draft.removedComponents.append(name)
			}
			commit()
		} label: {
			HStack(spacing: 9) {
				Image(systemName: removed ? "trash.circle.fill" : "circle")
					.font(.system(size: 15))
					.foregroundStyle(removed ? Color.bad : Color.inkSecondary)

				componentLabel(action, removed: removed)
					.lineLimit(1)
					.truncationMode(.middle)

				Spacer(minLength: 0)
			}
			.padding(8)
			.background(.ultraThinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
		}
		.buttonStyle(.plain)
	}

	/// `Text.strikethrough` is iOS 16+ in the current SDK. Below that, the
	/// colour change alone — already applied above — is what marks a removed
	/// component; the line through it is the iOS 16+ bonus.
	@ViewBuilder
	private func componentLabel(_ text: String, removed: Bool) -> some View {
		let label = Text(text)
			.font(.system(size: 11.5))
			.foregroundStyle(removed ? Color.inkSecondary : Color.inkPrimary)

		if #available(iOS 16, *) {
			label.strikethrough(removed, color: Color.bad.opacity(0.7))
		} else {
			label
		}
	}

	// MARK: Writing back

	/// Fills or clears the identifier field to match the duplicate toggle.
	///
	/// Only ever overwrites a value this generated, so a bundle identifier the
	/// user typed survives the toggle being flipped either way.
	private func applyDuplicate(_ on: Bool) {
		if on {
			let base = draft.identifierOverride ?? item.bundleIdentifier ?? ""
			if !base.isEmpty, !SignOptions.isGeneratedDuplicate(base) {
				draft.bundleIdentifier = SignOptions.duplicateIdentifier(from: base)
			}
		} else if SignOptions.isGeneratedDuplicate(draft.bundleIdentifier) {
			draft.bundleIdentifier = ""
		}
		commit()
	}

	/// Clears every override back to how `SignOptions()` starts out, in one tap
	/// instead of one per field.
	private func resetAll() {
		if draft.customIconName != nil {
			store.deleteCustomIcon(for: item)
		}
		draft = SignOptions()
		commit()
	}

	private func commit() {
		guard draft != item.options else { return }
		store.setOptions(draft, for: item)
	}
}
