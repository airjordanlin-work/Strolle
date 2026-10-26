import AVFoundation
import UIKit

/// Haptics and sound for the gate. Everything is system API or generated
/// in code, so there are no audio files to license (see ASSETS.md).
///
/// Tone: a hit is a small bright chime, a miss is one low, quiet note and a
/// soft tap. No error haptic and no buzzer; a miss still lets the user in.
@MainActor
final class GateFeedback: ObservableObject {
    private let notify = UINotificationFeedbackGenerator()
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private var player: AVAudioPlayer?

    private let correctChime = GateFeedback.wav(notes: [(659.25, 0.12), (880.0, 0.28)], volume: 0.5)
    private let missTone = GateFeedback.wav(notes: [(392.0, 0.30)], volume: 0.25)
    private let levelUpChime = GateFeedback.wav(notes: [(523.25, 0.10), (659.25, 0.10), (783.99, 0.10), (1046.5, 0.35)], volume: 0.5)

    init() {
        // .ambient respects the silent switch and mixes with other audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        notify.prepare()
        soft.prepare()
    }

    func play(_ reward: AnswerReward) {
        if reward.correct {
            if reward.newLevel != nil {
                notify.notificationOccurred(.success)
                sound(levelUpChime)
            } else if [3, 5, 8, 10].contains(reward.combo) {
                medium.impactOccurred()
                sound(correctChime)
            } else {
                notify.notificationOccurred(.success)
                sound(correctChime)
            }
        } else {
            soft.impactOccurred()
            sound(missTone)
        }
    }

    func unlocked() {
        medium.impactOccurred(intensity: 0.8)
    }

    private func sound(_ data: Data) {
        player = try? AVAudioPlayer(data: data)
        player?.play()
    }

    /// Mono 16-bit 44.1 kHz WAV of sine notes with a short attack and an
    /// exponential decay, built in memory.
    private static func wav(notes: [(freq: Double, dur: Double)], volume: Double) -> Data {
        let rate = 44_100.0
        var samples: [Int16] = []
        for (freq, dur) in notes {
            let n = Int(rate * dur)
            for i in 0..<n {
                let t = Double(i) / rate
                let attack = min(1, t / 0.005)
                let decay = exp(-5 * t / dur)
                let v = sin(2 * .pi * freq * t) * attack * decay * volume
                samples.append(Int16(v * Double(Int16.max)))
            }
        }
        var d = Data()
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let dataSize = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); put(36 + dataSize)
        d.append(contentsOf: Array("WAVEfmt ".utf8)); put(UInt32(16))
        put(UInt16(1)); put(UInt16(1)); put(UInt32(rate)); put(UInt32(rate) * 2)
        put(UInt16(2)); put(UInt16(16))
        d.append(contentsOf: Array("data".utf8)); put(dataSize)
        for s in samples { put(s) }
        return d
    }
}
