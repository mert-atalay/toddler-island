// Parent steers with keyboard + mouse or the controller's sticks; the child's hello button is
// space, any other non-movement key, or any face button. A second controller is all hello buttons.
import * as THREE from 'three';

const MOVE_KEYS = new Set(['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ShiftLeft', 'ShiftRight']);
const IGNORE_KEYS = new Set(['Escape', 'Tab', 'MetaLeft', 'MetaRight', 'AltLeft', 'AltRight', 'ControlLeft', 'ControlRight', 'ContextMenu', 'CapsLock', 'NumLock', 'ScrollLock', 'PrintScreen']);

export class Input {
  keys = new Set<string>();
  move = new THREE.Vector2(); // x = strafe right, y = forward
  look = new THREE.Vector2(); // radians this frame from mouse
  stickLook = new THREE.Vector2(); // -1..1 from right stick
  private hellos = 0;
  private padPrev: boolean[][] = [];
  dragging = false;

  constructor(private el: HTMLElement) {
    addEventListener('keydown', (e) => {
      if (e.code.startsWith('F') && /^F\d+$/.test(e.code)) return; // let F11 fullscreen through
      if (IGNORE_KEYS.has(e.code)) return;
      e.preventDefault();
      if (MOVE_KEYS.has(e.code)) { this.keys.add(e.code); return; }
      if (!e.repeat) this.hellos++;
    });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    addEventListener('blur', () => this.keys.clear());
    el.addEventListener('mousedown', () => { this.dragging = true; });
    addEventListener('mouseup', () => { this.dragging = false; });
    addEventListener('mousemove', (e) => {
      if (document.pointerLockElement === el || this.dragging) {
        const k = document.pointerLockElement === el ? 0.0022 : 0.004;
        this.look.x += e.movementX * k;
        this.look.y += e.movementY * k;
      }
    });
    addEventListener('contextmenu', (e) => e.preventDefault());
  }

  /** Call once per frame. Returns how many hello presses happened since the last call. */
  poll() {
    let h = this.hellos;
    this.hellos = 0;
    const k = this.keys;
    this.move.set(
      (k.has('KeyD') ? 1 : 0) - (k.has('KeyA') ? 1 : 0),
      (k.has('KeyW') || k.has('ArrowUp') ? 1 : 0) - (k.has('KeyS') || k.has('ArrowDown') ? 1 : 0),
    );
    // arrow left/right turn instead of strafe, which is easier one-handed
    this.stickLook.set((k.has('ArrowRight') ? 1 : 0) - (k.has('ArrowLeft') ? 1 : 0), 0);

    const pads = (navigator.getGamepads?.() || []).filter((p): p is Gamepad => !!p && p.connected);
    pads.forEach((p, n) => {
      const prev = (this.padPrev[n] ||= []);
      const pressed = p.buttons.map((b) => b.pressed);
      // first pad: face buttons A B X Y (0-3) are hello; second pad: every button is hello
      const helloButtons = n === 0 ? [0, 1, 2, 3] : pressed.map((_, i) => i);
      for (const i of helloButtons) if (pressed[i] && !prev[i]) h++;
      this.padPrev[n] = pressed;
      if (n === 0) {
        const dz = (v: number) => (Math.abs(v) < 0.18 ? 0 : (v - Math.sign(v) * 0.18) / 0.82);
        const lx = dz(p.axes[0] || 0), ly = dz(p.axes[1] || 0), rx = dz(p.axes[2] || 0), ry = dz(p.axes[3] || 0);
        if (lx || ly) this.move.set(lx, -ly);
        if (rx || ry) this.stickLook.set(rx, ry);
        // d-pad walks too
        if (pressed[12]) this.move.y = 1;
        if (pressed[13]) this.move.y = -1;
        if (pressed[14]) this.stickLook.x = -1;
        if (pressed[15]) this.stickLook.x = 1;
      }
    });
    if (this.move.lengthSq() > 1) this.move.normalize();
    return h;
  }

  takeLook() { const v = this.look.clone(); this.look.set(0, 0); return v; }
}
