import "./style.css";
import type {
  BootstrapPayload,
  LibraryTab,
  MediaLibraryItem,
  MediaMetadata,
} from "./common/contracts";

type AppView = "home" | "settings" | "info" | "player" | "cinema" | "visualizer";
type PlayerMode = "playing" | "paused";
type RepeatMode = "all" | "one" | "off";

interface IndexedMediaItem {
  item: MediaLibraryItem;
  index: number;
}

interface ShellState {
  activeView: AppView;
  activeTab: LibraryTab;
  searchQuery: string;
  selectedIndex: number;
  volume: number;
  playbackSpeed: number;
  playerMode: PlayerMode;
  repeatMode: RepeatMode;
  shuffleEnabled: boolean;
  dataDirectoryLabel: string;
  audioDirectoryLabel: string;
  videoDirectoryLabel: string;
  actionLog: string;
}

const SPEED_STEPS = [0.5, 0.75, 0.9, 1.0, 1.1, 1.25, 1.4, 1.5, 1.75, 2.0];

const mediaRows: Record<LibraryTab, MediaLibraryItem[]> = {
  audio: [],
  video: [],
};

const durationCache = new Map<string, number>();
const metadataCache = new Map<string, MediaMetadata>();
const metadataRequests = new Map<string, Promise<MediaMetadata | null>>();

const audioPlayer = new Audio();
audioPlayer.preload = "metadata";

const videoPlayer = document.createElement("video");
videoPlayer.preload = "metadata";
videoPlayer.playsInline = true;

const state: ShellState = {
  activeView: "home",
  activeTab: "audio",
  searchQuery: "",
  selectedIndex: 0,
  volume: 70,
  playbackSpeed: 1.0,
  playerMode: "paused",
  repeatMode: "all",
  shuffleEnabled: false,
  dataDirectoryLabel: "Not selected yet",
  audioDirectoryLabel: "Not selected yet",
  videoDirectoryLabel: "Not selected yet",
  actionLog: "Ready.",
};

let bootstrap: BootstrapPayload | null = null;
let disposeMainMessageListener: (() => void) | null = null;
let currentPlayingItemId: string | null = null;
let preMuteVolume: number | null = null;
let cinemaControlsTimer: ReturnType<typeof setTimeout> | null = null;
let cinemaControlsVisible = true;
let metadataObserver: IntersectionObserver | null = null;

/* ── Web Audio API for Visualizer ── */
let audioContext: AudioContext | null = null;
let analyserNode: AnalyserNode | null = null;
let audioSourceNode: MediaElementAudioSourceNode | null = null;
let visualizerAnimationId: number | null = null;
let visualizerControlsTimer: ReturnType<typeof setTimeout> | null = null;
let visualizerControlsVisible = true;
let visualizerArtImage: HTMLImageElement | null = null;
let videoLibraryScanned = false;
let vizSmoothedIntensity = 0;
let visualizerArtSrc = "";

