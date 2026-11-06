// Original RescueLink notification sketches, synthesized locally without samples.
const fs = require('node:fs');
const path = require('node:path');
const sampleRate = 48000;
const output = path.resolve(__dirname, '../output/audio');
fs.mkdirSync(output, { recursive: true });

function render(name, seconds, events, peak) {
  const samples = new Float64Array(Math.round(seconds * sampleRate));
  for (const { start, duration, frequency, gain = 1, bell = false } of events) {
    const first = Math.round(start * sampleRate);
    const count = Math.round(duration * sampleRate);
    for (let j = 0; j < count && first + j < samples.length; j++) {
      const t = j / sampleRate;
      const attack = Math.min(1, t / 0.012);
      const release = Math.min(1, (duration - t) / 0.085);
      const envelope = Math.sin(attack * Math.PI / 2) ** 2
        * Math.sin(release * Math.PI / 2) ** 2
        * Math.exp(-t * (bell ? 4.8 : 1.4));
      const phase = 2 * Math.PI * frequency * t;
      const tone = bell
        ? Math.sin(phase) + 0.18 * Math.sin(phase * 2.003) * Math.exp(-t * 8)
        : Math.sin(phase) + 0.12 * Math.sin(phase * 2) + 0.035 * Math.sin(phase * 3);
      samples[first + j] += tone * gain * envelope;
    }
  }
  const mean = samples.reduce((sum, value) => sum + value, 0) / samples.length;
  let maximum = 0;
  for (let i = 0; i < samples.length; i++) {
    samples[i] -= mean;
    // Fade the boundaries to silence, including any DC correction.
    const edge = Math.min(1, i / 240, (samples.length - 1 - i) / 240);
    samples[i] *= Math.max(0, edge);
    maximum = Math.max(maximum, Math.abs(samples[i]));
  }
  const dataBytes = samples.length * 2;
  const wav = Buffer.alloc(44 + dataBytes);
  wav.write('RIFF', 0);
  wav.writeUInt32LE(36 + dataBytes, 4);
  wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20); // PCM
  wav.writeUInt16LE(1, 22); // mono
  wav.writeUInt32LE(sampleRate, 24);
  wav.writeUInt32LE(sampleRate * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write('data', 36);
  wav.writeUInt32LE(dataBytes, 40);
  let energy = 0;
  for (let i = 0; i < samples.length; i++) {
    const value = samples[i] * peak / maximum;
    if (!Number.isFinite(value) || Math.abs(value) > 1) throw Error('Invalid audio');
    energy += value * value;
    wav.writeInt16LE(Math.round(value * 32767), 44 + i * 2);
  }
  const file = path.join(output, name);
  fs.writeFileSync(file, wav);
  const check = fs.readFileSync(file);
  if (check.toString('ascii', 0, 4) !== 'RIFF'
      || check.readUInt32LE(40) !== check.length - 44) throw Error('Invalid WAV');
  console.log(JSON.stringify({ file, seconds, peak, rms: +Math.sqrt(energy / samples.length).toFixed(3), bytes: wav.length }));
}

render('rescuelink-message-v1.wav', 1.15, [
  { start: 0.05, duration: 0.47, frequency: 783.991, gain: 0.72, bell: true },
  { start: 0.21, duration: 0.71, frequency: 1046.502, gain: 0.87, bell: true },
], 0.56);

const sos = [];
for (const start of [0.10, 1.45, 2.80]) {
  sos.push(
    { start, duration: 0.22, frequency: 659.255, gain: 0.82 },
    { start: start + 0.27, duration: 0.22, frequency: 783.991, gain: 0.90 },
    { start: start + 0.54, duration: 0.38, frequency: 1046.502, gain: 1 },
  );
}
render('rescuelink-sos-v1.wav', 4.15, sos, 0.68);
