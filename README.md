# Acoustic Intensity Scanner — iPhone 15 Pro prototype

This repository contains the iOS prototype and a GitHub Actions workflow that compiles a physical-device IPA on a hosted macOS/Xcode runner.

Included now:
- ARKit plane detection and LiDAR scene reconstruction when available.
- Adjustable 10 / 25 / 50 cm measurement grid.
- Measurement progress stored by grid cell.
- Already measured cells displayed with a semi-transparent Jet-style colour overlay.
- AVAudioSession `.measurement` mode and live microphone capture.
- Engineering broadband level and simple inter-channel correlation/coherence indicator when 2 channels are available.

Important: the acoustic readout is EXPERIMENTAL. It is not yet a standards-compliant sound-intensity meter. True p-p sound intensity requires verified independent microphone channels, known spacing/orientation, amplitude calibration, frequency-dependent phase calibration, cross-spectral processing and validation against a reference intensity probe.
