import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

let S: CGFloat = 1024

func rgb(_ hex: UInt32) -> CGColor {
	CGColor(red: CGFloat((hex >> 16) & 0xFF)/255,
			green: CGFloat((hex >> 8) & 0xFF)/255,
			blue: CGFloat(hex & 0xFF)/255, alpha: 1)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func grad(_ colors: [UInt32], _ locs: [CGFloat]) -> CGGradient {
	CGGradient(colorsSpace: space, colors: colors.map { rgb($0) } as CFArray, locations: locs)!
}

let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
				  bytesPerRow: 0, space: space,
				  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// ── Fondo aurora ────────────────────────────────────────────────────────
c.drawLinearGradient(grad([0x08202B, 0x120E2E], [0, 1]),
					 start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
for (color, center, radius) in [
	(UInt32(0x0E7C7B), CGPoint(x: 190, y: 790), CGFloat(520)),
	(UInt32(0x2B4FD8), CGPoint(x: 850, y: 590), CGFloat(520)),
	(UInt32(0x6B2BD9), CGPoint(x: 540, y: 150), CGFloat(460)),
] {
	let g = CGGradient(colorsSpace: space,
					   colors: [rgb(color).copy(alpha: 0.85)!, rgb(color).copy(alpha: 0)!] as CFArray,
					   locations: [0, 1])!
	c.drawRadialGradient(g, startCenter: center, startRadius: 0,
						 endCenter: center, endRadius: radius, options: [])
}

// ── La V ────────────────────────────────────────────────────────────────
// Algo más estrecha y subida para dejar aire a la pluma y a la firma.
let vp = CGMutablePath()
vp.move(to: CGPoint(x: S/2 - 224, y: 856))
vp.addLine(to: CGPoint(x: S/2 - 26, y: 392))
vp.addLine(to: CGPoint(x: S/2 + 172, y: 856))
let v = vp.copy(strokingWithWidth: 156, lineCap: .round, lineJoin: .round, miterLimit: 10)

c.setShadow(offset: CGSize(width: 0, height: -16), blur: 46, color: rgb(0x000000).copy(alpha: 0.5))
c.saveGState()
c.addPath(v); c.clip()
let vb = v.boundingBox
c.drawLinearGradient(grad([0x7DF6FF, 0x53AEFF, 0x9B3BFF], [0, 0.46, 1]),
					 start: CGPoint(x: vb.minX, y: vb.maxY), end: CGPoint(x: vb.minX, y: vb.minY), options: [])
c.restoreGState()
c.setShadow(offset: .zero, blur: 0, color: nil)

// ── Pluma ───────────────────────────────────────────────────────────────
// Más grande y con halo para que sobreviva al tamaño de 60 pt.
func nib(at p: CGPoint, size: CGFloat, angle: CGFloat) {
	c.saveGState()
	c.translateBy(x: p.x, y: p.y)
	c.rotate(by: angle)

	let body = CGMutablePath()
	body.move(to: CGPoint(x: 0, y: -size))
	body.addLine(to: CGPoint(x: -size*0.36, y: -size*0.08))
	body.addLine(to: CGPoint(x: -size*0.36, y: size*0.66))
	body.addLine(to: CGPoint(x: size*0.36, y: size*0.66))
	body.addLine(to: CGPoint(x: size*0.36, y: -size*0.08))
	body.closeSubpath()

	// halo
	c.saveGState()
	c.setShadow(offset: .zero, blur: 34, color: rgb(0x9FE9FF).copy(alpha: 0.55))
	c.addPath(body); c.setFillColor(rgb(0xFFFFFF)); c.fillPath()
	c.restoreGState()

	c.saveGState()
	c.addPath(body); c.clip()
	c.drawLinearGradient(grad([0xFFFFFF, 0xCFC9F8], [0, 1]),
						 start: CGPoint(x: -size*0.36, y: size*0.66),
						 end: CGPoint(x: size*0.36, y: -size), options: [])
	c.restoreGState()

	c.setStrokeColor(rgb(0x241C4A))
	c.setLineWidth(size*0.085)
	c.setLineCap(.round)
	c.move(to: CGPoint(x: 0, y: -size*0.88))
	c.addLine(to: CGPoint(x: 0, y: size*0.06))
	c.strokePath()

	c.setFillColor(rgb(0x241C4A))
	c.fillEllipse(in: CGRect(x: -size*0.125, y: size*0.03, width: size*0.25, height: size*0.25))

	c.setStrokeColor(rgb(0x241C4A))
	c.setLineWidth(size*0.095)
	c.move(to: CGPoint(x: -size*0.36, y: size*0.44))
	c.addLine(to: CGPoint(x: size*0.36, y: size*0.44))
	c.strokePath()

	c.restoreGState()
}
nib(at: CGPoint(x: 792, y: 372), size: 152, angle: -0.40)

// ── Firma ───────────────────────────────────────────────────────────────
// Bajada y desplazada para no cruzarse con la punta de la V.
let sp = CGMutablePath()
let w: CGFloat = 470, x0: CGFloat = 300, y: CGFloat = 196
sp.move(to: CGPoint(x: x0, y: y))
sp.addCurve(to: CGPoint(x: x0 + w*0.30, y: y + 4),
			control1: CGPoint(x: x0 + w*0.09, y: y + 52),
			control2: CGPoint(x: x0 + w*0.19, y: y - 48))
sp.addCurve(to: CGPoint(x: x0 + w*0.64, y: y + 14),
			control1: CGPoint(x: x0 + w*0.42, y: y + 46),
			control2: CGPoint(x: x0 + w*0.52, y: y - 34))
sp.addCurve(to: CGPoint(x: x0 + w, y: y + 2),
			control1: CGPoint(x: x0 + w*0.77, y: y + 44),
			control2: CGPoint(x: x0 + w*0.90, y: y + 20))
c.setStrokeColor(rgb(0xC7B8FF).copy(alpha: 0.95)!)
c.setLineWidth(24)
c.setLineCap(.round)
c.addPath(sp)
c.strokePath()

// ── Escritura ───────────────────────────────────────────────────────────
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let image = c.makeImage()!
let dest = CGImageDestinationCreateWithURL(
	out.appendingPathComponent("vendor-1024.png") as CFURL,
	UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("→ vendor-1024.png")
