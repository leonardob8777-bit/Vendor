//
//  make-app-icon.swift
//  Vendor
//
//  Builds the app icon in its light and dark variants from the official
//  artwork (the white bird over a mint→lavender wash).
//
//  Rather than recolouring the JPEG — which would drag its compression noise
//  along and cannot fill the corners the rounded crop cut off — the icon is
//  rebuilt from scratch:
//
//    1. the bird is lifted out of the artwork as an alpha mask (it is the only
//       pure-white thing in it),
//    2. the background is re-drawn as a mint field with a lavender bloom in the
//       bottom-left corner, which is what the original gradient actually is,
//    3. the long shadow is extruded from the mask at 45°, the way the original
//       was drawn.
//
//  Both variants then come off the same geometry, so the icon keeps its shape
//  when the phone switches appearance and only the palette moves.
//
//  Usage: swift Tools/make-app-icon.swift <artwork.jpg> <output-folder>
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

let side = 1024
let sideF = CGFloat(side)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

guard CommandLine.arguments.count >= 3 else {
	print("usage: make-app-icon.swift <artwork.jpg> <output-folder>")
	exit(1)
}
let artworkURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])

// MARK: - Palette

struct Palette {
	let mintTop: UInt32
	let mintBottom: UInt32
	let bloom: UInt32
	/// How dark the long shadow sits over the background.
	let shadowAlpha: CGFloat
	let bird: UInt32
}

/// Sampled straight off the official artwork.
let light = Palette(
	mintTop:    0x99F0CE,
	mintBottom: 0x93E4C4,
	bloom:      0xC3A2F8,
	shadowAlpha: 0.13,
	bird:       0xFFFFFF
)

/// The same icon after dark: every hue kept, luminance dropped so it sits on a
/// dark home screen without glowing, and the shadow deepened because a 13%
/// black is invisible over a dark field.
let dark = Palette(
	mintTop:    0x0F5340,
	mintBottom: 0x0A3B31,
	bloom:      0x412C7E,
	shadowAlpha: 0.30,
	bird:       0xF4FFFB
)

func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
	CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
			green: CGFloat((hex >> 8) & 0xFF) / 255,
			blue: CGFloat(hex & 0xFF) / 255,
			alpha: alpha)
}

// MARK: - Lifting the bird out of the artwork

/// Returns the bird as a mask: `colour` everywhere the artwork is white,
/// transparent everywhere else.
///
/// The bird is the only pure white in the piece — the mint tops out at a
/// minimum channel of 0xA6, so a threshold at 200 separates them with room to
/// spare, and the ramp to 240 keeps the feathered edges smooth.
func birdMask(from url: URL, colour: UInt32) -> CGImage {
	guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
		  let artwork = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
		print("cannot read \(url.path)"); exit(1)
	}
	let w = artwork.width, h = artwork.height

	let read = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
						 bytesPerRow: w * 4, space: space,
						 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	read.draw(artwork, in: CGRect(x: 0, y: 0, width: w, height: h))
	let pixels = read.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)

	// The screenshot carries black margins around the rounded crop; find where
	// the artwork actually starts so the bird lands centred.
	var minX = w, maxX = 0, minY = h, maxY = 0
	for y in 0..<h {
		for x in 0..<w {
			let i = (y * w + x) * 4
			if pixels[i] > 24 || pixels[i + 1] > 24 || pixels[i + 2] > 24 {
				minX = min(minX, x); maxX = max(maxX, x)
				minY = min(minY, y); maxY = max(maxY, y)
			}
		}
	}
	let cropW = maxX - minX + 1, cropH = maxY - minY + 1

	let out = CGContext(data: nil, width: cropW, height: cropH, bitsPerComponent: 8,
						bytesPerRow: cropW * 4, space: space,
						bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	let dst = out.data!.bindMemory(to: UInt8.self, capacity: cropW * cropH * 4)

	let r = UInt8((colour >> 16) & 0xFF)
	let g = UInt8((colour >> 8) & 0xFF)
	let b = UInt8(colour & 0xFF)

	for y in 0..<cropH {
		for x in 0..<cropW {
			let i = ((y + minY) * w + (x + minX)) * 4
			let lowest = min(pixels[i], min(pixels[i + 1], pixels[i + 2]))
			let ramp = (CGFloat(lowest) - 200) / 40
			let alpha = max(0, min(1, ramp))
			let j = (y * cropW + x) * 4
			// Premultiplied, so the colour is scaled by its own coverage.
			dst[j]     = UInt8(CGFloat(r) * alpha)
			dst[j + 1] = UInt8(CGFloat(g) * alpha)
			dst[j + 2] = UInt8(CGFloat(b) * alpha)
			dst[j + 3] = UInt8(alpha * 255)
		}
	}
	return out.makeImage()!
}

