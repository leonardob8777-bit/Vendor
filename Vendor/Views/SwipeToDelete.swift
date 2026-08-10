//
//  SwipeToDelete.swift
//  Vendor
//
//  Swipe a card to the left to reveal a red destructive panel. Releasing past
//  the commit threshold deletes; a shorter swipe rests open so the button can
//  be tapped instead.
//

import SwiftUI

struct SwipeToDelete<Content: View>: View {
	var cornerRadius: CGFloat = 18
	/// Whether the card can be swiped away at all.
	///
	/// Turned off while a card is open for editing. Two reasons, and the second
	/// is the one that matters: a card being set up for signing is the last one
	/// the user means to throw away, and the drag would otherwise fight every
	/// vertical scroll through the options — the gesture claims the touch, so
	/// trying to scroll the section arms the red panel instead.
	var isEnabled: Bool = true
	var onDelete: () -> Void
	@ViewBuilder var content: () -> Content

	/// How far the card rests open when the swipe is released early.
	private let restWidth: CGFloat = 84
	/// Past this distance, releasing commits the delete.
	private let commitWidth: CGFloat = 190

	@State private var offset: CGFloat = 0
	@State private var armed = false
	@State private var removing = false

	private var travel: CGFloat { -offset }
	private var revealed: Bool { travel > 2 }

	var body: some View {
		ZStack(alignment: .trailing) {
			destructivePanel
			content()
				.offset(x: offset)
				// `.subviews` rather than dropping the modifier: it takes this
				// gesture out of play while leaving the buttons and fields inside
				// the card working.
				.gesture(drag, including: isEnabled ? .all : .subviews)
		}
		.onChange(of: isEnabled) { enabled in
			// A card left resting open and then opened for editing would keep the
			// red panel showing behind it with no way to put it back.
			if !enabled { reset() }
		}
		// Keeps the sliding card inside its own rounded bounds instead of
		// letting it run past the screen margin.
		.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
		.frame(height: removing ? 0 : nil)
		.opacity(removing ? 0 : 1)
		.clipped()
	}

	// MARK: Panel

	private var destructivePanel: some View {
		RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
			.fill(armed ? Color.destructive : Color.destructive.opacity(0.82))
			.overlay(alignment: .trailing) {
				Button {
					commit()
				} label: {
					Image(systemName: "xmark")
						.font(.system(size: armed ? 22 : 18, weight: .bold))
						.foregroundStyle(.white)
						.frame(width: max(restWidth, travel), height: 44)
				}
				.disabled(!revealed)
			}
			.opacity(revealed ? 1 : 0)
			.animation(.spring(response: 0.25, dampingFraction: 0.8), value: armed)
	}

	// MARK: Gesture

	private var drag: some Gesture {
		DragGesture(minimumDistance: 12)
			.onChanged { value in
				// Left only; a little rubber-banding once past the commit point.
				let raw = min(0, value.translation.width)
				offset = raw < -commitWidth
					? -commitWidth - (abs(raw) - commitWidth) * 0.35
					: raw

				let nowArmed = travel >= commitWidth
				if nowArmed != armed {
					armed = nowArmed
					UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
				}
			}
			.onEnded { _ in
				if travel >= commitWidth {
					commit()
				} else if travel >= restWidth / 2 {
					withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
						offset = -restWidth
					}
				} else {
					reset()
				}
			}
	}

	private func commit() {
		UINotificationFeedbackGenerator().notificationOccurred(.success)
		withAnimation(.easeIn(duration: 0.22)) {
			offset = -UIScreen.main.bounds.width
		}
		withAnimation(.easeInOut(duration: 0.25).delay(0.12)) {
			removing = true
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
			onDelete()
		}
	}

	private func reset() {
		withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
			offset = 0
			armed = false
		}
	}
}
