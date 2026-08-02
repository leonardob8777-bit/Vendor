//
//  LoopingVideo.swift
//  Vendor
//
//  Plays a bundled clip on an endless loop with no chrome: no controls, no
//  audio, no material over it. Playback stops whenever the view leaves the
//  screen or the app is backgrounded, so an idle loop never drains battery.
//

import SwiftUI
import AVFoundation
import UIKit

struct LoopingVideo: UIViewRepresentable {
	/// Resource name without extension.
	let resource: String
	var ext: String = "mp4"
	/// True once the view is on screen and allowed to play.
	var isActive: Bool = true
	/// When set, a single frozen frame is shown instead of moving video.
	var isStill: Bool = false

	func makeUIView(context: Context) -> PlayerView {
		let view = PlayerView()
		view.load(resource: resource, ext: ext)
		return view
	}

	func updateUIView(_ view: PlayerView, context: Context) {
		view.setPlaying(isActive && !isStill)
	}

	static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
		view.tearDown()
	}

	/// Puts the process in an audio category that leaves everyone else alone.
	///
	/// This is the whole reason opening Vendor used to stop the user's music.
	/// An app starts out in `soloAmbient`, and that category silences other
	/// apps the moment an `AVPlayer` activates the session — it does not matter
	/// that this clip is muted, or that it has no audio track at all. Merely
	/// playing video was enough to cut Spotify off.
	///
	/// `ambient` is the category for sound that is decoration: it mixes rather
	/// than interrupts, and it is not interrupted in turn, which is what stops
	/// the clip freezing when music starts playing over it.
	private static func allowOtherAudio() {
		// Once per process. The category is global, and re-setting it on every
		// appearance would reactivate the session for no reason.
		guard !hasConfiguredSession else { return }
		hasConfiguredSession = true
		do {
			try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
		} catch {
			// Nothing to recover: the clip is silent either way, and the worst
			// case is the behaviour that was already being shipped.
			assertionFailure("Could not take an ambient audio session: \(error)")
		}
	}

	private nonisolated(unsafe) static var hasConfiguredSession = false

	/// A plain UIView backed by AVPlayerLayer — lighter than AVPlayerViewController,
	/// which would drag in playback controls we do not want.
	final class PlayerView: UIView {
		override static var layerClass: AnyClass { AVPlayerLayer.self }

		private var looper: AVPlayerLooper?
		private var queuePlayer: AVQueuePlayer?
		private var observers: [NSObjectProtocol] = []

		private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

		func load(resource: String, ext: String) {
			guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
				assertionFailure("Missing bundled clip \(resource).\(ext)")
				return
			}

			LoopingVideo.allowOtherAudio()

			let item = AVPlayerItem(url: url)
			let player = AVQueuePlayer()
			player.isMuted = true
			// A decorative loop is not a reason to hold the screen awake. Left at
			// its default, sitting on Home would keep the display from dimming
			// for as long as the app was open.
			player.preventsDisplaySleepDuringVideoPlayback = false
			// Never interrupt the user's music.
			player.audiovisualBackgroundPlaybackPolicy = .pauses

			looper = AVPlayerLooper(player: player, templateItem: item)
			queuePlayer = player

			playerLayer.player = player
			// Fills the frame edge to edge; no letterboxing whatever the size.
			playerLayer.videoGravity = .resizeAspectFill

			let center = NotificationCenter.default
			observers.append(
				center.addObserver(
					forName: UIApplication.didEnterBackgroundNotification,
					object: nil, queue: .main
				) { [weak self] _ in self?.queuePlayer?.pause() }
			)
			observers.append(
				center.addObserver(
					forName: UIApplication.willEnterForegroundNotification,
					object: nil, queue: .main
				) { [weak self] _ in
					guard let self, self.shouldPlay else { return }
					self.queuePlayer?.play()
				}
			)
		}

		private var shouldPlay = false

		func setPlaying(_ playing: Bool) {
			shouldPlay = playing
			if playing {
				queuePlayer?.play()
			} else {
				queuePlayer?.pause()
			}
		}

		func tearDown() {
			queuePlayer?.pause()
			observers.forEach(NotificationCenter.default.removeObserver)
			observers.removeAll()
			looper?.disableLooping()
			looper = nil
			playerLayer.player = nil
			queuePlayer = nil
		}
	}
}
