/// Frozen. Not a user toggle.
/// AndroidEqualizer / LoudnessEnhancer ride the audio SESSION.
/// A2DP Bluetooth often skips AudioEffect — earbuds get dry sound.
/// This app processes PCM in-process, then the phone sends that to BT.
class SoundPolicy {
  static const engine = 'software';
  static const androidEqualizer = false;
  static const androidLoudnessEnhancer = false;
  static const bluetoothSafe = true;

  static bool get isSoftwareEngine =>
      engine == 'software' && !androidEqualizer && !androidLoudnessEnhancer;
}
