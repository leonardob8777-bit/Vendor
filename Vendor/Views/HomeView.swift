//
//  HomeView.swift
//  Vendor
//

import SwiftUI

struct HomeView: View {
	@Binding var tab: RootTabView.Tab

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@State private var probe = EngineProbe()
	@State private var store = CertificateStore.shared
	@State private var isVisible = false
	@State private var browsing: BrowserLink?
	@State private var pickingLanguage = false

	private let telegramURL = URL(string: "https://t.me/LBsignapp")!
	private let websiteURL  = URL(string: "https://leonardob8777-bit.github.io/")!

	/// The identity that will actually be used to sign: the healthy one that
	/// expires soonest, so the user sees the deadline that matters.
	private var leadCertificate: StoredCertificate? {
		store.certificates
			.filter(\.isUsable)
			.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
			.first
	}

	var body: some View {
		Screen(
			t("tab.home"),
			toolbar: AnyView(LanguageButton(isPresented: $pickingLanguage)),
			// Through `Screen` rather than a `.blur` on the whole thing: the
			// aurora ignores the safe area, so blurring the screen as a whole
			// left the strip beside the Dynamic Island outside the blurred layer
			// and the join read as a black line ruled across the top.
			contentBlur: pickingLanguage ? 16 : 0
		) {
			banner
			certificateStatus
			quickActions
			privacyNote
			community
			disclaimer
		}
		.overlay {
			if pickingLanguage {
				LanguagePicker { pickingLanguage = false }
					.transition(.opacity.combined(with: .scale(scale: 0.94)))
			}
		}
		.animation(.spring(response: 0.32, dampingFraction: 0.86), value: pickingLanguage)
		// The tab bar is the TabView's, so it draws above anything a tab lays
		// over its own content — sharp chrome on top of a floating panel.
		.toolbar(pickingLanguage ? .hidden : .visible, for: .tabBar)
		.inAppBrowser($browsing)
		.task {
			probe.run()
			store.reload()
		}
	}

	// MARK: Banner

	/// The clip fills this slot completely: no card, no material, no padding —
	/// the panel's rounded rectangle is simply used as the crop.
	private var banner: some View {
		LoopingVideo(
			resource: "banner",
			isActive: isVisible,
			isStill: reduceMotion
		)
		// Keeps the panel's original footprint; the clip is scaled to fill it
		// and cropped, so it never letterboxes.
		.frame(maxWidth: .infinity)
		.frame(height: 86)
		.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
		// Three stacked shadows read as depth rather than as a dark smear:
		// a tight contact edge, a wide soft cast, and a brand-tinted bounce
		// that ties the panel to the aurora behind it.
		.shadow(color: .black.opacity(0.22), radius: 4,  y: 2)
		.shadow(color: .black.opacity(0.38), radius: 20, y: 14)
		.shadow(color: Color.brand.opacity(0.22), radius: 26, y: 18)
		.padding(.bottom, 6)
		.onAppear { isVisible = true }
		.onDisappear { isVisible = false }
	}

	// MARK: Certificate status — the screen's reason to exist

	@ViewBuilder
	private var certificateStatus: some View {
		if let cert = leadCertificate {
			activeCertificate(cert)
		} else {
			noCertificate
		}
	}

