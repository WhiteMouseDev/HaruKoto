/**
 * AudioWorklet processor: resamples native sample rate → 16 kHz PCM Int16.
 * Runs in the audio rendering thread for low-latency capture.
 */
class PcmProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._buffer = [];
    this._targetRate = 16000;
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || !input[0]) return true;

    const samples = input[0]; // Float32Array, native sample rate
    const nativeRate = sampleRate; // global in AudioWorkletGlobalScope

    // Resample: simple linear interpolation
    const ratio = nativeRate / this._targetRate;
    const outputLength = Math.floor(samples.length / ratio);

    for (let i = 0; i < outputLength; i++) {
      const srcIndex = i * ratio;
      const low = Math.floor(srcIndex);
      const high = Math.min(low + 1, samples.length - 1);
      const frac = srcIndex - low;
      const value = samples[low] + (samples[high] - samples[low]) * frac;

      // Float32 → Int16
      const clamped = Math.max(-1, Math.min(1, value));
      const int16 = clamped < 0 ? clamped * 0x8000 : clamped * 0x7fff;
      this._buffer.push(int16);
    }

    // Send chunks of ~100ms (1600 samples at 16kHz)
    while (this._buffer.length >= 1600) {
      const chunk = new Int16Array(this._buffer.splice(0, 1600));
      this.port.postMessage(chunk.buffer, [chunk.buffer]);
    }

    return true;
  }
}

registerProcessor('pcm-processor', PcmProcessor);
