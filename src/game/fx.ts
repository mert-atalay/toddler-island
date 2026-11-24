// Little visual answers: hearts rising from a greeted animal, a butterfly when no animal is near,
// and splash rings when wading at the shore.
import * as THREE from 'three';

function heartTexture() {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d')!;
  g.translate(64, 70); g.scale(1.9, 1.9);
  g.beginPath();
  g.moveTo(0, 18);
  g.bezierCurveTo(-30, -2, -22, -30, 0, -14);
  g.bezierCurveTo(22, -30, 30, -2, 0, 18);
  g.fillStyle = '#ff5c8a'; g.fill();
  g.lineWidth = 3; g.strokeStyle = '#fff'; g.stroke();
  g.beginPath(); g.ellipse(-9, -10, 5, 3, -0.6, 0, Math.PI * 2); g.fillStyle = '#ffffffaa'; g.fill();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

interface Particle { obj: THREE.Object3D; age: number; life: number; update: (p: Particle, dt: number) => void }

export class Fx {
  private items: Particle[] = [];
  private heartMat = new THREE.SpriteMaterial({ map: heartTexture(), depthWrite: false, fog: false });
  private ringGeo = new THREE.RingGeometry(0.85, 1, 32).rotateX(-Math.PI / 2);
  constructor(private scene: THREE.Scene) {}

  hearts(at: THREE.Vector3, count = 6) {
    for (let i = 0; i < count; i++) {
      const s = new THREE.Sprite(this.heartMat.clone());
      const size = 0.35 + Math.random() * 0.25;
      s.scale.setScalar(size);
      s.position.copy(at).add(new THREE.Vector3((Math.random() - 0.5) * 0.8, Math.random() * 0.3, (Math.random() - 0.5) * 0.8));
      const vx = (Math.random() - 0.5) * 0.5, vz = (Math.random() - 0.5) * 0.5, delay = i * 0.08;
      this.add(s, 1.8 + delay, (p, dt) => {
        if (p.age < delay) { s.visible = false; return; }
        s.visible = true;
        const t = (p.age - delay) / (p.life - delay);
        s.position.x += vx * dt + Math.sin(p.age * 6 + i) * 0.004;
        s.position.z += vz * dt;
        s.position.y += (1.4 - t) * dt;
        s.scale.setScalar(size * (t < 0.15 ? t / 0.15 : 1));
        (s.material as THREE.SpriteMaterial).opacity = t > 0.6 ? 1 - (t - 0.6) / 0.4 : 1;
      });
    }
  }

  /** A butterfly that flutters across the view in front of the camera. */
  butterfly(camera: THREE.Camera) {
    const g = new THREE.Group();
    const colors = [0xffb347, 0x9ad0ff, 0xff8fd0, 0xfff07a];
    const mat = new THREE.MeshBasicMaterial({ color: colors[Math.floor(Math.random() * colors.length)], side: THREE.DoubleSide });
    const wingGeo = new THREE.CircleGeometry(0.16, 12).translate(0.15, 0.03, 0);
    const lw = new THREE.Mesh(wingGeo, mat), rw = new THREE.Mesh(wingGeo, mat);
    rw.scale.x = -1;
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.025, 0.14, 4, 8).rotateZ(Math.PI / 2).rotateY(Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0x4a3a2a }));
    g.add(lw, rw, body);
    const fwd = new THREE.Vector3(); camera.getWorldDirection(fwd); fwd.y = 0; fwd.normalize();
    const right = new THREE.Vector3(-fwd.z, 0, fwd.x);
    const side = Math.random() < 0.5 ? -1 : 1;
    const base = camera.position.clone().addScaledVector(fwd, 2.4);
    const from = base.clone().addScaledVector(right, -2.6 * side), to = base.clone().addScaledVector(right, 2.6 * side);
    g.position.copy(from);
    this.add(g, 3.2, (p) => {
      const t = p.age / p.life;
      g.position.lerpVectors(from, to, t);
      g.position.y = camera.position.y + 0.15 + Math.sin(t * Math.PI * 3) * 0.3 + Math.sin(t * Math.PI) * 0.25;
      const flap = Math.sin(p.age * 28) * 1.1;
      lw.rotation.y = flap; rw.rotation.y = -flap;
      g.lookAt(to.x, g.position.y, to.z);
    });
  }

  splash(at: THREE.Vector3) {
    const m = new THREE.Mesh(this.ringGeo, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, depthWrite: false }));
    m.position.set(at.x, 0.03, at.z);
    m.renderOrder = 2;
    this.add(m, 1.2, (p) => {
      const t = p.age / p.life;
      m.scale.setScalar(0.3 + t * 1.6);
      (m.material as THREE.MeshBasicMaterial).opacity = 0.7 * (1 - t);
    });
  }

  private add(obj: THREE.Object3D, life: number, update: Particle['update']) {
    this.scene.add(obj);
    this.items.push({ obj, age: 0, life, update });
  }

  tick(dt: number) {
    for (const p of this.items) { p.age += dt; p.update(p, dt); }
    this.items = this.items.filter((p) => {
      if (p.age < p.life) return true;
      this.scene.remove(p.obj);
      p.obj.traverse((o) => { const m = o as unknown as { material?: THREE.Material }; m.material?.dispose(); });
      return false;
    });
  }
}
