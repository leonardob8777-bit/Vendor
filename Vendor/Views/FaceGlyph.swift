//
//  FaceGlyph.swift
//  Vendor
//
//  Outline happy / sad face. Drawn rather than taken from SF Symbols, which
//  ships a smiling face but no sad counterpart — a mismatched pair would read
//  as two unrelated icons.
//

import SwiftUI

struct FaceGlyph: View {
	enum Mood {
		case happy
		/// Flat mouth — used while a certificate still works but is running out.
		case neutral
		case sad
	}

	let mood: Mood
	var tint: Color
	var size: CGFloat = 44

	/// Stroke stays proportional so the face reads the same at any size.
	private var line: CGFloat { max(size * 0.045, 1.2) }

	var body: some View {
		ZStack {
			Circle()
				.strokeBorder(tint, lineWidth: line)

			// Eyes
			HStack(spacing: size * 0.20) {
				eye
				eye
			}
			.offset(y: -size * 0.09)

			// Mouth: curves up, flat, or curves down.
			MouthArc(mood: mood)
				.stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))
				.frame(width: size * 0.42, height: mood == .neutral ? line : size * 0.20)
				.offset(y: mouthOffset)
		}
		.frame(width: size, height: size)
		.background(tint.opacity(0.10))
		.clipShape(Circle())
	}

	/// A flat mouth sits higher than a curved one, which needs room to bow.
	private var mouthOffset: CGFloat {
		switch mood {
		case .happy:   return size * 0.13
		case .neutral: return size * 0.19
		case .sad:     return size * 0.17
		}
	}

	private var eye: some View {
		Circle()
			.fill(tint)
			.frame(width: size * 0.085, height: size * 0.085)
	}
}

private struct MouthArc: Shape {
	let mood: FaceGlyph.Mood

	func path(in rect: CGRect) -> Path {
		var path = Path()

		guard mood != .neutral else {
			path.move(to: CGPoint(x: rect.minX, y: rect.midY))
			path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
			return path
		}

		let smiling = mood == .happy
		path.move(to: CGPoint(x: rect.minX, y: smiling ? rect.minY : rect.maxY))
		path.addQuadCurve(
			to: CGPoint(x: rect.maxX, y: smiling ? rect.minY : rect.maxY),
			control: CGPoint(
				x: rect.midX,
				y: smiling ? rect.maxY + rect.height * 0.6 : rect.minY - rect.height * 0.6
			)
		)
		return path
	}
}
