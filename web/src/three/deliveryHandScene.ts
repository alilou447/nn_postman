import * as THREE from "three";

export type DeliveryNoteType =
  | "urgent"
  | "fragile"
  | "dog"
  | "signature"
  | "cluster"
  | "newspaper"
  | "regular";

export type DeliveryItemShape = "envelope" | "box" | "newspaper";

export interface DeliveryMailItem {
  id: string;
  label: string;
  address: string;
  note: string;
  noteType: DeliveryNoteType;
  stopType: string;
  recipient?: string;
  tracking?: string;
  instructions?: string;
}

export const DEFAULT_DELIVERY_MAIL: DeliveryMailItem[] = [
  {
    id: "a",
    label: "A",
    address: "12 Mirror Park Blvd",
    note: "URGENT",
    noteType: "urgent",
    stopType: "mailbox",
    recipient: "M. Santos",
    tracking: "PM-A-48291",
    instructions: "Priority delivery. Deposit in mailbox.",
  },
  {
    id: "b",
    label: "B",
    address: "4 Grove St Apartments",
    note: "FRAGILE",
    noteType: "fragile",
    stopType: "package",
    recipient: "L. Johnson",
    tracking: "PM-B-19384",
    instructions: "Handle with care. Leave at front door.",
  },
  {
    id: "c",
    label: "C",
    address: "88 Vinewood Hills Dr",
    note: "CAREFUL — DOG",
    noteType: "dog",
    stopType: "dog_yard",
    recipient: "R. De Santa",
    tracking: "PM-C-72015",
    instructions: "Watch for dog in yard. Knock before entering gate.",
  },
  {
    id: "d",
    label: "D",
    address: "221 Bay City Ave",
    note: "SIGNATURE",
    noteType: "signature",
    stopType: "registered",
    recipient: "T. Clinton",
    tracking: "PM-D-55802",
    instructions: "Signature required. Deliver to recipient only.",
  },
  {
    id: "e",
    label: "E",
    address: "9 Del Perro Heights",
    note: "NEWSPAPER",
    noteType: "newspaper",
    stopType: "newspaper",
    recipient: "Porch delivery",
    tracking: "PM-E-90441",
    instructions: "Toss newspaper onto porch. Do not ring doorbell.",
  },
];

const NOTE_STYLES: Record<
  DeliveryNoteType,
  { bg: string; fg: string; accent: string }
> = {
  urgent: { bg: "#ff3d4f", fg: "#ffffff", accent: "#ffd2d7" },
  fragile: { bg: "#ff9f2e", fg: "#2b1a00", accent: "#ffe2b8" },
  dog: { bg: "#8b5e34", fg: "#fff8ef", accent: "#d4b48c" },
  signature: { bg: "#3d7fd6", fg: "#ffffff", accent: "#b8d8ff" },
  cluster: { bg: "#4caf6a", fg: "#f2fff6", accent: "#b8e8c8" },
  newspaper: { bg: "#6d7a8a", fg: "#ffffff", accent: "#c8d4e0" },
  regular: { bg: "#d8cbb8", fg: "#3a342c", accent: "#f5efe6" },
};

const STOP_TYPE_LABELS: Record<string, string> = {
  mailbox: "Mailbox delivery",
  door_knock: "Knock & deliver",
  package: "Heavy package",
  cluster: "Regular mail",
  registered: "Registered mail",
  newspaper: "Newspaper toss",
  dog_yard: "Dog yard",
};

export function getDeliveryItemShape(
  stopType: string,
  noteType?: DeliveryNoteType,
): DeliveryItemShape {
  if (
    stopType === "package" ||
    noteType === "fragile"
  ) {
    return "box";
  }
  if (stopType === "newspaper") return "newspaper";
  return "envelope";
}