/// The square the artwork is drawn into: scaled to fill 1024², centred, so the
/// bird keeps its proportions even though the crop is not perfectly square.
func fillRect(for image: CGImage) -> CGRect {
	let scale = max(sideF / CGFloat(image.width), sideF / CGFloat(image.height))
	let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
	return CGRect(x: (sideF - w) / 2, y: (sideF - h) / 2, width: w, height: h)
}

// MARK: - The long shadow

/// Extrudes the mask towards the bottom-right, the way a 45° long shadow is
/// built: the union of the silhouette slid along the diagonal until it runs off
/// the canvas. Each copy is opaque, so overlaps stay flat instead of stacking
/// into a gradient.
func longShadow(from mask: CGImage, in rect: CGRect) -> CGImage {
	let layer = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
						  bytesPerRow: side * 4, space: space,
						  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	let reach = sideF * 1.6
	var travelled: CGFloat = 0
	while travelled <= reach {
		// Down and to the right; the context's y axis points up.
		layer.draw(mask, in: rect.offsetBy(dx: travelled, dy: -travelled))
		travelled += 2
	}
	return layer.makeImage()!
}

// MARK: - Drawing one icon

func render(_ palette: Palette, to url: URL) {
	let mask = birdMask(from: artworkURL, colour: palette.bird)
	let shadowMask = birdMask(from: artworkURL, colour: 0x000000)
	let rect = fillRect(for: mask)

	// Opaque: the App Store rejects an icon with an alpha channel, and the
	// dark variant is authored rather than composited over a system backdrop.
	let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
						bytesPerRow: 0, space: space,
						bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

	// 1. The mint field.
	let mint = CGGradient(colorsSpace: space,
						  colors: [rgb(palette.mintTop), rgb(palette.mintBottom)] as CFArray,
						  locations: [0, 1])!
	ctx.drawLinearGradient(mint,
						   start: CGPoint(x: 0, y: sideF),
						   end: CGPoint(x: 0, y: 0),
						   options: [])

	// 2. The lavender bloom anchored in the bottom-left corner. Measuring the
	//    original showed the violet is not a diagonal ramp but a corner glow:
	//    full strength at the corner, gone by roughly one and a quarter sides
	//    out. These stops trace the falloff that was sampled off it.
	let bloom = CGGradient(
		colorsSpace: space,
		colors: [
			rgb(palette.bloom, alpha: 0.92),
			rgb(palette.bloom, alpha: 0.62),
			rgb(palette.bloom, alpha: 0.40),
			rgb(palette.bloom, alpha: 0.19),
			rgb(palette.bloom, alpha: 0.06),
			rgb(palette.bloom, alpha: 0.00),
		] as CFArray,
		locations: [0, 0.28, 0.42, 0.62, 0.82, 1])!
	ctx.drawRadialGradient(bloom,
						   startCenter: CGPoint(x: 0, y: 0), startRadius: 0,
						   endCenter: CGPoint(x: 0, y: 0), endRadius: sideF * 1.25,
						   options: [])

	// 3. The long shadow, laid down as one flat layer.
	ctx.saveGState()
	ctx.setAlpha(palette.shadowAlpha)
	ctx.draw(longShadow(from: shadowMask, in: rect), in: CGRect(x: 0, y: 0, width: sideF, height: sideF))
	ctx.restoreGState()

	// 4. The bird on top.
	ctx.draw(mask, in: rect)

	let image = ctx.makeImage()!
	let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
	CGImageDestinationAddImage(destination, image, nil)
	CGImageDestinationFinalize(destination)
	print("→ \(url.lastPathComponent)")
}

render(light, to: outputDir.appendingPathComponent("icon-light-1024.png"))
render(dark, to: outputDir.appendingPathComponent("icon-dark-1024.png"))