	private func activeCertificate(_ cert: StoredCertificate) -> some View {
		let health = cert.health()
		let days = daysLeft(health)
		let tint = tint(for: health)

		return VStack(alignment: .leading, spacing: 14) {
			HStack {
				SectionLabel(text: t("home.signingIdentity"))
				Spacer()
				Badge(text: statusWord(health), tone: statusTone(health))
			}

			HStack(spacing: 16) {
				CountdownRing(daysLeft: days, tint: tint)
					.frame(width: 76, height: 76)

				VStack(alignment: .leading, spacing: 4) {
					Text(cert.name)
						.font(.system(size: 17, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
						.lineLimit(1)

					if let issuer = cert.issuer {
						Text(issuer)
							.font(.system(size: 12))
							.foregroundStyle(Color.inkSecondary)
							.lineLimit(1)
					}

					if let expiry = cert.expiresAt {
						let date = expiry.formatted(date: .abbreviated, time: .omitted)
						// Past-tense wording once the date has gone by.
						Text(String(format: expiry > Date() ? t("home.validUntil") : t("home.expiredOn"), date))
							.font(.system(size: 12, weight: .medium))
							.foregroundStyle(tint)
					}
				}

				Spacer(minLength: 0)
			}

			if case .expiring = health {
				inlineWarning(t("home.resignWarning"))
			}
			if case .rejected(let reason) = health {
				inlineWarning(reason)
			}
		}
		.statusCard(glow: tint)
	}

	/// Read-only too: importing lives in the Certificates tab, this panel only
	/// reports what is there.
	private var noCertificate: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				SectionLabel(text: t("home.signingIdentity"))
				Spacer()
				Badge(text: t("certs.none"), tone: .neutral)
			}

			HStack(spacing: 14) {
				GlyphTile(systemName: "shield", tint: .inkSecondary, size: 46)
				VStack(alignment: .leading, spacing: 3) {
					Text(t("home.noCertificate"))
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
					Text(t("home.nothingToSign"))
						.font(.system(size: 12))
						.foregroundStyle(Color.inkSecondary)
				}
				Spacer(minLength: 0)
			}
		}
		.statusCard(glow: .inkSecondary)
	}

	private func inlineWarning(_ text: String) -> some View {
		HStack(spacing: 8) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 12, weight: .bold))
				.foregroundStyle(Color.warn)
			Text(text)
				.font(.system(size: 12))
				.foregroundStyle(Color.inkPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.padding(10)
		.background(Color.warnSoft)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}

	// MARK: Quick actions

	private var quickActions: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(text: t("home.quickActions"))
			LazyVGrid(
				columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
				spacing: 10
			) {
				action(icon: "doc.zipper", title: t("quick.ipa"),   detail: t("quick.ipaDetail"))   { tab = .ipa }
				action(icon: "shield",     title: t("quick.certs"), detail: t("quick.certsDetail")) { tab = .certificates }
				action(icon: "cube",       title: t("quick.apps"),  detail: t("quick.appsDetail"))  { tab = .apps }
				action(icon: "book",       title: t("quick.guides"), detail: t("quick.guidesDetail")) { tab = .guide }
			}
		}
	}

	private func action(
		icon: String,
		title: String,
		detail: String,
		go: @escaping () -> Void
	) -> some View {
		Button(action: go) {
			VStack(alignment: .leading, spacing: 8) {
				GlyphTile(systemName: icon, size: 34)
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(Color.inkPrimary)
					Text(detail)
						.font(.system(size: 11))
						.foregroundStyle(Color.inkSecondary)
						.lineLimit(1)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.card(padding: 13)
		}
		.buttonStyle(.plain)
	}

	// MARK: Trust

	private var privacyNote: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				Image(systemName: "lock.shield")
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(Color.ok)
				Text(t("home.privateByDesign"))
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.inkPrimary)
				Spacer(minLength: 0)
				// Same recording-light blink as the Live chip on Profile.
				BlinkingDot(color: probe.linked ? .ok : .bad, size: 9)
			}

			Text(String(format: t("home.signingRuns"), probe.linked ? t("home.engineLoaded") : t("home.engineMissing")))
				.font(.system(size: 12))
				.foregroundStyle(Color.inkSecondary)
				.fixedSize(horizontal: false, vertical: true)

			HStack(spacing: 6) {
				trustChip(t("home.noAccount"))
				trustChip(t("home.noAnalytics"))
				trustChip(t("home.noTracking"))
			}
		}
		.card()
	}

	private func trustChip(_ text: String) -> some View {
		Text(text)
			.font(.system(size: 11, weight: .medium))
			.foregroundStyle(Color.inkSecondary)
			.padding(.horizontal, 9)
			.padding(.vertical, 4)
			.background(.ultraThinMaterial)
			.clipShape(Capsule())
	}

	// MARK: Community

	/// Telegram and the website, given their own loud block so they are the
	/// last thing seen on the screen rather than buried in a settings page.
	private var community: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 7) {
				SectionLabel(text: t("home.stayUpdated"))
				SiteBadge(text: t("home.recommended"), kind: .hot)
				Spacer(minLength: 0)
			}

			Button { browsing = BrowserLink(url: telegramURL) } label: {
				HStack(spacing: 12) {
					Image(systemName: "paperplane.fill")
						.font(.system(size: 19, weight: .semibold))
						.foregroundStyle(.white)

					VStack(alignment: .leading, spacing: 1) {
						Text(t("home.telegram"))
							.font(.system(size: 15, weight: .bold))
							.foregroundStyle(.white)
						Text(t("home.telegramDetail"))
							.font(.system(size: 11))
							.foregroundStyle(.white.opacity(0.85))
					}

					Spacer(minLength: 0)

					Image(systemName: "arrow.up.right")
						.font(.system(size: 13, weight: .bold))
						.foregroundStyle(.white.opacity(0.9))
				}
				.padding(14)
				.background(
					RoundedRectangle(cornerRadius: 18, style: .continuous)
						.fill(
							LinearGradient(
								colors: [.telegram, .telegramDeep],
								startPoint: .leading, endPoint: .trailing
							)
						)
				)
				.shadow(color: Color.telegram.opacity(0.5), radius: 14, y: 5)
			}

			Button { browsing = BrowserLink(url: websiteURL) } label: {
				HStack(spacing: 12) {
					Image(systemName: "globe")
						.font(.system(size: 18, weight: .semibold))
						.foregroundStyle(.white)

					VStack(alignment: .leading, spacing: 1) {
						Text(t("home.tagline"))
							.font(.system(size: 15, weight: .bold))
							.foregroundStyle(.white)
						Text(t("home.websiteDetail"))
							.font(.system(size: 11))
							.foregroundStyle(.white.opacity(0.85))
					}

					Spacer(minLength: 0)

					Image(systemName: "arrow.up.right")
						.font(.system(size: 13, weight: .bold))
						.foregroundStyle(.white.opacity(0.9))
				}
				.padding(14)
				.background(
					RoundedRectangle(cornerRadius: 18, style: .continuous)
						.fill(
							LinearGradient(
								colors: [.mint, .brand],
								startPoint: .leading, endPoint: .trailing
							)
						)
				)
				.shadow(color: Color.brand.opacity(0.45), radius: 14, y: 5)
			}
		}
	}

	private var disclaimer: some View {
		Text(t("home.disclaimer"))
			.font(.system(size: 11))
			.foregroundStyle(Color.inkSecondary.opacity(0.8))
			.frame(maxWidth: .infinity)
			.padding(.top, 2)
	}

	// MARK: Helpers

	private func daysLeft(_ health: StoredCertificate.Health) -> Int {
		switch health {
		case .valid(let d), .expiring(let d): return d
		case .expired, .rejected:             return 0
		}
	}

	private func statusWord(_ health: StoredCertificate.Health) -> String {
		switch health {
		case .valid:    return t("home.active")
		case .expiring: return t("home.expiring")
		case .expired:  return t("home.expired")
		case .rejected: return t("home.rejected")
		}
	}

	private func statusTone(_ health: StoredCertificate.Health) -> Badge.Tone {
		switch health {
		case .valid:    return .ok
		case .expiring: return .warn
		default:        return .bad
		}
	}

	private func tint(for health: StoredCertificate.Health) -> Color {
		switch health {
		case .valid:    return .ok
		case .expiring: return .warn
		default:        return .bad
		}
	}
}

/// Ring showing how much of a year-long certificate life is left.
struct CountdownRing: View {
	let daysLeft: Int
	let tint: Color

	/// Certificates are typically issued for a year; clamp so the ring stays sane.
	private var fraction: Double {
		min(max(Double(daysLeft) / 365.0, 0), 1)
	}

	var body: some View {
		ZStack {
			Circle()
				.stroke(Color.inkSecondary.opacity(0.18), lineWidth: 7)

			Circle()
				.trim(from: 0, to: fraction)
				.stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
				.rotationEffect(.degrees(-90))

			VStack(spacing: -2) {
				Text("\(daysLeft)")
					.font(.system(size: 22, weight: .bold))
					.foregroundStyle(Color.inkPrimary)
				Text(daysLeft == 1 ? t("home.day") : t("home.days"))
					.font(.system(size: 10, weight: .medium))
					.foregroundStyle(Color.inkSecondary)
			}
		}
	}
}