function createLabelTexture(
  item: DeliveryMailItem,
  shape: DeliveryItemShape,
): THREE.CanvasTexture {
  const style = NOTE_STYLES[item.noteType];
  const canvas = document.createElement("canvas");
  canvas.width = 1024;
  canvas.height = shape === "box" ? 720 : 640;
  const ctx = canvas.getContext("2d");
  if (!ctx) return new THREE.CanvasTexture(canvas);

  const w = canvas.width;
  const h = canvas.height;

  ctx.clearRect(0, 0, w, h);

  const panelW = shape === "box" ? 880 : 860;
  const panelH = shape === "box" ? 620 : 600;
  const panelX = (w - panelW) / 2;
  const panelY = (h - panelH) / 2;
  const isUrgent = item.noteType === "urgent";
  const addressY = panelY + panelH * 0.56;

  ctx.fillStyle = shape === "box" ? "#f7f2e8" : "#f3ead8";
  roundRect(ctx, panelX, panelY, panelW, panelH, 28);
  ctx.fill();
  ctx.strokeStyle = shape === "box" ? "#c8b79f" : "#d8cbb8";
  ctx.lineWidth = 5;
  roundRect(ctx, panelX, panelY, panelW, panelH, 28);
  ctx.stroke();

  if (isUrgent) {
    const urgentW = panelW - 80;
    const urgentH = 96;
    const urgentX = (w - urgentW) / 2;
    const urgentY = addressY - 150;

    ctx.fillStyle = NOTE_STYLES.urgent.bg;
    roundRect(ctx, urgentX, urgentY, urgentW, urgentH, 18);
    ctx.fill();
    ctx.strokeStyle = NOTE_STYLES.urgent.accent;
    ctx.lineWidth = 5;
    roundRect(ctx, urgentX, urgentY, urgentW, urgentH, 18);
    ctx.stroke();

    ctx.fillStyle = NOTE_STYLES.urgent.fg;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = "bold 64px Inter, Arial, sans-serif";
    ctx.fillText("URGENT", w / 2, urgentY + urgentH / 2);
  } else {
    const badgeW = 360;
    const badgeH = 118;
    const badgeX = (w - badgeW) / 2;
    const badgeY = panelY + 36;

    ctx.fillStyle = style.bg;
    roundRect(ctx, badgeX, badgeY, badgeW, badgeH, 20);
    ctx.fill();
    ctx.strokeStyle = style.accent;
    ctx.lineWidth = 5;
    roundRect(ctx, badgeX, badgeY, badgeW, badgeH, 20);
    ctx.stroke();

    ctx.fillStyle = style.fg;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = "bold 58px Inter, Arial, sans-serif";
    wrapText(ctx, item.note, w / 2, badgeY + 58, badgeW - 30, 54);
  }

  ctx.fillStyle = "#1a2433";
  ctx.font = "bold 76px Inter, Arial, sans-serif";
  ctx.globalAlpha = 1;
  wrapText(ctx, item.address, w / 2, addressY, panelW - 70, 72);

  ctx.fillStyle = "#4a5f7a";
  ctx.font = "600 38px Inter, Arial, sans-serif";
  ctx.globalAlpha = 0.95;
  ctx.fillText(`STOP ${item.label}`, w / 2, panelY + panelH - 96);

  ctx.font = "500 30px Inter, Arial, sans-serif";
  ctx.globalAlpha = 0.82;
  ctx.fillText(
    STOP_TYPE_LABELS[item.stopType] ?? item.stopType,
    w / 2,
    panelY + panelH - 48,
  );

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.needsUpdate = true;
  return texture;
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function wrapText(
  ctx: CanvasRenderingContext2D,
  text: string,
  x: number,
  y: number,
  maxWidth: number,
  lineHeight: number,
) {
  const words = text.split(" ");
  let line = "";
  const lines: string[] = [];

  for (const word of words) {
    const test = line ? `${line} ${word}` : word;
    if (ctx.measureText(test).width > maxWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = test;
    }
  }
  if (line) lines.push(line);

  const startY = y - ((lines.length - 1) * lineHeight) / 2;
  lines.forEach((entry, index) => {
    ctx.fillText(entry, x, startY + index * lineHeight);
  });
}

function createEnvelopeMesh(item: DeliveryMailItem): THREE.Group {
  const group = new THREE.Group();
  group.userData.itemId = item.id;
  const shape: DeliveryItemShape = "envelope";

  const body = new THREE.Mesh(
    new THREE.BoxGeometry(1.05, 0.68, 0.04),
    new THREE.MeshStandardMaterial({ color: "#f3ead8", roughness: 0.84, metalness: 0.02 }),
  );
  group.add(body);

  const flap = new THREE.Mesh(
    new THREE.BoxGeometry(1.0, 0.34, 0.03),
    new THREE.MeshStandardMaterial({ color: "#e8dcc8", roughness: 0.9, metalness: 0.01 }),
  );
  flap.position.set(0, 0.24, 0.025);
  flap.rotation.x = -0.62;
  group.add(flap);

  const label = new THREE.Mesh(
    new THREE.PlaneGeometry(0.96, 0.68),
    new THREE.MeshStandardMaterial({
      map: createLabelTexture(item, shape),
      transparent: true,
      roughness: 0.75,
    }),
  );
  label.position.set(0, -0.04, 0.03);
  group.add(label);

  return group;
}

function createPackageBoxMesh(item: DeliveryMailItem): THREE.Group {
  const group = new THREE.Group();
  group.userData.itemId = item.id;
  const shape: DeliveryItemShape = "box";

  const box = new THREE.Mesh(
    new THREE.BoxGeometry(1.0, 0.68, 0.68),
    new THREE.MeshStandardMaterial({ color: "#c9a66b", roughness: 0.92, metalness: 0.03 }),
  );
  group.add(box);

  const label = new THREE.Mesh(
    new THREE.PlaneGeometry(0.82, 0.62),
    new THREE.MeshStandardMaterial({
      map: createLabelTexture(item, shape),
      transparent: true,
      alphaTest: 0.08,
      roughness: 0.8,
    }),
  );
  label.position.set(0, 0, 0.35);
  group.add(label);

  const edge = new THREE.LineSegments(
    new THREE.EdgesGeometry(new THREE.BoxGeometry(1.0, 0.68, 0.68)),
    new THREE.LineBasicMaterial({ color: "#8b6a3e", transparent: true, opacity: 0.5 }),
  );
  group.add(edge);

  return group;
}

function createNewspaperMesh(item: DeliveryMailItem): THREE.Group {
  const group = new THREE.Group();
  group.userData.itemId = item.id;
  const shape: DeliveryItemShape = "newspaper";

  const roll = new THREE.Mesh(
    new THREE.CylinderGeometry(0.22, 0.22, 0.9, 28),
    new THREE.MeshStandardMaterial({ color: "#d5cec0", roughness: 0.88, metalness: 0.02 }),
  );
  roll.rotation.z = Math.PI / 2;
  group.add(roll);

  const band = new THREE.Mesh(
    new THREE.TorusGeometry(0.225, 0.018, 10, 32),
    new THREE.MeshStandardMaterial({ color: "#ece7dc", roughness: 0.9 }),
  );
  band.rotation.y = Math.PI / 2;
  group.add(band);

  const label = new THREE.Mesh(
    new THREE.PlaneGeometry(0.72, 0.56),
    new THREE.MeshStandardMaterial({
      map: createLabelTexture(item, shape),
      transparent: true,
      roughness: 0.78,
    }),
  );
  label.position.set(0, 0.12, 0.24);
  label.rotation.x = -0.25;
  group.add(label);

  return group;
}

function createDeliveryItemMesh(item: DeliveryMailItem): THREE.Group {
  const shape = getDeliveryItemShape(item.stopType, item.noteType);
  if (shape === "box") return createPackageBoxMesh(item);
  if (shape === "newspaper") return createNewspaperMesh(item);
  return createEnvelopeMesh(item);
}

function configureMeshShadows(root: THREE.Object3D) {
  root.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;

    const materials = Array.isArray(object.material) ? object.material : [object.material];
    const isTransparent = materials.some((entry) => {
      if (entry.transparent) return true;
      if (entry.opacity < 1) return true;
      if ("alphaTest" in entry && typeof entry.alphaTest === "number" && entry.alphaTest > 0) {
        return true;
      }
      return false;
    });

    object.castShadow = !isTransparent;
    object.receiveShadow = !isTransparent;
  });
}

