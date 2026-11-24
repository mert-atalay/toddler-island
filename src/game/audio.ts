// Sound: the parent's processed clips, positional so the parent can ask "where is the cow?",
// with a volume floor for a greeted animal, a limiter on the master, and a chime made in code.
import * as THREE from 'three';

interface GameClip { file: string; kind: 'call' | 'ambient'; title: string }
export type SoundBank = Record<string, { calls: AudioBuffer[]; ambient: AudioBuffer[] }>;

export class Sound {
  listener = new THREE.AudioListener();
  bank: SoundBank = {};
  private last: Record<string, number> = {};
  private bed?: THREE.Audio;

  constructor(camera: THREE.Camera) {
    camera.add(this.listener);
    const ctx = this.listener.context;
    const limiter = ctx.createDynamicsCompressor();
    limiter.threshold.value = -10; limiter.knee.value = 6; limiter.ratio.value = 12;
    limiter.attack.value = 0.003; limiter.release.value = 0.25;
    this.listener.setFilter(limiter);
  }

  async load() {
    const manifest: Record<string, GameClip[]> = await fetch('/sounds/game.json').then((r) => r.json());
    const loader = new THREE.AudioLoader();
    await Promise.all(Object.entries(manifest).map(async ([animal, clips]) => {
      const entry = (this.bank[animal] = { calls: [] as AudioBuffer[], ambient: [] as AudioBuffer[] });
      for (const c of clips) {
        const buf = await loader.loadAsync(c.file);
        (c.kind === 'ambient' ? entry.ambient : entry.calls).push(buf);
      }
    }));
  }

  /** A different call from last time, so repeats don't sound identical. */
  pickCall(animal: string) {
    const calls = this.bank[animal]?.calls || [];
    if (!calls.length) return null;
    let i = Math.floor(Math.random() * calls.length);
    if (calls.length > 1 && i === this.last[animal]) i = (i + 1) % calls.length;
    this.last[animal] = i;
    return calls[i];
  }

  makeVoice(holder: THREE.Object3D) {
    const v = new THREE.PositionalAudio(this.listener);
    v.setDistanceModel('inverse');
    v.setRolloffFactor(1.2);
    holder.add(v);
    return v;
  }

  /** near = a greeting or hello: clear even a few metres away. Far = a call across the island. */
  call(voice: THREE.PositionalAudio, animal: string, near: boolean) {
    const buf = this.pickCall(animal);
    if (!buf) return 0;
    if (voice.isPlaying) voice.stop();
    voice.setBuffer(buf);
    voice.setRefDistance(near ? 9 : 5);
    voice.setVolume(near ? 1.0 : 0.7);
    voice.play();
    return buf.duration;
  }

  /** Birdsong bed, looping quietly under everything. */
  startBed() {
    const bg = this.bank.background;
    if (!bg) return;
    const song = bg.ambient[0];
    if (song) {
      this.bed = new THREE.Audio(this.listener);
      this.bed.setBuffer(song); this.bed.setLoop(true); this.bed.setVolume(0.35); this.bed.play();
    }
  }
  /** The wood pigeon and other background calls, now and then. */
  background() {
    const bg = this.bank.background?.calls;
    if (!bg?.length) return;
    const a = new THREE.Audio(this.listener);
    a.setBuffer(bg[Math.floor(Math.random() * bg.length)]); a.setVolume(0.25); a.play();
  }

  /** A soft bell made of a few sine partials: the answer when no animal is near. */
  chime() {
    const ctx = this.listener.context, t = ctx.currentTime;
    const out = this.listener.getInput();
    const notes = [784, 988, 1175];
    notes.forEach((f, k) => {
      for (const [mult, amp] of [[1, 0.22], [2.01, 0.06], [3.02, 0.025]] as const) {
        const o = ctx.createOscillator(), g = ctx.createGain();
        o.type = 'sine'; o.frequency.value = f * mult;
        const s = t + k * 0.12;
        g.gain.setValueAtTime(0, s);
        g.gain.linearRampToValueAtTime(amp, s + 0.01);
        g.gain.exponentialRampToValueAtTime(0.0001, s + 1.1);
        o.connect(g).connect(out); o.start(s); o.stop(s + 1.2);
      }
    });
  }
}
