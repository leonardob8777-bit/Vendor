//
//  CachedImage.swift
//  Vendor
//
//  Artwork that only travels once.
//
//  `AsyncImage` keeps nothing: it refetches every time the view is rebuilt and
//  remembers nothing between launches. In a scrolling list of source apps that
//  shows as icons arriving late, blanking out on the way back up, and starting
//  over on the next launch. This keeps decoded images in memory and their bytes
//  on disk, so an icon is fetched once and from then on is already there in the
//  frame the row first draws.
//
//  Images are also decoded down to the size they are actually shown at. The
//  feeds hand out 1024² artwork for a 52 pt tile, and holding those full size
//  is what makes a long list feel heavy.
//

import SwiftUI
import ImageIO
import UIKit

final class ImageCache: @unchecked Sendable {
	static let shared = ImageCache()

	/// NSCache is thread-safe on its own, which is what lets a view read from
	/// it during `init` and draw a cached icon with no placeholder frame.
	private let memory = NSCache<NSString, UIImage>()
	private let folder: URL

	/// Icons are shown at 52 pt and, in the install ring, at about 82 pt. 512 px
	/// covers both at 3× with room to spare. Screenshots ask for more.
	static let iconPixels = 512
	static let screenshotPixels = 1024

	/// Keyed by size as well as URL. The same artwork can legitimately be wanted
	/// at two sizes, and one shared entry would hand whichever asked second the
	/// other one's resolution.
	private func key(_ url: URL, _ pixels: Int) -> NSString {
		"\(url.absoluteString)#\(pixels)" as NSString
	}

	private init() {
		folder = FileManager.default.cachesDirectory.appendingPathComponent("Artwork", isDirectory: true)
		try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		memory.countLimit = 200
	}

	/// Already-decoded image, or nil. Cheap enough to call while laying out.
	func inMemory(_ url: URL?, maximumPixels: Int = ImageCache.iconPixels) -> UIImage? {
		guard let url else { return nil }
		return memory.object(forKey: key(url, maximumPixels))
	}

	/// Memory, then disk, then the network.
	func image(for url: URL, maximumPixels: Int = ImageCache.iconPixels) async -> UIImage? {
		if let hit = memory.object(forKey: key(url, maximumPixels)) { return hit }

		let file = cacheFile(for: url, maximumPixels: maximumPixels)
		let limit = maximumPixels

		let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
			// A file:// URL — the icon Vendor pulled out of a package — is read
			// straight through, with no copy into the cache folder.
			if url.isFileURL {
				return Self.decode(url, maximumPixels: limit)
			}
			if FileManager.default.fileExists(atPath: file.path),
			   let cached = Self.decode(file, maximumPixels: limit) {
				return cached
			}
			guard let (data, response) = try? await URLSession.shared.data(from: url) else {
				return nil
			}
			if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
				return nil
			}
			try? data.write(to: file, options: .atomic)
			return Self.decode(file, maximumPixels: limit)
		}.value

		if let image { memory.setObject(image, forKey: key(url, maximumPixels)) }
		return image
	}

	/// Decodes straight to the size needed. ImageIO never builds the full-size
	/// bitmap, so a 1024² PNG costs what a 512² one does.
	private static func decode(_ file: URL, maximumPixels: Int) -> UIImage? {
		guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceShouldCacheImmediately: true,
			kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
		]
		guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
		else { return nil }
		return UIImage(cgImage: thumbnail)
	}

	/// One file per URL, named by a hash so the path stays short and legal.
	private func cacheFile(for url: URL, maximumPixels: Int) -> URL {
		var hash: UInt64 = 5381
		for byte in "\(url.absoluteString)#\(maximumPixels)".utf8 {
			hash = hash &* 33 &+ UInt64(byte)
		}
		return folder.appendingPathComponent(String(hash, radix: 36))
	}

	/// Nothing here ever expires on its own — the folder just grows for as
	/// long as Vendor is installed. Settings' storage row is the only caller,
	/// giving someone who wants the space back a way to ask for it.
	func clear() {
		memory.removeAllObjects()
		let files = (try? FileManager.default.contentsOfDirectory(
			at: folder, includingPropertiesForKeys: nil
		)) ?? []
		for file in files { try? FileManager.default.removeItem(at: file) }
	}
}

/// Drop-in replacement for `AsyncImage` that goes through the cache.
struct CachedImage<Placeholder: View>: View {
	let url: URL?
	/// Longest edge to decode to. Icons keep the default; screenshots ask for
	/// more, since they are shown many times larger.
	var maximumPixels: Int = ImageCache.iconPixels
	/// `.fill` suits a square tile that will be cropped. A screenshot has to
	/// keep its own shape, so it asks for `.fit`.
	var contentMode: ContentMode = .fill
	@ViewBuilder var placeholder: () -> Placeholder

	@State private var image: UIImage?

	init(
		url: URL?,
		maximumPixels: Int = ImageCache.iconPixels,
		contentMode: ContentMode = .fill,
		@ViewBuilder placeholder: @escaping () -> Placeholder
	) {
		self.url = url
		self.maximumPixels = maximumPixels
		self.contentMode = contentMode
		self.placeholder = placeholder
		// Seeded from memory so an icon already fetched draws immediately
		// instead of flashing its placeholder for a frame.
		_image = State(initialValue: ImageCache.shared.inMemory(url, maximumPixels: maximumPixels))
	}

	var body: some View {
		Group {
			if let image {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: contentMode)
			} else {
				placeholder()
			}
		}
		.task(id: url) {
			guard image == nil, let url else { return }
			image = await ImageCache.shared.image(for: url, maximumPixels: maximumPixels)
		}
	}
}