function createSpotlightGroundTexture(): THREE.CanvasTexture {
  const size = 512;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  if (!ctx) return new THREE.CanvasTexture(canvas);

  const center = size / 2;
  const spotlight = ctx.createRadialGradient(center, center, 0, center, center, center * 0.92);
  spotlight.addColorStop(0, "rgba(58, 66, 74, 0.55)");
  spotlight.addColorStop(0.22, "rgba(42, 48, 56, 0.35)");
  spotlight.addColorStop(0.48, "rgba(30, 34, 40, 0.16)");
  spotlight.addColorStop(0.72, "rgba(21, 24, 30, 0.05)");
  spotlight.addColorStop(1, "rgba(21, 24, 30, 0)");

  ctx.fillStyle = spotlight;
  ctx.fillRect(0, 0, size, size);

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.needsUpdate = true;
  return texture;
}

function createShadowGround(): THREE.Group {
  const group = new THREE.Group();
  group.position.y = -0.38;

  const spotlight = new THREE.Mesh(
    new THREE.CircleGeometry(2.35, 80),
    new THREE.MeshBasicMaterial({
      map: createSpotlightGroundTexture(),
      transparent: true,
      depthWrite: false,
      toneMapped: false,
    }),
  );
  spotlight.rotation.x = -Math.PI / 2;
  group.add(spotlight);

  const shadowReceiver = new THREE.Mesh(
    new THREE.CircleGeometry(1.85, 64),
    new THREE.ShadowMaterial({ opacity: 0.72, color: "#000000" }),
  );
  shadowReceiver.rotation.x = -Math.PI / 2;
  shadowReceiver.position.y = 0.002;
  shadowReceiver.receiveShadow = true;
  group.add(shadowReceiver);

  return group;
}