/* ── Inline SVG Icons for Transport ── */
const ICON = {
  shuffle: `<img src="./shuffle.svg" width="18" height="18" alt="Shuffle" />`,
  prev: `<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z"/></svg>`,
  play: `<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>`,
  pause: `<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>`,
  next: `<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>`,
  repeat: `<img src="./loop.svg" width="18" height="18" alt="Repeat" />`,
  refresh: `<img src="./retry.svg" width="16" height="16" alt="Refresh" />`,
  volume: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/></svg>`,
  expand: `<img src="./fullscreen.svg" width="18" height="18" alt="Fullscreen" />`,
};

const appRoot = getAppRoot();

renderShell();
wireUiEvents();
wireMediaEvents();
applyVolumeToPlayers();
void initializeApp();

function renderShell() {
  normalizeSelectedIndex();

  if (state.activeView === "cinema") {
    appRoot.innerHTML = renderVideoCinema();
    mountCinemaVideo();
    return;
  }

  if (state.activeView === "visualizer") {
    appRoot.innerHTML = renderVisualizer();
    mountVisualizer();
    return;
  }

  if (state.activeView === "player") {
    appRoot.innerHTML = `
      <div class="fumic-shell player-mode">
        <div class="backdrop player-backdrop" ${getNowPlayingBackdropStyle()}></div>
        <button id="nav-home" class="chip back-btn" type="button">Close</button>
        
        <main class="player-center">
          ${renderPlayerCenter()}
        </main>
      </div>
      ${renderTransportDock()}
    `;
    return;
  }

  appRoot.innerHTML = `
    <div class="fumic-shell" data-active-tab="${state.activeTab}" data-active-view="${state.activeView}">
      <div class="backdrop"></div>

      <header class="chrome-bar">
        <div class="brand-lockup">
          <img src="./fumic_logo_trans.png" alt="Fumic" class="brand-logo" />
          <h1>Fumic</h1>
        </div>

        <nav class="primary-nav" aria-label="Views">
          <button id="nav-home" class="chip ${state.activeView === "home" ? "active" : ""}" type="button">Home</button>
          <button id="nav-settings" class="chip ${state.activeView === "settings" ? "active" : ""}" type="button">Settings</button>
          <button id="nav-info" class="chip ${state.activeView === "info" ? "active" : ""}" type="button">Info</button>
          <button id="manual-refresh" class="chip refresh-chip" type="button" title="Refresh Library">${ICON.refresh}</button>
        </nav>

        <div class="search-wrap">
          <input id="global-search" type="text" placeholder="Search media (Ctrl + K)" value="${escapeHtml(state.searchQuery)}" />
        </div>

        <div class="tab-pills" role="tablist" aria-label="Library Tabs">
          <button id="tab-audio" class="tab-pill ${state.activeTab === "audio" ? "active" : ""}" type="button" role="tab" aria-selected="${state.activeTab === "audio"}">Audio</button>
          <button id="tab-video" class="tab-pill ${state.activeTab === "video" ? "active" : ""}" type="button" role="tab" aria-selected="${state.activeTab === "video"}">Video</button>
        </div>
      </header>

      <main class="view-root">
        ${renderView()}
      </main>
    </div>
    ${renderTransportDock()}
  `;

  primeVisibleDurations();

  /* Mount the actual <video> element into the player if in video mode */
  const videoMount = document.querySelector<HTMLElement>("#fs-video-mount");
  if (videoMount && getCurrentPlayingItem()?.kind === "video") {
    videoPlayer.style.width = "100%";
    videoPlayer.style.maxHeight = "70vh";
    videoPlayer.style.borderRadius = "12px";
    videoPlayer.style.objectFit = "contain";
    videoMount.appendChild(videoPlayer);
  }
}

function renderTransportDock() {
  const current = getCurrentPlayingItem();
  const meta = current ? metadataCache.get(current.filePath) : null;
  const thumbStyle = meta?.pictureBase64 ? `style="background-image: url('${meta.pictureBase64}')"` : '';

  return `
    <footer class="transport-dock transport-spotify">
      <div class="progress-bar-wrap">
        <span class="progress-time" id="progress-current">0:00</span>
        <div class="progress-bar" id="progress-bar-track">
          <div class="progress-fill" id="transport-progress" style="width: 0%;">
            <div class="progress-thumb"></div>
          </div>
        </div>
        <span class="progress-time" id="progress-duration">${escapeHtml(current ? getDurationLabel(current) : "0:00")}</span>
      </div>

      <div class="dock-bottom">
        <div class="dock-section now-playing">
          <div class="now-playing-thumb" ${thumbStyle}></div>
          <div class="now-playing-text">
            <p class="dock-value" id="now-playing-title">${escapeHtml(getNowPlayingName() ?? "None")}</p>
            <p class="runtime-badge" id="now-playing-meta">${escapeHtml(getNowPlayingMeta())}</p>
          </div>
        </div>

        <div class="dock-section controls spotify-controls">
          <button id="toggle-shuffle" class="transport-icon ${state.shuffleEnabled ? "active" : ""}" type="button" aria-label="Shuffle" title="Shuffle">${ICON.shuffle}</button>
          <button id="transport-prev" class="transport-icon" type="button" aria-label="Previous" title="Previous">${ICON.prev}</button>
          <button id="toggle-play" class="transport-icon transport-primary" type="button" aria-label="Play or pause" title="Play/Pause">
            ${state.playerMode === "playing" ? ICON.pause : ICON.play}
          </button>
          <button id="transport-next" class="transport-icon" type="button" aria-label="Next" title="Next">${ICON.next}</button>
          <button id="cycle-repeat" class="transport-icon ${state.repeatMode !== "off" ? "active" : ""}" type="button" aria-label="Repeat" title="Repeat: ${state.repeatMode}" data-repeat="${state.repeatMode}">${ICON.repeat}</button>
        </div>

        <div class="dock-section status">
          <span class="speed-label" id="speed-label" title="Playback speed (Shift + &lt; / &gt;)">${state.playbackSpeed === 1.0 ? "" : state.playbackSpeed.toFixed(2) + "x"}</span>
          <div class="status-grid">
            <span class="volume-icon">${ICON.volume}</span>
            <div class="volume-bar">
              <div class="volume-fill" style="width: ${state.volume}%;"></div>
            </div>
            <strong id="volume-label">${state.volume}%</strong>
          </div>
          <button id="toggle-player-mode" class="transport-icon fs-btn" type="button" title="Full Screen Player (Ctrl + F)">${ICON.expand}</button>
        </div>
      </div>
    </footer>
  `;
}

function getNowPlayingBackdropStyle() {
  const current = getCurrentPlayingItem();
  if (current) {
    const meta = metadataCache.get(current.filePath);
    if (meta?.pictureBase64) {
      return `style="background-image: url('${meta.pictureBase64}');"`;
    }
  }
  return "";
}

function renderPlayerCenter() {
  const current = getCurrentPlayingItem();
  if (!current) return `<div class="empty-player"><h2>No media selected</h2></div>`;

  const meta = metadataCache.get(current.filePath);
  const thumbStyle = meta?.pictureBase64 ? `style="background-image: url('${meta.pictureBase64}')"` : '';

  const isVideo = current?.kind === "video";

  return `
    <div class="fullscreen-player">
      ${isVideo ? '<div class="fs-video-wrap" id="fs-video-mount"></div>' : `<div class="fs-art" ${thumbStyle}></div>`}
      <h1 class="fs-title">${escapeHtml(getMediaTitle(current))}</h1>
      <h2 class="fs-subtitle">${escapeHtml(getMediaSubtitle(current))}</h2>
      <p class="fs-duration">${escapeHtml(getDurationLabel(current))}</p>
    </div>
  `;
}

function renderVideoCinema() {
  const current = getCurrentPlayingItem();
  if (!current) {
    return '<div class="video-cinema"><p style="color:#fff;text-align:center;margin:auto;">No video selected</p></div>';
  }

  return `
    <div class="video-cinema" id="video-cinema">
      <div class="video-cinema-video-wrap" id="cinema-video-mount"></div>
      <div class="video-cinema-overlay" id="cinema-overlay">
        <button class="video-cinema-close" id="cinema-close" type="button">✕</button>
        <div class="video-cinema-bottom">
          <div class="cinema-info">
            <p class="cinema-title" id="cinema-title">${escapeHtml(getMediaTitle(current))}</p>
            <p class="cinema-subtitle" id="cinema-subtitle">${escapeHtml(getMediaSubtitle(current))}</p>
          </div>
          <div class="progress-bar-wrap cinema-progress">
            <span class="progress-time" id="progress-current">0:00</span>
            <div class="progress-bar" id="progress-bar-track">
              <div class="progress-fill" id="transport-progress" style="width: 0%;">
                <div class="progress-thumb"></div>
              </div>
            </div>
            <span class="progress-time" id="progress-duration">${escapeHtml(getDurationLabel(current))}</span>
          </div>
          <div class="cinema-transport">
            <button id="toggle-shuffle" class="transport-icon ${state.shuffleEnabled ? "active" : ""}" type="button" title="Shuffle">${ICON.shuffle}</button>
            <button id="transport-prev" class="transport-icon" type="button" title="Previous">${ICON.prev}</button>
            <button id="toggle-play" class="transport-icon transport-primary" type="button" title="Play/Pause">
              ${state.playerMode === "playing" ? ICON.pause : ICON.play}
            </button>
            <button id="transport-next" class="transport-icon" type="button" title="Next">${ICON.next}</button>
            <button id="cycle-repeat" class="transport-icon ${state.repeatMode !== "off" ? "active" : ""}" type="button" title="Repeat: ${state.repeatMode}" data-repeat="${state.repeatMode}">${ICON.repeat}</button>
            <div class="cinema-volume-group">
              <span class="volume-icon">${ICON.volume}</span>
              <div class="volume-bar">
                <div class="volume-fill" style="width: ${state.volume}%;"></div>
              </div>
              <strong id="volume-label">${state.volume}%</strong>
            </div>
            <span class="speed-label" id="speed-label">${state.playbackSpeed === 1.0 ? "" : state.playbackSpeed.toFixed(2) + "x"}</span>
          </div>
        </div>
      </div>
    </div>
  `;
}

function mountCinemaVideo() {
  const mount = document.querySelector<HTMLElement>("#cinema-video-mount");
  if (mount) {
    videoPlayer.style.width = "100%";
    videoPlayer.style.height = "100%";
    videoPlayer.style.maxHeight = "";
    videoPlayer.style.borderRadius = "0";
    videoPlayer.style.objectFit = "contain";
    mount.appendChild(videoPlayer);
  }

  const cinema = document.querySelector<HTMLElement>("#video-cinema");
  if (cinema) {
    cinema.addEventListener("mousemove", handleCinemaActivity);
  }

  cinemaControlsVisible = true;
  resetCinemaControlsTimer();
}

function handleCinemaActivity() {
  showCinemaControls();
  resetCinemaControlsTimer();
}

function showCinemaControls() {
  if (cinemaControlsVisible) return;
  cinemaControlsVisible = true;
  const cinema = document.querySelector<HTMLElement>("#video-cinema");
  cinema?.classList.remove("controls-hidden");
}

function hideCinemaControls() {
  if (!cinemaControlsVisible) return;
  cinemaControlsVisible = false;
  const cinema = document.querySelector<HTMLElement>("#video-cinema");
  cinema?.classList.add("controls-hidden");
}

function resetCinemaControlsTimer() {
  if (cinemaControlsTimer !== null) {
    clearTimeout(cinemaControlsTimer);
  }
  cinemaControlsTimer = setTimeout(() => {
    hideCinemaControls();
  }, 2500);
}

function cleanupCinemaMode() {
  if (cinemaControlsTimer !== null) {
    clearTimeout(cinemaControlsTimer);
    cinemaControlsTimer = null;
  }
  cinemaControlsVisible = true;
  const cinema = document.querySelector<HTMLElement>("#video-cinema");
  if (cinema) {
    cinema.removeEventListener("mousemove", handleCinemaActivity);
  }
}

/** Update cinema overlay info when track changes without full re-render */
function updateCinemaInfo() {
  if (state.activeView !== "cinema") return;
  const current = getCurrentPlayingItem();
  if (!current) return;
  const title = document.querySelector<HTMLElement>("#cinema-title");
  if (title) title.textContent = getMediaTitle(current);
  const subtitle = document.querySelector<HTMLElement>("#cinema-subtitle");
  if (subtitle) subtitle.textContent = getMediaSubtitle(current);
}

/* ========================================
   AUDIO VISUALIZER
   ======================================== */

function initAudioAnalyser() {
  if (analyserNode) return;
  audioContext = new AudioContext();
  analyserNode = audioContext.createAnalyser();
  analyserNode.fftSize = 256;
  analyserNode.smoothingTimeConstant = 0.82;
  audioSourceNode = audioContext.createMediaElementSource(audioPlayer);
  audioSourceNode.connect(analyserNode);
  analyserNode.connect(audioContext.destination);
}

function renderVisualizer() {
  const current = getCurrentPlayingItem();
  if (!current) {
    return '<div class="audio-visualizer"><p style="color:#fff;text-align:center;margin:auto;">No audio playing</p></div>';
  }

  return `
    <div class="audio-visualizer" id="audio-visualizer">
      <canvas class="visualizer-canvas" id="visualizer-canvas"></canvas>
      <div class="visualizer-overlay" id="visualizer-overlay">
        <button class="visualizer-close" id="visualizer-close" type="button">✕</button>
        <div class="visualizer-bottom">
          <div class="visualizer-info">
            <p class="visualizer-title" id="visualizer-title">${escapeHtml(getMediaTitle(current))}</p>
            <p class="visualizer-subtitle" id="visualizer-subtitle">${escapeHtml(getMediaSubtitle(current))}</p>
          </div>
          <div class="progress-bar-wrap visualizer-progress">
            <span class="progress-time" id="progress-current">0:00</span>
            <div class="progress-bar" id="progress-bar-track">
              <div class="progress-fill" id="transport-progress" style="width: 0%;">
                <div class="progress-thumb"></div>
              </div>
            </div>
            <span class="progress-time" id="progress-duration">${escapeHtml(getDurationLabel(current))}</span>
          </div>
          <div class="visualizer-transport">
            <button id="toggle-shuffle" class="transport-icon ${state.shuffleEnabled ? "active" : ""}" type="button" title="Shuffle">${ICON.shuffle}</button>
            <button id="transport-prev" class="transport-icon" type="button" title="Previous">${ICON.prev}</button>
            <button id="toggle-play" class="transport-icon transport-primary" type="button" title="Play/Pause">
              ${state.playerMode === "playing" ? ICON.pause : ICON.play}
            </button>
            <button id="transport-next" class="transport-icon" type="button" title="Next">${ICON.next}</button>
            <button id="cycle-repeat" class="transport-icon ${state.repeatMode !== "off" ? "active" : ""}" type="button" title="Repeat: ${state.repeatMode}" data-repeat="${state.repeatMode}">${ICON.repeat}</button>
            <div class="visualizer-volume-group">
              <span class="volume-icon">${ICON.volume}</span>
              <div class="volume-bar">
                <div class="volume-fill" style="width: ${state.volume}%;"></div>
              </div>
              <strong id="volume-label">${state.volume}%</strong>
            </div>
            <span class="speed-label" id="speed-label">${state.playbackSpeed === 1.0 ? "" : state.playbackSpeed.toFixed(2) + "x"}</span>
          </div>
        </div>
      </div>
    </div>
  `;
}

function mountVisualizer() {
  initAudioAnalyser();

  if (audioContext && audioContext.state === "suspended") {
    void audioContext.resume();
  }

  const canvas = document.querySelector<HTMLCanvasElement>("#visualizer-canvas");
  if (!canvas) return;

  const resize = () => {
    canvas.width = window.innerWidth * (window.devicePixelRatio || 1);
    canvas.height = window.innerHeight * (window.devicePixelRatio || 1);
    canvas.style.width = "100%";
    canvas.style.height = "100%";
  };
  resize();
  window.addEventListener("resize", resize);

  /* Load album art for center disc */
  const current = getCurrentPlayingItem();
  const meta = current ? metadataCache.get(current.filePath) : null;
  if (meta?.pictureBase64 && meta.pictureBase64 !== visualizerArtSrc) {
    visualizerArtImage = new Image();
    visualizerArtSrc = meta.pictureBase64;
    visualizerArtImage.src = meta.pictureBase64;
  } else if (!meta?.pictureBase64) {
    visualizerArtImage = null;
    visualizerArtSrc = "";
  }

  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  drawVisualizerFrame(canvas, ctx);

  const container = document.querySelector<HTMLElement>("#audio-visualizer");
  if (container) {
    container.addEventListener("mousemove", handleVisualizerActivity);
  }
  visualizerControlsVisible = true;
  resetVisualizerControlsTimer();
}

function drawVisualizerFrame(canvas: HTMLCanvasElement, ctx: CanvasRenderingContext2D) {
  const W = canvas.width;
  const H = canvas.height;
  const cx = W / 2;
  const cy = H * 0.45;
  const dpr = window.devicePixelRatio || 1;
  const time = performance.now() / 1000;
  const minDim = Math.min(W, H);

  const bufferLength = analyserNode ? analyserNode.frequencyBinCount : 128;
  const dataArray = new Uint8Array(bufferLength);
  if (analyserNode) analyserNode.getByteFrequencyData(dataArray);

  /* ── Calculate overall intensity (average of all bins) ── */
  let rawSum = 0;
  for (let i = 0; i < bufferLength; i++) rawSum += dataArray[i];
  const rawIntensity = rawSum / (bufferLength * 255);
  /* Exponential smoothing for fluid motion */
  vizSmoothedIntensity = vizSmoothedIntensity * 0.88 + rawIntensity * 0.12;
  const intensity = vizSmoothedIntensity;

  /* ── Background ── */
  ctx.fillStyle = "#050510";
  ctx.fillRect(0, 0, W, H);

  /* Pulsing ambient glow */
  const ambientRadius = minDim * (0.5 + intensity * 0.2);
  const ambientGlow = ctx.createRadialGradient(cx, cy, 0, cx, cy, ambientRadius);
  ambientGlow.addColorStop(0, `rgba(0, 220, 200, ${0.04 + intensity * 0.08})`);
  ambientGlow.addColorStop(0.3, `rgba(100, 0, 255, ${0.03 + intensity * 0.06})`);
  ambientGlow.addColorStop(0.6, `rgba(255, 0, 180, ${0.02 + intensity * 0.04})`);
  ambientGlow.addColorStop(1, "transparent");
  ctx.fillStyle = ambientGlow;
  ctx.fillRect(0, 0, W, H);

  /* ── Dimensions ── */
  const artRadius = minDim * 0.16;
  const ringGap = minDim * 0.035;
  const baseRingRadius = artRadius + ringGap;
  const maxExpansion = minDim * 0.06;
  const pulseAmplitude = minDim * 0.008;
  const pulse = Math.sin(time * 3.5) * pulseAmplitude;
  const dynamicRingRadius = baseRingRadius + intensity * maxExpansion + pulse;
  const baseThickness = 4 * dpr;
  const dynamicThickness = baseThickness + intensity * 12 * dpr;

  /* ── Ring segments count for smooth wave effect ── */
  const segmentCount = 200;

  /* Create a subtle wave pattern on the ring driven by intensity */
  const waveCount = 6;
  const waveSpeed = 2.2;
  const waveAmplitude = intensity * minDim * 0.018;

  /* Slowly rotating color offset for dynamism */
  const colorRotation = time * 0.15;

  /* ── Draw glowing ring (3 layers for neon glow) ── */
  const glowLayers = [
    { blur: 40 * dpr, alpha: 0.15 + intensity * 0.15, widthMul: 3.0 },
    { blur: 18 * dpr, alpha: 0.3 + intensity * 0.2, widthMul: 1.8 },
    { blur: 4 * dpr, alpha: 0.7 + intensity * 0.3, widthMul: 1.0 },
  ];

  for (const layer of glowLayers) {
    ctx.save();
    ctx.shadowBlur = layer.blur;
    ctx.lineWidth = dynamicThickness * layer.widthMul;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    /* Draw the ring as connected segments with wave variation */
    ctx.beginPath();
    for (let i = 0; i <= segmentCount; i++) {
      const t = i / segmentCount;
      const angle = t * Math.PI * 2 - Math.PI / 2;
      const wave = Math.sin(angle * waveCount + time * waveSpeed) * waveAmplitude;
      const r = dynamicRingRadius + wave;
      const x = cx + Math.cos(angle) * r;
      const y = cy + Math.sin(angle) * r;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.closePath();

    /* Conic gradient for rainbow/cyan/teal Trap Nation look */
    const gradient = ctx.createConicGradient(colorRotation, cx, cy);
    gradient.addColorStop(0, `rgba(0, 255, 210, ${layer.alpha})`);
    gradient.addColorStop(0.12, `rgba(0, 200, 255, ${layer.alpha})`);
    gradient.addColorStop(0.25, `rgba(120, 0, 255, ${layer.alpha})`);
    gradient.addColorStop(0.37, `rgba(255, 0, 200, ${layer.alpha})`);
    gradient.addColorStop(0.5, `rgba(255, 80, 80, ${layer.alpha})`);
    gradient.addColorStop(0.62, `rgba(255, 200, 0, ${layer.alpha})`);
    gradient.addColorStop(0.75, `rgba(0, 255, 120, ${layer.alpha})`);
    gradient.addColorStop(0.87, `rgba(0, 220, 255, ${layer.alpha})`);
    gradient.addColorStop(1, `rgba(0, 255, 210, ${layer.alpha})`);

    ctx.strokeStyle = gradient;
    ctx.shadowColor = `rgba(0, 220, 200, ${layer.alpha * 0.6})`;
    ctx.stroke();
    ctx.restore();
  }

  /* ── Inner glow ring (subtle white highlight at art boundary) ── */
  ctx.save();
  ctx.beginPath();
  ctx.arc(cx, cy, artRadius + 2 * dpr, 0, Math.PI * 2);
  ctx.strokeStyle = `rgba(255, 255, 255, ${0.06 + intensity * 0.08})`;
  ctx.lineWidth = 1.5 * dpr;
  ctx.shadowBlur = 12 * dpr;
  ctx.shadowColor = `rgba(0, 255, 210, ${0.1 + intensity * 0.15})`;
  ctx.stroke();
  ctx.restore();

  /* ── Center disc - album art or gradient ── */
  ctx.save();
  ctx.beginPath();
  ctx.arc(cx, cy, artRadius, 0, Math.PI * 2);
  ctx.closePath();
  ctx.clip();

  if (visualizerArtImage && visualizerArtImage.complete && visualizerArtImage.naturalWidth > 0) {
    const sz = artRadius * 2;
    ctx.drawImage(visualizerArtImage, cx - sz / 2, cy - sz / 2, sz, sz);
  } else {
    const discG = ctx.createRadialGradient(cx, cy, 0, cx, cy, artRadius);
    discG.addColorStop(0, `rgba(0, 220, 200, ${0.5 + intensity * 0.3})`);
    discG.addColorStop(0.5, `rgba(100, 0, 255, ${0.3 + intensity * 0.2})`);
    discG.addColorStop(1, `rgba(20, 10, 40, 0.9)`);
    ctx.fillStyle = discG;
    ctx.fillRect(cx - artRadius, cy - artRadius, artRadius * 2, artRadius * 2);
  }
  ctx.restore();

  /* ── Art border ring ── */
  ctx.beginPath();
  ctx.arc(cx, cy, artRadius, 0, Math.PI * 2);
  ctx.strokeStyle = `rgba(255, 255, 255, ${0.12 + intensity * 0.12})`;
  ctx.lineWidth = 1.5 * dpr;
  ctx.stroke();

  visualizerAnimationId = requestAnimationFrame(() => drawVisualizerFrame(canvas, ctx));
}

function cleanupVisualizer() {
  if (visualizerAnimationId !== null) {
    cancelAnimationFrame(visualizerAnimationId);
    visualizerAnimationId = null;
  }
  if (visualizerControlsTimer !== null) {
    clearTimeout(visualizerControlsTimer);
    visualizerControlsTimer = null;
  }
  visualizerControlsVisible = true;
  const container = document.querySelector<HTMLElement>("#audio-visualizer");
  if (container) container.removeEventListener("mousemove", handleVisualizerActivity);
}

function handleVisualizerActivity() {
  showVisualizerControls();
  resetVisualizerControlsTimer();
}

function showVisualizerControls() {
  if (visualizerControlsVisible) return;
  visualizerControlsVisible = true;
  const el = document.querySelector<HTMLElement>("#audio-visualizer");
  el?.classList.remove("controls-hidden");
}

function hideVisualizerControls() {
  if (!visualizerControlsVisible) return;
  visualizerControlsVisible = false;
  const el = document.querySelector<HTMLElement>("#audio-visualizer");
  el?.classList.add("controls-hidden");
}

function resetVisualizerControlsTimer() {
  if (visualizerControlsTimer !== null) clearTimeout(visualizerControlsTimer);
  visualizerControlsTimer = setTimeout(() => hideVisualizerControls(), 2500);
}

function updateVisualizerInfo() {
  if (state.activeView !== "visualizer") return;
  const current = getCurrentPlayingItem();
  if (!current) return;

  const title = document.querySelector<HTMLElement>("#visualizer-title");
  if (title) title.textContent = getMediaTitle(current);
  const subtitle = document.querySelector<HTMLElement>("#visualizer-subtitle");
  if (subtitle) subtitle.textContent = getMediaSubtitle(current);

  const meta = metadataCache.get(current.filePath);
  if (meta?.pictureBase64 && meta.pictureBase64 !== visualizerArtSrc) {
    visualizerArtImage = new Image();
    visualizerArtSrc = meta.pictureBase64;
    visualizerArtImage.src = meta.pictureBase64;
  } else if (!meta?.pictureBase64) {
    visualizerArtImage = null;
    visualizerArtSrc = "";
  }
}

function renderView() {
  if (state.activeView === "settings") {
    return renderSettingsView();
  }

  if (state.activeView === "info") {
    return renderInfoView();
  }

  return renderHomeView();
}

function renderHomeView() {
  return `
    <div class="home-layout">
      <section class="collection-surface">
        <div id="collection-root" class="collection-root">
          ${renderGroupedCollection()}
        </div>
      </section>
    </div>
  `;
}

function renderSettingsView() {
  return `
    <section class="panel-view">
      <div class="section-title">
        <h2>Settings</h2>
        <p>Configure local paths and refresh the file index. Everything remains offline.</p>
      </div>

      <div class="settings-grid">
        <article class="setting-card">
          <p class="meta-label">Storage</p>
          <p class="meta-value">Current data directory:</p>
          <p class="meta-value strong" id="data-directory">${escapeHtml(state.dataDirectoryLabel)}</p>
          <button id="pick-data-dir" class="button secondary" type="button">Change Data Directory</button>
        </article>

        <article class="setting-card">
          <p class="meta-label">Audio Library</p>
          <p class="meta-value">Current audio folder:</p>
          <p class="meta-value strong" id="audio-directory">${escapeHtml(state.audioDirectoryLabel)}</p>
          <button id="pick-audio-dir" class="button secondary" type="button">Change Audio Folder</button>
          <button id="refresh-audio" class="button secondary" type="button">Refresh Audio Library</button>
        </article>

        <article class="setting-card">
          <p class="meta-label">Video Library</p>
          <p class="meta-value">Current video folder:</p>
          <p class="meta-value strong" id="video-directory">${escapeHtml(state.videoDirectoryLabel)}</p>
          <button id="pick-video-dir" class="button secondary" type="button">Change Video Folder</button>
          <button id="refresh-video" class="button secondary" type="button">Refresh Video Library</button>
        </article>

        <article class="setting-card">
          <p class="meta-label">Privacy</p>
          <p class="meta-value">Telemetry is disabled. Fumic does not upload analytics or media data.</p>
        </article>
      </div>
    </section>
  `;
}

function renderInfoView() {
  return `
    <section class="panel-view info-page">
      <div class="info-hero">
        <img src="./fumic_logo_trans.svg" alt="Fumic" class="info-hero-logo" />
        <p class="info-tagline">The Magical Media Player <span class="info-tested">(FOSS)</span></p>
        <p class="info-thanks">Thanks for using Fumic! ❤️</p>
      </div>

      <div class="info-section">
        <h3 class="info-section-title">Features</h3>
        <div class="info-features-grid">
          <div class="info-feature-card">
            <span class="info-feature-icon">⌨️</span>
            <span class="info-feature-text">100% Keyboard Control</span>
          </div>
          <div class="info-feature-card">
            <span class="info-feature-icon">🆓</span>
            <span class="info-feature-text">FOSS — Free & Open Source</span>
          </div>
          <div class="info-feature-card">
            <span class="info-feature-icon">📁</span>
            <span class="info-feature-text">Supported formats: .mp3, .mp4, .opus, .wav</span>
          </div>
          <div class="info-feature-card">
            <span class="info-feature-icon">🔒</span>
            <span class="info-feature-text">100% Offline</span>
          </div>
          <div class="info-feature-card">
            <span class="info-feature-icon">💪</span>
            <span class="info-feature-text">Performance Audio & Video Playback</span>
          </div>
          <div class="info-feature-card">
            <span class="info-feature-icon">✨</span>
            <span class="info-feature-text">Minimalistic & Aesthetic Design</span>
          </div>
          <div class="info-feature-card">
            <span class="info-feature-icon">🎛️</span>
            <span class="info-feature-text">Media Controls</span>
          </div>
          <div class="info-feature-card">
            <span class="info-feature-icon">⚡</span>
            <span class="info-feature-text">Fast & Reliable</span>
          </div>
        </div>
      </div>

      <div class="info-section">
        <h3 class="info-section-title">Keyboard Shortcuts</h3>
        <div class="shortcuts-grid">
          <div class="shortcut-entry"><span class="shortcut-key">Space</span><span class="shortcut-desc">Play / Pause</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + Enter</span><span class="shortcut-desc">Play Selected Track</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">← / →</span><span class="shortcut-desc">Seek 5s Back / Forward</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Shift + ← / →</span><span class="shortcut-desc">Seek 10s Back / Forward</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + ← / →</span><span class="shortcut-desc">Previous / Next Track</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + ↑ / ↓</span><span class="shortcut-desc">Volume Up / Down</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + M</span><span class="shortcut-desc">Mute / Unmute</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Shift + S</span><span class="shortcut-desc">Toggle Shuffle</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Shift + L</span><span class="shortcut-desc">Toggle Loop</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Shift + &lt; / &gt;</span><span class="shortcut-desc">Playback Speed Down / Up</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">↑ / ↓</span><span class="shortcut-desc">Navigate Media List</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + K</span><span class="shortcut-desc">Focus Search</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Escape</span><span class="shortcut-desc">Unfocus Search / Exit Player</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + H</span><span class="shortcut-desc">Go to Home</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + S</span><span class="shortcut-desc">Go to Settings</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + I</span><span class="shortcut-desc">Go to Info</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + A</span><span class="shortcut-desc">Switch to Audio Tab</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + V</span><span class="shortcut-desc">Switch to Video Tab</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + F</span><span class="shortcut-desc">Toggle Full Screen Player</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + R</span><span class="shortcut-desc">Refresh Current Library</span></div>
          <div class="shortcut-entry"><span class="shortcut-key">Ctrl + E</span><span class="shortcut-desc">Toggle Audio Visualizer</span></div>
        </div>
      </div>

      <div class="info-section">
        <h3 class="info-section-title">FAQ</h3>
        <div class="faq-list">
          <details class="faq-item">
            <summary class="faq-question">Why Fumic?</summary>
            <div class="faq-answer">
              <p>Because no matter how much you look for, you won't find anything like this on the internet. A truly offline, keyboard-first, no-nonsense media player that just works.</p>
              <p>Even if you do find something close, they will be behind paywalls or loaded with bloat you never asked for.</p>
              <p>So Fumic is a lifesaver for you all. It was built out of genuine frustration and love for clean software.</p>
            </div>
          </details>

          <details class="faq-item">
            <summary class="faq-question">Why FOSS?</summary>
            <div class="faq-answer">
              <p>FOSS means Free Open Source Software. It's not just a license, it's a philosophy.</p>
              <p>Grew up using lots of tools and stuff, and now when I am able to contribute to the community, it's my chance — and so I did. Giving back feels right, and everyone deserves good tools without strings attached.</p>
            </div>
          </details>

          <details class="faq-item">
            <summary class="faq-question">Who is the developer?</summary>
            <div class="faq-answer">
              <p><strong>Legally responsible developer:</strong> TheIdealDev52 aka Saksham Sharma, along with Shelly (AI Agent).</p>
              <p>A solo developer who believes software should be simple, fast, and free. Shelly helped bring the vision to life with precision and speed.</p>
            </div>
          </details>

          <details class="faq-item">
            <summary class="faq-question">How to contribute?</summary>
            <div class="faq-answer">
              <p>You will find this repo at <a href="https://github.com/UnExplainableFish52/Fumic" target="_blank" rel="noopener noreferrer">github.com/UnExplainableFish52/Fumic</a></p>
              <p>Follow the profile to stay updated. Support by giving stars ⭐ — it genuinely helps with visibility and motivation.</p>
              <p>Pull requests, bug reports, and feature suggestions are always welcome. Every bit of contribution counts.</p>
              <p>If you want to support financially, contact at:</p>
              <ul class="faq-contact-list">
                <li><a href="mailto:sharma@saksham.info.np">sharma@saksham.info.np</a></li>
                <li><a href="mailto:contactsaksham52@gmail.com">contactsaksham52@gmail.com</a></li>
                <li><a href="mailto:info@sakshamsharma.com.np">info@sakshamsharma.com.np</a></li>
              </ul>
            </div>
          </details>

          <details class="faq-item">
            <summary class="faq-question">What license?</summary>
            <div class="faq-answer">
              <p><strong>GNU General Public License v3.0</strong></p>
              <p>In simple terms, this means:</p>
              <ul>
                <li>Feel free to use</li>
                <li>Feel free to modify</li>
                <li>Feel free to share</li>
                <li>Never allowed to redistribute as proprietary — always must stay FOSS</li>
              </ul>
              <p>The whole point is to keep it open forever. No one should lock this down behind a paywall.</p>
            </div>
          </details>

          <details class="faq-item">
            <summary class="faq-question">Where to give feedback?</summary>
            <div class="faq-answer">
              <p>In the GitHub repo as <a href="https://github.com/UnExplainableFish52/Fumic/issues" target="_blank" rel="noopener noreferrer">Issues</a> — whether it's a bug, a suggestion, or just a thought, open an issue and it will be looked at.</p>
              <p>You can also send feedback at the email addresses mentioned above.</p>
              <p>Or find the contact form at: <a href="https://sakshamsharma.com.np/#contact" target="_blank" rel="noopener noreferrer">sakshamsharma.com.np/#contact</a></p>
              <p>Honestly, any feedback is appreciated. It helps shape Fumic into something even better.</p>
            </div>
          </details>
        </div>
      </div>
    </section>
  `;
}

function renderGroupedCollection() {
  const entries = getFilteredRows();

  if (entries.length === 0) {
    return '<p class="empty-state">No matching files found in the selected media folder.</p>';
  }

  /* Sort alphabetically by fileName (case-insensitive) */
  entries.sort((a, b) =>
    a.item.fileName.localeCompare(b.item.fileName, undefined, { sensitivity: "base" })
  );

  const groups = new Map<string, IndexedMediaItem[]>();

  for (const entry of entries) {
    const first = entry.item.fileName.charAt(0).toUpperCase();
    const key = /[A-Z]/.test(first) ? first : "#";
    const bucket = groups.get(key);

    if (bucket) {
      bucket.push(entry);
    } else {
      groups.set(key, [entry]);
    }
  }

  return Array.from(groups.entries())
    .map(([letter, groupEntries]) => {
      const cards = groupEntries
        .map((entry) => {
          const isSelected = entry.index === state.selectedIndex;
          const isNowPlaying = entry.item.id === currentPlayingItemId;
            let thumbStyle = `style="--thumb-hue: ${hueFromName(entry.item.fileName)};"`;
            const meta = metadataCache.get(entry.item.filePath);
            if (meta?.pictureBase64) {
              thumbStyle = `style="background-image: url('${meta.pictureBase64}'); background-size: cover; background-position: center; box-shadow: none;"`;
            }
            return `
              <button class="media-card ${isSelected ? "selected" : ""} ${isNowPlaying ? "playing" : ""}" type="button" data-row-index="${entry.index}">
                <span class="media-thumb" ${thumbStyle}></span>
                <span class="media-body">
                  <span class="media-title">${escapeHtml(getMediaTitle(entry.item))}</span>
                  <span class="media-subtitle">${escapeHtml(getMediaSubtitle(entry.item))}</span>
                  <span class="media-duration">${escapeHtml(getDurationLabel(entry.item))}</span>
                </span>
              </button>
            `;
          })
          .join("");

        return `
          <section class="alpha-group">
            <h3>${letter}</h3>
            <div class="media-grid">${cards}</div>
          </section>
        `;
      })
      .join("");
}

function wireUiEvents() {
  document.addEventListener("keydown", handleKeyboard);

  appRoot.addEventListener("click", (event) => {
    const target = event.target as HTMLElement;
    const button = target.closest<HTMLButtonElement>("button");

    if (!button) {
      return;
    }

    if (button.id === "nav-home") {
      switchView("home");
      return;
    }

    if (button.id === "cinema-close") {
      switchView("home");
      return;
    }

    if (button.id === "visualizer-close") {
      switchView("home");
      return;
    }

    if (button.id === "nav-settings") {
      switchView("settings");
      return;
    }

    if (button.id === "nav-info") {
      switchView("info");
      return;
    }

    if (button.id === "tab-audio") {
      switchTab("audio");
      return;
    }

    if (button.id === "tab-video") {
      switchTab("video");
      return;
    }

    if (button.id === "toggle-play") {
      void togglePlayPause();
      return;
    }

    if (button.id === "transport-prev") {
      void playPrevious();
      return;
    }

    if (button.id === "transport-next") {
      void playNext();
      return;
    }

    if (button.id === "cycle-repeat") {
      cycleRepeatMode();
      return;
    }

    if (button.id === "toggle-shuffle") {
      toggleShuffle();
      return;
    }

    if (button.id === "pick-data-dir") {
      void selectDataDirectory();
      return;
    }

    if (button.id === "pick-audio-dir") {
      void selectAudioDirectory();
      return;
    }

    if (button.id === "pick-video-dir") {
      void selectVideoDirectory();
      return;
    }

    if (button.id === "refresh-audio") {
      void refreshAudioLibrary("Audio library refreshed.");
      return;
    }

    if (button.id === "refresh-video") {
      void refreshVideoLibrary("Video library refreshed.");
      return;
    }

    if (button.id === "manual-refresh") {
      if (state.activeTab === "audio") {
        void refreshAudioLibrary("Audio library refreshed.");
      } else {
        void refreshVideoLibrary("Video library refreshed.");
      }
      return;
    }

    if (button.id === "toggle-player-mode") {
      const currentItem = getCurrentPlayingItem();
      if (currentItem?.kind === "video") {
        switchView(state.activeView === "cinema" ? "home" : "cinema");
      } else {
        switchView(state.activeView === "player" ? "home" : "player");
      }
      return;
    }

    const index = Number(button.dataset.rowIndex);
    if (!Number.isNaN(index)) {
      state.selectedIndex = index;
      updateSelectionUI();
      setActionLog(`Highlighted ${getSelectedRowName() ?? "item"}.`);
    }
  });

  appRoot.addEventListener("dblclick", (event) => {
    const target = event.target as HTMLElement;
    const button = target.closest<HTMLButtonElement>("button.media-card");
    if (button) {
      const index = Number(button.dataset.rowIndex);
      if (!Number.isNaN(index)) {
        state.selectedIndex = index;
        void playSelectedItem();
        updateSelectionUI();
      }
    }
  });

  appRoot.addEventListener("input", (event) => {
    const target = event.target as HTMLInputElement;
    if (target.id === "global-search") {
      state.searchQuery = target.value;
      state.selectedIndex = 0;

      if (state.activeView !== "home") {
        state.activeView = "home";
        renderShell();
      }

      updateCollectionOnly();
    }
  });

  /* --- Progress bar click-to-seek --- */
  appRoot.addEventListener("click", (event) => {
    const progressTrack = (event.target as HTMLElement).closest("#progress-bar-track");
    if (progressTrack) {
      const player = getActivePlayer();
      if (player && Number.isFinite(player.duration)) {
        const rect = (progressTrack as HTMLElement).getBoundingClientRect();
        const clickX = (event as MouseEvent).clientX - rect.left;
        const ratio = Math.max(0, Math.min(1, clickX / rect.width));
        player.currentTime = ratio * player.duration;
        updateProgressBar();
      }
    }
  });
}

function wireMediaEvents() {
  audioPlayer.addEventListener("loadedmetadata", () => {
    const item = getCurrentPlayingItem();
    if (
      item &&
      Number.isFinite(audioPlayer.duration) &&
      audioPlayer.duration > 0
    ) {
      durationCache.set(item.filePath, audioPlayer.duration);
      updateDurationForItem(item);
    }
    syncTransportState();
    updateProgressBar();
  });

  videoPlayer.addEventListener("loadedmetadata", () => {
    const item = getCurrentPlayingItem();
    if (
      item &&
      Number.isFinite(videoPlayer.duration) &&
      videoPlayer.duration > 0
    ) {
      durationCache.set(item.filePath, videoPlayer.duration);
      updateDurationForItem(item);
    }
    syncTransportState();
    updateProgressBar();
  });

  audioPlayer.addEventListener("timeupdate", () => updateProgressBar());
  videoPlayer.addEventListener("timeupdate", () => updateProgressBar());

  audioPlayer.addEventListener("play", () => {
    state.playerMode = "playing";
    syncTransportState();
  });

  videoPlayer.addEventListener("play", () => {
    state.playerMode = "playing";
    syncTransportState();
  });

  audioPlayer.addEventListener("pause", () => {
    state.playerMode = "paused";
    syncTransportState();
  });

  videoPlayer.addEventListener("pause", () => {
    state.playerMode = "paused";
    syncTransportState();
  });

  audioPlayer.addEventListener("ended", () => {
    void handleTrackEnded();
  });

  videoPlayer.addEventListener("ended", () => {
    void handleTrackEnded();
  });
}

async function initializeApp() {
  disposeMainMessageListener = window.appApi.onMainMessage((message) => {
    setActionLog(message);
  });

  bootstrap = await window.appApi.getBootstrap();
  state.dataDirectoryLabel = bootstrap.dataDirectory;
  state.audioDirectoryLabel = bootstrap.audioDirectory;
  state.videoDirectoryLabel = bootstrap.videoDirectory;
  /* Only scan audio on launch; video scans lazily when the user switches tabs */
  await refreshAudioLibrary("Audio library indexed.");
}

function switchView(view: AppView) {
  if (state.activeView === view) {
    return;
  }

  /* Clean up cinema mode resources when leaving */
  if (state.activeView === "cinema") {
    cleanupCinemaMode();
  }

  if (state.activeView === "visualizer") {
    cleanupVisualizer();
  }

  state.activeView = view;
  renderShell();
  setActionLog(`Switched to ${view} view.`);
}

function switchTab(tab: LibraryTab) {
  if (state.activeTab === tab && state.activeView === "home") {
    return;
  }

  state.activeTab = tab;
  state.activeView = "home";
  state.selectedIndex = 0;

  /* Lazy-scan video library on first access */
  if (tab === "video" && !videoLibraryScanned) {
    void refreshVideoLibrary("Video library indexed.");
  } else {
    renderShell();
  }

  setActionLog(`Switched to ${tab} tab.`);
}

async function refreshAudioLibrary(successMessage: string) {
  setActionLog("Scanning audio library...");

  try {
    const snapshot = await window.appApi.scanAudioLibrary();
    mediaRows.audio = snapshot.items;
    state.audioDirectoryLabel = snapshot.rootDirectory;
    normalizeSelectedIndex();
    renderShell();
    syncTransportState();
    setActionLog(successMessage);
  } catch {
    setActionLog(
      "Audio library scan failed. Please check folder permissions and try again.",
    );
  }
}

async function refreshVideoLibrary(successMessage: string) {
  setActionLog("Scanning video library...");

  try {
    const snapshot = await window.appApi.scanVideoLibrary();
    mediaRows.video = snapshot.items;
    state.videoDirectoryLabel = snapshot.rootDirectory;
    videoLibraryScanned = true;
    normalizeSelectedIndex();
    renderShell();
    syncTransportState();
    setActionLog(successMessage);
  } catch {
    setActionLog(
      "Video library scan failed. Please check folder permissions and try again.",
    );
  }
}

async function togglePlayPause() {
  const activePlayer = getActivePlayer();

  if (activePlayer && currentPlayingItemId) {
    if (activePlayer.paused) {
      await activePlayer.play();
    } else {
      activePlayer.pause();
    }
    return;
  }

  await playSelectedItem();
}

function cycleRepeatMode() {
  const order: RepeatMode[] = ["all", "one", "off"];
  const currentIndex = order.indexOf(state.repeatMode);
  state.repeatMode = order[(currentIndex + 1) % order.length];
  syncTransportState();
  setActionLog(`Repeat mode is now ${state.repeatMode}.`);
}

function toggleShuffle() {
  state.shuffleEnabled = !state.shuffleEnabled;
  syncTransportState();
  setActionLog(`Shuffle is now ${state.shuffleEnabled ? "on" : "off"}.`);
}

function toggleMute() {
  if (state.volume > 0) {
    preMuteVolume = state.volume;
    state.volume = 0;
    setActionLog("Muted.");
  } else {
    state.volume = preMuteVolume ?? 70;
    preMuteVolume = null;
    setActionLog(`Unmuted. Volume set to ${state.volume}%.`);
  }
  applyVolumeToPlayers();
  syncTransportState();
}

async function selectDataDirectory() {
  const pickedPath = await window.appApi.pickDataDirectory();
  if (!pickedPath) {
    setActionLog("Data directory selection canceled.");
    return;
  }

  state.dataDirectoryLabel = pickedPath;
  const dataDirectoryEl =
    document.querySelector<HTMLElement>("#data-directory");
  if (dataDirectoryEl) {
    dataDirectoryEl.textContent = pickedPath;
  }

  setActionLog("Data directory updated.");
}

async function selectAudioDirectory() {
  const pickedPath = await window.appApi.pickAudioDirectory();
  if (!pickedPath) {
    setActionLog("Audio folder selection canceled.");
    return;
  }

  state.audioDirectoryLabel = pickedPath;
  await refreshAudioLibrary("Audio folder updated and indexed.");
}

async function selectVideoDirectory() {
  const pickedPath = await window.appApi.pickVideoDirectory();
  if (!pickedPath) {
    setActionLog("Video folder selection canceled.");
    return;
  }

  state.videoDirectoryLabel = pickedPath;
  await refreshVideoLibrary("Video folder updated and indexed.");
}

function updateCollectionOnly() {
  normalizeSelectedIndex();

  const collectionRoot = document.querySelector<HTMLElement>("#collection-root");
  if (collectionRoot) {
    collectionRoot.innerHTML = renderGroupedCollection();
  }

  updateSelectionUI();
  primeVisibleDurations();
}

function updateSelectionUI() {
  const collectionRoot = document.querySelector<HTMLElement>("#collection-root");
  if (collectionRoot) {
    const buttons = collectionRoot.querySelectorAll<HTMLButtonElement>(".media-card");
    for (const btn of Array.from(buttons)) {
      const rowIndex = parseInt(btn.dataset.rowIndex ?? "-1", 10);
      if (rowIndex === state.selectedIndex) {
        btn.classList.add("selected");
        btn.scrollIntoView({ block: "nearest", behavior: "smooth" });
      } else {
        btn.classList.remove("selected");
      }
    }
  }
  syncTransportState();
}

/** Lightweight update: only toggle .selected / .playing CSS classes without rebuilding DOM */
function updatePlayingIndicator() {
  const collectionRoot = document.querySelector<HTMLElement>("#collection-root");
  if (!collectionRoot) return;

  const cards = collectionRoot.querySelectorAll<HTMLButtonElement>(".media-card");
  for (const btn of Array.from(cards)) {
    const rowIndex = parseInt(btn.dataset.rowIndex ?? "-1", 10);
    const item = mediaRows[state.activeTab][rowIndex];
    btn.classList.toggle("playing", !!item && item.id === currentPlayingItemId);
    btn.classList.toggle("selected", rowIndex === state.selectedIndex);
  }
  syncTransportState();
}

/** Update only the duration label for a specific item's card without rebuilding the collection */
function updateDurationForItem(item: MediaLibraryItem) {
  const collectionRoot = document.querySelector<HTMLElement>("#collection-root");
  if (!collectionRoot) return;

  const allRows = mediaRows[state.activeTab];
  const rowIndex = allRows.indexOf(item);
  if (rowIndex < 0) return;

  const card = collectionRoot.querySelector<HTMLElement>(`.media-card[data-row-index="${rowIndex}"]`);
  if (!card) return;

  const durationEl = card.querySelector<HTMLElement>(".media-duration");
  if (durationEl) durationEl.textContent = getDurationLabel(item);
}

function syncTransportState() {
  const volumeLabel = document.querySelector<HTMLElement>("#volume-label");
  const volumeFill = document.querySelector<HTMLElement>(".volume-fill");
  const playButton = document.querySelector<HTMLButtonElement>("#toggle-play");
  const repeatButton =
    document.querySelector<HTMLButtonElement>("#cycle-repeat");
  const shuffleButton =
    document.querySelector<HTMLButtonElement>("#toggle-shuffle");
  const nowPlayingTitle =
    document.querySelector<HTMLElement>("#now-playing-title");
  const nowPlayingMeta =
    document.querySelector<HTMLElement>("#now-playing-meta");

  if (volumeLabel) {
    volumeLabel.textContent = `${state.volume}%`;
  }
  if (volumeFill) {
    volumeFill.style.width = `${state.volume}%`;
  }
  if (playButton) {
    playButton.innerHTML = state.playerMode === "playing" ? ICON.pause : ICON.play;
  }
  if (repeatButton) {
    repeatButton.classList.toggle("active", state.repeatMode !== "off");
    repeatButton.setAttribute("data-repeat", state.repeatMode);
    repeatButton.title = `Repeat: ${state.repeatMode}`;
  }
  if (shuffleButton) {
    shuffleButton.classList.toggle("active", state.shuffleEnabled);
  }
  if (nowPlayingTitle) {
    nowPlayingTitle.textContent = getNowPlayingName() ?? "None";
  }
  if (nowPlayingMeta) {
    nowPlayingMeta.textContent = getNowPlayingMeta();
  }

  /* Update now-playing thumbnail */
  const nowPlayingThumb = document.querySelector<HTMLElement>(".now-playing-thumb");
  if (nowPlayingThumb) {
    const current = getCurrentPlayingItem();
    const meta = current ? metadataCache.get(current.filePath) : null;
    if (meta?.pictureBase64) {
      nowPlayingThumb.style.backgroundImage = `url('${meta.pictureBase64}')`;
    } else {
      nowPlayingThumb.style.backgroundImage = '';
    }
  }

  /* Update speed label */
  const speedLabel = document.querySelector<HTMLElement>("#speed-label");
  if (speedLabel) {
    speedLabel.textContent = state.playbackSpeed === 1.0 ? "" : state.playbackSpeed.toFixed(2) + "x";
  }
}

function setActionLog(text: string) {
  state.actionLog = text;
  const actionLog = document.querySelector<HTMLElement>("#action-log");
  if (actionLog) {
    actionLog.textContent = text;
  }
}

/** Update the progress bar, current time, and duration labels without rebuilding the DOM */
function updateProgressBar() {
  const player = getActivePlayer();
  const progressFill = document.querySelector<HTMLElement>("#transport-progress");
  const currentTimeEl = document.querySelector<HTMLElement>("#progress-current");
  const durationEl = document.querySelector<HTMLElement>("#progress-duration");

  if (!player || !Number.isFinite(player.duration) || player.duration === 0) {
    if (progressFill) progressFill.style.width = "0%";
    if (currentTimeEl) currentTimeEl.textContent = "0:00";
    if (durationEl) durationEl.textContent = "0:00";
    return;
  }

  const percent = (player.currentTime / player.duration) * 100;
  if (progressFill) progressFill.style.width = `${percent}%`;
  if (currentTimeEl) currentTimeEl.textContent = formatDuration(player.currentTime);
  if (durationEl) durationEl.textContent = formatDuration(player.duration);
}

/** Update the fullscreen player view elements with targeted DOM updates */
function updatePlayerView() {
  if (state.activeView !== "player") return;

  const current = getCurrentPlayingItem();
  if (!current) return;

  const meta = metadataCache.get(current.filePath);
  const isVideo = current.kind === "video";

  /* Check if we need to swap between audio art and video mount */
  const hasVideoMount = !!document.querySelector("#fs-video-mount");
  const hasArt = !!document.querySelector(".fs-art");

  if ((isVideo && !hasVideoMount) || (!isVideo && !hasArt)) {
    /* Mode switched (audio↔video) — must re-render the player center */
    const playerCenter = document.querySelector<HTMLElement>(".player-center");
    if (playerCenter) {
      playerCenter.innerHTML = renderPlayerCenter();
    }
    /* Mount video element if needed */
    if (isVideo) {
      const videoMount = document.querySelector<HTMLElement>("#fs-video-mount");
      if (videoMount) {
        videoPlayer.style.width = "100%";
        videoPlayer.style.maxHeight = "70vh";
        videoPlayer.style.borderRadius = "12px";
        videoPlayer.style.objectFit = "contain";
        videoMount.appendChild(videoPlayer);
      }
    }
  } else {
    /* Same mode — just update content in place */
    if (!isVideo) {
      const fsArt = document.querySelector<HTMLElement>(".fs-art");
      if (fsArt) {
        fsArt.style.backgroundImage = meta?.pictureBase64 ? `url('${meta.pictureBase64}')` : '';
      }
    }
  }

  /* Update text */
  const fsTitle = document.querySelector<HTMLElement>(".fs-title");
  if (fsTitle) fsTitle.textContent = getMediaTitle(current);
  const fsSubtitle = document.querySelector<HTMLElement>(".fs-subtitle");
  if (fsSubtitle) fsSubtitle.textContent = getMediaSubtitle(current);
  const fsDuration = document.querySelector<HTMLElement>(".fs-duration");
  if (fsDuration) fsDuration.textContent = getDurationLabel(current);

  /* Update backdrop */
  const backdrop = document.querySelector<HTMLElement>(".player-backdrop");
  if (backdrop) {
    backdrop.style.backgroundImage = meta?.pictureBase64 ? `url('${meta.pictureBase64}')` : '';
  }
}

function handleKeyboard(event: KeyboardEvent) {
  const target = event.target as HTMLElement | null;
  const isTextInputFocused =
    target?.tagName === "INPUT" || target?.tagName === "TEXTAREA";

  /* ── Cinema/Visualizer mode: any key shows controls ── */
  if (state.activeView === "cinema") {
    handleCinemaActivity();
  }
  if (state.activeView === "visualizer") {
    handleVisualizerActivity();
  }

  if (event.ctrlKey && event.key.toLowerCase() === "h") {
    event.preventDefault();
    switchView("home");
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "i") {
    event.preventDefault();
    switchView("info");
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "s") {
    event.preventDefault();
    switchView("settings");
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "a") {
    event.preventDefault();
    switchTab("audio");
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "v") {
    event.preventDefault();
    switchTab("video");
    return;
  }

  /* ── Ctrl + R  →  Refresh current tab's library ── */
  if (event.ctrlKey && event.key.toLowerCase() === "r") {
    event.preventDefault();
    if (state.activeTab === "audio") {
      void refreshAudioLibrary("Audio library refreshed.");
    } else {
      void refreshVideoLibrary("Video library refreshed.");
    }
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "k") {
    event.preventDefault();

    if (state.activeView !== "home") {
      state.activeView = "home";
      renderShell();
    }

    const input = document.querySelector<HTMLInputElement>("#global-search");
    input?.focus();
    input?.select();
    setActionLog("Focused search input.");
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "f") {
    event.preventDefault();
    const currentItem = getCurrentPlayingItem();
    if (currentItem?.kind === "video") {
      /* Video: toggle cinema mode */
      if (state.activeView !== "cinema") {
        switchView("cinema");
      } else {
        switchView("home");
      }
    } else {
      /* Audio: toggle fullscreen player */
      if (state.activeView !== "player") {
        switchView("player");
      } else {
        switchView("home");
      }
    }
    return;
  }

  /* ── Ctrl + E  →  Toggle Audio Visualizer ── */
  if (event.ctrlKey && event.key.toLowerCase() === "e") {
    event.preventDefault();
    if (state.activeView !== "visualizer") {
      switchView("visualizer");
    } else {
      switchView("home");
    }
    return;
  }

  /* ── Ctrl + M  →  Toggle mute / unmute ── */
  if (event.ctrlKey && event.key.toLowerCase() === "m") {
    event.preventDefault();
    toggleMute();
    return;
  }

  if (event.key === "Escape" && (state.activeView === "player" || state.activeView === "cinema" || state.activeView === "visualizer")) {
    event.preventDefault();
    switchView("home");
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "b") {
    event.preventDefault();
    setActionLog(`Added ${getSelectedRowName() ?? "item"} to Liked Music.`);
    return;
  }

  if (event.ctrlKey && event.key.toLowerCase() === "p") {
    event.preventDefault();
    setActionLog("Ctrl + P captured for user playlist target flow.");
    return;
  }

  if (event.ctrlKey && event.key === "ArrowUp") {
    event.preventDefault();
    state.volume = Math.min(100, state.volume + 5);
    applyVolumeToPlayers();
    syncTransportState();
    setActionLog(`Volume set to ${state.volume}%.`);
    return;
  }

  if (event.ctrlKey && event.key === "ArrowDown") {
    event.preventDefault();
    state.volume = Math.max(0, state.volume - 5);
    applyVolumeToPlayers();
    syncTransportState();
    setActionLog(`Volume set to ${state.volume}%.`);
    return;
  }

  if (event.ctrlKey && event.key === "ArrowRight") {
    event.preventDefault();
    void playNext();
    return;
  }

  if (event.ctrlKey && event.key === "ArrowLeft") {
    event.preventDefault();
    void playPrevious();
    return;
  }

  if (event.ctrlKey && event.key === "Enter") {
    event.preventDefault();
    void playSelectedItem();
    return;
  }

  if (isTextInputFocused) {
    if (event.key === "Escape") {
      event.preventDefault();
      (target as HTMLElement)?.blur();
      setActionLog("Search unfocused.");
    }
    return;
  }

  /* ── Shift + S  →  Toggle Shuffle (homepage focus) ── */
  if (event.shiftKey && event.key === "S") {
    event.preventDefault();
    toggleShuffle();
    return;
  }

  /* ── Shift + L  →  Toggle Loop / Repeat (homepage focus) ── */
  if (event.shiftKey && event.key === "L") {
    event.preventDefault();
    cycleRepeatMode();
    return;
  }

  if (event.code === "Space") {
    event.preventDefault();
    void togglePlayPause();
    return;
  }

  if (event.key === "ArrowUp") {
    event.preventDefault();
    moveSelection(-1);
    return;
  }

  if (event.key === "ArrowDown") {
    event.preventDefault();
    moveSelection(1);
    return;
  }

  if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
    event.preventDefault();
    const seekStep = event.shiftKey ? 10 : 5;
    seekBySeconds(event.key === "ArrowRight" ? seekStep : -seekStep);
    return;
  }

  if (event.key === "<" || event.key === ",") {
    if (event.shiftKey) {
      event.preventDefault();
      cyclePlaybackSpeed(-1);
      return;
    }
  }

  if (event.key === ">" || event.key === ".") {
    if (event.shiftKey) {
      event.preventDefault();
      cyclePlaybackSpeed(1);
      return;
    }
  }
}

function moveSelection(delta: number) {
  if (state.activeView !== "home") {
    state.activeView = "home";
    renderShell();
  }

  const rows = getFilteredRows();
  if (rows.length === 0) {
    state.selectedIndex = 0;
    updateSelectionUI();
    return;
  }

  const next = state.selectedIndex + delta;
  state.selectedIndex = Math.max(0, Math.min(rows.length - 1, next));
  updateSelectionUI();
}

function getFilteredRows() {
  const rows = mediaRows[state.activeTab];
  const normalizedQuery = state.searchQuery.trim().toLowerCase();

  if (!normalizedQuery) {
    return rows.map((item, index) => ({ item, index }));
  }

  return rows
    .map((item, index) => ({ item, index }))
    .filter((entry) =>
      entry.item.fileName.toLowerCase().includes(normalizedQuery),
    );
}

function normalizeSelectedIndex() {
  const rows = getFilteredRows();

  if (rows.length === 0) {
    state.selectedIndex = 0;
    return;
  }

  if (state.selectedIndex > rows.length - 1) {
    state.selectedIndex = rows.length - 1;
  }

  if (state.selectedIndex < 0) {
    state.selectedIndex = 0;
  }
}

function getSelectedRow() {
  const rows = getFilteredRows();
  return rows[state.selectedIndex]?.item ?? null;
}

function getCurrentPlayingItem() {
  if (!currentPlayingItemId) {
    return null;
  }

  return (
    mediaRows.audio.find((item) => item.id === currentPlayingItemId) ??
    mediaRows.video.find((item) => item.id === currentPlayingItemId) ??
    null
  );
}

function getSelectedRowName() {
  return getSelectedRow()?.fileName ?? null;
}

function getNowPlayingName() {
  const current = getCurrentPlayingItem();
  return current ? getMediaTitle(current) : null;
}

function getNowPlayingMeta() {
  const current = getCurrentPlayingItem();
  if (!current) {
    return "Select media and press Play.";
  }

  return `${getMediaSubtitle(current)} - ${getDurationLabel(current)}`;
}

function getMediaTitle(item: MediaLibraryItem) {
  const meta = metadataCache.get(item.filePath);
  if (meta?.title) {
    return meta.title;
  }
  return item.fileName;
}

function getMediaSubtitle(item: MediaLibraryItem) {
  const meta = metadataCache.get(item.filePath);
  if (meta?.artist) {
    return meta.artist;
  }
  return item.kind.toUpperCase();
}

function applyThumbnail(element: HTMLElement, item: MediaLibraryItem) {
  const meta = metadataCache.get(item.filePath);
  if (meta?.pictureBase64) {
    element.style.backgroundImage = `url("${meta.pictureBase64}")`;
    element.style.backgroundSize = 'cover';
    element.style.backgroundPosition = 'center';
    element.style.boxShadow = 'none';
  } else {
    element.style.backgroundImage = '';
    element.style.setProperty('--thumb-hue', String(hueFromName(item.fileName)));
  }
}

function getDurationLabel(item: MediaLibraryItem) {
  const cached = durationCache.get(item.filePath);
  if (!cached) {
    return "Loading duration...";
  }

  return formatDuration(cached);
}

function primeVisibleDurations() {
  /* Use IntersectionObserver to lazily load metadata as cards scroll into view */
  const collectionRoot = document.querySelector<HTMLElement>("#collection-root");
  if (!collectionRoot) return;

  /* Disconnect previous observer to prevent leaks */
  if (metadataObserver) {
    metadataObserver.disconnect();
    metadataObserver = null;
  }

  metadataObserver = new IntersectionObserver(
    (observerEntries) => {
      for (const obsEntry of observerEntries) {
        if (!obsEntry.isIntersecting) continue;
        metadataObserver?.unobserve(obsEntry.target);

        const card = obsEntry.target as HTMLElement;
        const rowIndex = parseInt(card.dataset.rowIndex ?? "-1", 10);
        const rows = getFilteredRows();
        const match = rows.find((r) => r.index === rowIndex);
        if (!match) continue;

        if (!metadataCache.has(match.item.filePath) && !metadataRequests.has(match.item.filePath)) {
          void ensureMetadata(match.item).then(() => {
            const durationEl = card.querySelector('.media-duration');
            if (durationEl) durationEl.textContent = getDurationLabel(match.item);
            const titleEl = card.querySelector('.media-title');
            if (titleEl) titleEl.textContent = getMediaTitle(match.item);
            const subtitleEl = card.querySelector('.media-subtitle');
            if (subtitleEl) subtitleEl.textContent = getMediaSubtitle(match.item);
            const thumbEl = card.querySelector<HTMLElement>('.media-thumb');
            if (thumbEl) applyThumbnail(thumbEl, match.item);
          });
        }
      }
    },
    { root: null, rootMargin: "200px", threshold: 0 }
  );

  const cards = collectionRoot.querySelectorAll<HTMLElement>(".media-card");
  for (const card of Array.from(cards)) {
    metadataObserver.observe(card);
  }
}

async function ensureMetadata(
  item: MediaLibraryItem,
): Promise<MediaMetadata | null> {
  if (metadataCache.has(item.filePath)) {
    return metadataCache.get(item.filePath) ?? null;
  }

  const existing = metadataRequests.get(item.filePath);
  if (existing) {
    return existing;
  }

  const request = window.appApi.getMediaMetadata(item.filePath).then((metadata) => {
    metadataRequests.delete(item.filePath);

    if (metadata && (metadata.title || metadata.artist || metadata.duration || metadata.pictureBase64)) {
      if (metadata.duration && metadata.duration > 0) {
        durationCache.set(item.filePath, metadata.duration);
      }
      metadataCache.set(item.filePath, metadata);
    }
    
    // Only update sync transport state if this is the currently playing item
    if (currentPlayingItemId === item.id) {
       syncTransportState()
    }
    
    return metadata;
  }).catch(() => {
    metadataRequests.delete(item.filePath);
    return null;
  });

  metadataRequests.set(item.filePath, request);
  const result = await request;
  return result;
}

async function playSelectedItem() {
  const selected = getSelectedRow();
  if (!selected) {
    setActionLog("No media item selected.");
    return;
  }

  await playMediaItem(selected);
}

async function playMediaItem(item: MediaLibraryItem) {
  const src = toFileUrl(item.filePath);

  audioPlayer.pause();
  videoPlayer.pause();

  try {
    if (item.kind === "audio") {
      videoPlayer.removeAttribute("src");
      videoPlayer.load();
      audioPlayer.src = src;
      await audioPlayer.play();
    } else {
      audioPlayer.removeAttribute("src");
      audioPlayer.load();
      videoPlayer.src = src;
      await videoPlayer.play();
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    setActionLog(`Playback failed: ${msg}`);
    console.error("Playback failed:", err);
    return;
  }

  currentPlayingItemId = item.id;
  state.playerMode = "playing";
  await ensureMetadata(item);

  if (item.kind === "video") {
    /* Auto-switch to cinema mode so the video is visible */
    if (state.activeView !== "cinema") {
      state.activeView = "cinema";
      renderShell();
    } else {
      /* Already in cinema — just update the info overlay */
      updateCinemaInfo();
      syncTransportState();
    }
  } else {
    syncTransportState();
    updatePlayerView();
    updatePlayingIndicator();
    updateVisualizerInfo();
  }

  setActionLog(`Playing ${item.fileName}.`);
}

function getActivePlayer() {
  const current = getCurrentPlayingItem();
  if (!current) {
    return null;
  }

  return current.kind === "audio" ? audioPlayer : videoPlayer;
}

function seekBySeconds(deltaSeconds: number) {
  const player = getActivePlayer();
  if (!player || !Number.isFinite(player.duration)) {
    return;
  }

  const next = Math.max(
    0,
    Math.min(player.duration, player.currentTime + deltaSeconds),
  );
  player.currentTime = next;
  const direction = deltaSeconds >= 0 ? "forward" : "backward";
  setActionLog(`Seeked ${direction} ${Math.abs(deltaSeconds)}s.`);
}

async function playNext() {
  const current = getCurrentPlayingItem() ?? getSelectedRow();
  const queueTab: LibraryTab = current?.kind ?? state.activeTab;
  const queue = mediaRows[queueTab];

  if (queue.length === 0) {
    setActionLog("No media available in this tab.");
    return;
  }

  const currentIndex = current
    ? queue.findIndex((item) => item.id === current.id)
    : -1;
  const nextIndex = resolveNextIndex(queue.length, currentIndex);
  await playByIndex(queueTab, nextIndex);
}

async function playPrevious() {
  const current = getCurrentPlayingItem() ?? getSelectedRow();
  const queueTab: LibraryTab = current?.kind ?? state.activeTab;
  const queue = mediaRows[queueTab];

  if (queue.length === 0) {
    setActionLog("No media available in this tab.");
    return;
  }

  const currentIndex = current
    ? queue.findIndex((item) => item.id === current.id)
    : -1;
  const previousIndex = resolvePreviousIndex(queue.length, currentIndex);
  await playByIndex(queueTab, previousIndex);
}

async function playByIndex(tab: LibraryTab, index: number) {
  const queue = mediaRows[tab];
  const item = queue[index];
  if (!item) {
    return;
  }

  state.activeTab = tab;
  state.selectedIndex = index;
  state.searchQuery = "";

  if (state.activeView !== "home" && state.activeView !== "player" && state.activeView !== "cinema" && state.activeView !== "visualizer") {
    state.activeView = "home";
    renderShell();
  } else if (state.activeView !== "cinema" && state.activeView !== "visualizer") {
    updatePlayingIndicator();
  }

  await playMediaItem(item);
}

async function handleTrackEnded() {
  if (state.repeatMode === "one") {
    const current = getCurrentPlayingItem();
    if (current) {
      await playMediaItem(current);
    }
    return;
  }

  const current = getCurrentPlayingItem();
  if (!current) {
    state.playerMode = "paused";
    syncTransportState();
    return;
  }

  const queue = mediaRows[current.kind];
  const currentIndex = queue.findIndex((item) => item.id === current.id);

  if (currentIndex < 0) {
    state.playerMode = "paused";
    syncTransportState();
    return;
  }

  if (
    currentIndex === queue.length - 1 &&
    state.repeatMode === "off" &&
    !state.shuffleEnabled
  ) {
    state.playerMode = "paused";
    syncTransportState();
    return;
  }

  const nextIndex = resolveNextIndex(queue.length, currentIndex);
  await playByIndex(current.kind, nextIndex);
}

function resolveNextIndex(total: number, currentIndex: number) {
  if (state.shuffleEnabled) {
    if (total === 1) {
      return 0;
    }

    let next = Math.floor(Math.random() * total);
    while (next === currentIndex) {
      next = Math.floor(Math.random() * total);
    }
    return next;
  }

  if (currentIndex < 0 || currentIndex >= total - 1) {
    return 0;
  }

  return currentIndex + 1;
}

function resolvePreviousIndex(total: number, currentIndex: number) {
  if (state.shuffleEnabled) {
    if (total === 1) {
      return 0;
    }

    let previous = Math.floor(Math.random() * total);
    while (previous === currentIndex) {
      previous = Math.floor(Math.random() * total);
    }
    return previous;
  }

  if (currentIndex <= 0) {
    return total - 1;
  }

  return currentIndex - 1;
}

function applyVolumeToPlayers() {
  const level = state.volume / 100;
  audioPlayer.volume = level;
  videoPlayer.volume = level;
}

function cyclePlaybackSpeed(direction: 1 | -1) {
  const currentIdx = SPEED_STEPS.indexOf(state.playbackSpeed);
  let nextIdx: number;

  if (currentIdx < 0) {
    // Current speed isn't in the list; snap to nearest
    nextIdx = SPEED_STEPS.findIndex((s) => s >= state.playbackSpeed);
    if (nextIdx < 0) nextIdx = SPEED_STEPS.length - 1;
  } else {
    nextIdx = currentIdx + direction;
  }

  nextIdx = Math.max(0, Math.min(SPEED_STEPS.length - 1, nextIdx));
  state.playbackSpeed = SPEED_STEPS[nextIdx];
  applySpeedToPlayers();
  syncTransportState();
  setActionLog(`Playback speed: ${state.playbackSpeed.toFixed(2)}x`);
}

function applySpeedToPlayers() {
  audioPlayer.playbackRate = state.playbackSpeed;
  videoPlayer.playbackRate = state.playbackSpeed;
}

function toFileUrl(filePath: string) {
  const normalized = filePath.replace(/\\/g, "/");
  const encodedPath = normalized
    .split("/")
    .map((part) => encodeURIComponent(part))
    .join("/")
    .replace(/%3A/gi, ":");

  return `file:///${encodedPath}`;
}

function formatDuration(seconds: number) {
  const safeSeconds = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);
  const remainder = safeSeconds % 60;

  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`;
  }

  return `${minutes}:${String(remainder).padStart(2, "0")}`;
}

function hueFromName(name: string) {
  let hash = 0;
  for (let i = 0; i < name.length; i += 1) {
    hash = (hash << 5) - hash + name.charCodeAt(i);
    hash |= 0;
  }

  return Math.abs(hash) % 360;
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function getAppRoot() {
  const root = document.querySelector<HTMLDivElement>("#app");

  if (!root) {
    throw new Error("Application root #app was not found in DOM.");
  }

  return root;
}

window.addEventListener("beforeunload", () => {
  disposeMainMessageListener?.();
  audioPlayer.pause();
  videoPlayer.pause();
});