function createSceneLighting(scene: THREE.Scene) {
  const lights: THREE.Object3D[] = [];

  const hemi = new THREE.HemisphereLight("#e2f6f2", "#1c2e2c", 0.9);
  scene.add(hemi);
  lights.push(hemi);

  const ambient = new THREE.AmbientLight("#a8bddf", 0.55);
  scene.add(ambient);
  lights.push(ambient);

  const key = new THREE.DirectionalLight("#fff8ef", 3.4);
  key.position.set(1.8, 3.8, 2.5);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  key.shadow.camera.near = 0.4;
  key.shadow.camera.far = 10;
  const shadowSpan = 2.2;
  key.shadow.camera.left = -shadowSpan;
  key.shadow.camera.right = shadowSpan;
  key.shadow.camera.top = shadowSpan;
  key.shadow.camera.bottom = -shadowSpan;
  key.shadow.bias = -0.00015;
  key.shadow.normalBias = 0.018;
  key.shadow.radius = 1.1;
  scene.add(key);
  lights.push(key);

  const fill = new THREE.DirectionalLight("#9fd4ff", 1.65);
  fill.position.set(-2.3, 1.9, 2.2);
  scene.add(fill);
  lights.push(fill);

  const backFill = new THREE.DirectionalLight("#d8e6ff", 0.95);
  backFill.position.set(0.2, 1.4, -2.8);
  scene.add(backFill);
  lights.push(backFill);

  const rimRight = new THREE.SpotLight("#4fe3cf", 1.7, 8, Math.PI / 4.8, 0.4, 1.15);
  rimRight.position.set(2.2, 1.6, -1.2);
  rimRight.target.position.set(0, 0.12, 0);
  scene.add(rimRight);
  scene.add(rimRight.target);
  lights.push(rimRight, rimRight.target);

  const rimLeft = new THREE.SpotLight("#7eb8ff", 1.25, 8, Math.PI / 4.8, 0.42, 1.15);
  rimLeft.position.set(-2.1, 1.3, -1.1);
  rimLeft.target.position.set(0, 0.12, 0);
  scene.add(rimLeft);
  scene.add(rimLeft.target);
  lights.push(rimLeft, rimLeft.target);

  const frontAccent = new THREE.PointLight("#fff4df", 0.95, 5);
  frontAccent.position.set(0.4, 0.8, 2.4);
  scene.add(frontAccent);
  lights.push(frontAccent);

  return {
    dispose: () => {
      lights.forEach((light) => scene.remove(light));
    },
  };
}

function disposeObject3D(root: THREE.Object3D) {
  root.traverse((object) => {
    if (object instanceof THREE.Mesh) {
      object.geometry.dispose();
      const material = object.material;
      if (Array.isArray(material)) {
        material.forEach((entry) => {
          if (entry.map) entry.map.dispose();
          entry.dispose();
        });
      } else {
        if (material.map) material.map.dispose();
        material.dispose();
      }
    }
  });
}

export interface DeliveryItemsSceneOptions {
  onSelect?: (itemId: string | null) => void;
  initialSelectedId?: string | null;
}

export interface DeliveryItemsSceneHandle {
  dispose: () => void;
  setSelected: (itemId: string | null) => void;
}

export function createDeliveryItemsScene(
  container: HTMLElement,
  items: DeliveryMailItem[],
  options: DeliveryItemsSceneOptions = {},
): DeliveryItemsSceneHandle {
  const width = container.clientWidth;
  const height = container.clientHeight;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color("#15181e");
  scene.fog = new THREE.Fog("#15181e", 7, 16);

  const camera = new THREE.PerspectiveCamera(38, width / height, 0.1, 100);
  camera.position.set(0, 0.95, 3.1);
  camera.lookAt(0, 0.35, 0);

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(width, height);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.45;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  container.appendChild(renderer.domElement);

  const lighting = createSceneLighting(scene);

  const displayGroup = new THREE.Group();
  displayGroup.position.set(0.75, 0.18, 0);
  scene.add(displayGroup);

  const shadowGround = createShadowGround();
  displayGroup.add(shadowGround);

  let activeMesh: THREE.Group | null = null;
  let selectedId: string | null = options.initialSelectedId ?? items[0]?.id ?? null;
  let swapStart = 0;
  let animationId = 0;
  const clock = new THREE.Clock();

  const showItem = (itemId: string | null) => {
    if (activeMesh) {
      displayGroup.remove(activeMesh);
      disposeObject3D(activeMesh);
      activeMesh = null;
    }
    if (!itemId) return;

    const item = items.find((entry) => entry.id === itemId);
    if (!item) return;

    activeMesh = createDeliveryItemMesh(item);
    configureMeshShadows(activeMesh);
    activeMesh.scale.setScalar(0.72);
    activeMesh.rotation.set(-0.12, 0.35, 0.04);
    displayGroup.add(activeMesh);
    swapStart = clock.getElapsedTime();
  };

  const setSelected = (itemId: string | null) => {
    if (itemId === selectedId) return;
    selectedId = itemId;
    showItem(itemId);
    options.onSelect?.(itemId);
  };

  showItem(selectedId);

  const onResize = () => {
    const nextWidth = container.clientWidth;
    const nextHeight = container.clientHeight;
    camera.aspect = nextWidth / nextHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(nextWidth, nextHeight);
  };

  window.addEventListener("resize", onResize);

  const animate = () => {
    const t = clock.getElapsedTime();
    const sinceSwap = t - swapStart;

    if (activeMesh) {
      const pop = Math.min(sinceSwap / 0.45, 1);
      const ease = 1 - Math.pow(1 - pop, 3);
      const floatY = Math.sin(t * 0.9) * 0.05 + 0.04;

      activeMesh.scale.setScalar(0.72 + ease * 0.08);
      activeMesh.rotation.y = 0.35 + Math.sin(t * 0.55) * 0.12;
      activeMesh.position.y = floatY;
    }

    renderer.render(scene, camera);
    animationId = window.requestAnimationFrame(animate);
  };

  animate();

  return {
    dispose: () => {
      window.cancelAnimationFrame(animationId);
      window.removeEventListener("resize", onResize);
      lighting.dispose();
      if (activeMesh) {
        displayGroup.remove(activeMesh);
        disposeObject3D(activeMesh);
      }
      renderer.dispose();
      if (renderer.domElement.parentElement === container) {
        container.removeChild(renderer.domElement);
      }
      scene.traverse((object) => {
        if (object instanceof THREE.Mesh || object instanceof THREE.LineSegments) {
          object.geometry.dispose();
          const material = object.material;
          if (Array.isArray(material)) {
            material.forEach((entry) => entry.dispose());
          } else {
            material.dispose();
          }
        }
      });
    },
    setSelected,
  };
}

/** @deprecated Use createDeliveryItemsScene */
export const createDeliveryHandScene = createDeliveryItemsScene;
