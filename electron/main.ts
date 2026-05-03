import { app, BrowserWindow, dialog, ipcMain, protocol, net, Menu } from "electron";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { createHash } from "node:crypto";
import { readdir } from "node:fs/promises";
import * as mm from "music-metadata";
import {
  IPC_CHANNELS,
  type BootstrapPayload,
  type LibrarySnapshot,
  type MediaKind,
  type MediaLibraryItem,
  type MediaMetadata,
} from "../src/common/contracts";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// The built directory structure
//
// ├─┬─┬ dist
// │ │ └── index.html
// │ │
// │ ├─┬ dist-electron
// │ │ ├── main.js
// │ │ └── preload.mjs
// │
process.env.APP_ROOT = path.join(__dirname, "..");

// 🚧 Use ['ENV_NAME'] avoid vite:define plugin - Vite@2.x
export const VITE_DEV_SERVER_URL = process.env["VITE_DEV_SERVER_URL"];
export const MAIN_DIST = path.join(process.env.APP_ROOT, "dist-electron");
export const RENDERER_DIST = path.join(process.env.APP_ROOT, "dist");

process.env.VITE_PUBLIC = VITE_DEV_SERVER_URL
  ? path.join(process.env.APP_ROOT, "public")
  : RENDERER_DIST;

let win: BrowserWindow | null;
let dataDirectory = app.getPath("userData");
let audioDirectory = app.getPath("music");
let videoDirectory = app.getPath("videos");

const supportedFormats: BootstrapPayload["supportedFormats"] = [
  "mp4",
  "mp3",
  "opus",
  "wav",
];

const audioExtensions = new Set([".mp3", ".opus", ".wav"]);
const videoExtensions = new Set([".mp4"]);
const supportedExtensions = new Set([...audioExtensions, ...videoExtensions]);

// Register custom protocol for serving local media files to the renderer.
// Must be called before app.whenReady().
protocol.registerSchemesAsPrivileged([
  {
    scheme: "media",
    privileges: {
      secure: true,
      supportFetchAPI: true,
      stream: true,
      bypassCSP: true,
    },
  },
]);

const shortcuts: BootstrapPayload["shortcuts"] = [
  { id: "homeView", label: "Go To Home", combo: "Ctrl + H" },
  { id: "infoView", label: "Go To Info", combo: "Ctrl + I" },
  { id: "settingsView", label: "Go To Settings", combo: "Ctrl + S" },
  { id: "audioTab", label: "Select Audio Tab", combo: "Ctrl + A" },
  { id: "videoTab", label: "Select Video Tab", combo: "Ctrl + V" },
  { id: "search", label: "Search Library", combo: "Ctrl + K" },
  { id: "playPause", label: "Play/Pause", combo: "Space" },
  {
    id: "seekBack",
    label: "Seek Back",
    combo: "Left Arrow / Shift + Left Arrow",
  },
  {
    id: "seekForward",
    label: "Seek Forward",
    combo: "Right Arrow / Shift + Right Arrow",
  },
  { id: "volume", label: "Volume", combo: "Ctrl + Up / Ctrl + Down" },
  {
    id: "track",
    label: "Track Navigation",
    combo: "Ctrl + Left / Ctrl + Right",
  },
  { id: "playSelected", label: "Play Selected", combo: "Ctrl + Enter" },
  { id: "refreshLibrary", label: "Refresh Current Library", combo: "Ctrl + R" },
  {
    id: "likedMusic",
    label: "Add To Liked Music",
    combo: "Ctrl + B",
    notes: "MVP default quick-add shortcut",
  },
  {
    id: "playlistTarget",
    label: "Add To User Playlist",
    combo: "Ctrl + P",
    notes: "Can be deferred from MVP if playlist target flow is postponed",
  },
];

function getBootstrapPayload(): BootstrapPayload {
  return {
    appName: app.getName() || "Fumic",
    appVersion: app.getVersion(),
    platform: process.platform,
    supportedFormats,
    dataDirectory,
    audioDirectory,
    videoDirectory,
    shortcuts,
  };
}

function inferMediaKind(filePath: string): MediaKind | null {
  const extension = path.extname(filePath).toLowerCase();

  if (extension === ".mp4") {
    return "video";
  }

  if (extension === ".mp3" || extension === ".opus" || extension === ".wav") {
    return "audio";
  }

  return null;
}

async function collectMediaFiles(
  rootDirectory: string,
  allowedExtensions?: Set<string>,
): Promise<MediaLibraryItem[]> {
  const collected: MediaLibraryItem[] = [];
  const stack: string[] = [rootDirectory];
  const filterSet = allowedExtensions || supportedExtensions;

  while (stack.length > 0) {
    const currentDirectory = stack.pop();

    if (!currentDirectory) {
      continue;
    }

    let entries;
    try {
      entries = await readdir(currentDirectory, { withFileTypes: true });
    } catch {
      continue;
    }

    for (const entry of entries) {
      const fullPath = path.join(currentDirectory, entry.name);

      if (entry.isDirectory()) {
        stack.push(fullPath);
        continue;
      }

      if (!entry.isFile()) {
        continue;
      }

      const extension = path.extname(entry.name).toLowerCase();
      if (!filterSet.has(extension)) {
        continue;
      }

      const kind = inferMediaKind(fullPath);
      if (!kind) {
        continue;
      }

      const id = createHash("sha1").update(fullPath).digest("hex");
      collected.push({
        id,
        fileName: entry.name,
        filePath: fullPath,
        kind,
      });
    }
  }

  return collected.sort((a, b) =>
    a.fileName.localeCompare(b.fileName, undefined, {
      numeric: true,
      sensitivity: "base",
    }),
  );
}

async function scanAudioSnapshot(): Promise<LibrarySnapshot> {
  const items = await collectMediaFiles(audioDirectory, audioExtensions);
  return {
    rootDirectory: audioDirectory,
    items,
  };
}

async function scanVideoSnapshot(): Promise<LibrarySnapshot> {
  const items = await collectMediaFiles(videoDirectory, videoExtensions);
  return {
    rootDirectory: videoDirectory,
    items,
  };
}

function createWindow() {
  win = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 980,
    minHeight: 640,
    backgroundColor: "#151a1e",
    autoHideMenuBar: true,
    icon: path.join(process.env.APP_ROOT, "build", "icon.ico"),
    webPreferences: {
      preload: path.join(__dirname, "preload.mjs"),
      webSecurity: false,
    },
  });

  /* Override default Electron menu to remove Ctrl+R reload accelerator.
     Keep Edit menu for clipboard shortcuts and DevTools in dev mode. */
  const menuTemplate: Electron.MenuItemConstructorOptions[] = [
    {
      label: "Edit",
      submenu: [
        { role: "undo" },
        { role: "redo" },
        { type: "separator" },
        { role: "cut" },
        { role: "copy" },
        { role: "paste" },
        { role: "selectAll" },
      ],
    },
  ];

  if (VITE_DEV_SERVER_URL) {
    menuTemplate.push({
      label: "Developer",
      submenu: [
        { role: "toggleDevTools" },
      ],
    });
  }

  Menu.setApplicationMenu(Menu.buildFromTemplate(menuTemplate));

  // Test active push message to Renderer-process.
  win.webContents.on("did-finish-load", () => {
    win?.webContents.send(
      IPC_CHANNELS.mainMessage,
      `Main process ready at ${new Date().toLocaleString()}`,
    );
  });

  if (VITE_DEV_SERVER_URL) {
    win.loadURL(VITE_DEV_SERVER_URL);
  } else {
    // win.loadFile('dist/index.html')
    win.loadFile(path.join(RENDERER_DIST, "index.html"));
  }
}

function registerIpcHandlers() {
  ipcMain.handle(IPC_CHANNELS.bootstrap, () => getBootstrapPayload());

  ipcMain.handle(IPC_CHANNELS.pickDataDirectory, async () => {
    if (!win) {
      return null;
    }

    const result = await dialog.showOpenDialog(win, {
      title: "Select Fumic Data Directory",
      defaultPath: dataDirectory,
      properties: ["openDirectory", "createDirectory"],
    });

    if (result.canceled || result.filePaths.length === 0) {
      return null;
    }

    dataDirectory = result.filePaths[0];
    return dataDirectory;
  });

  ipcMain.handle(IPC_CHANNELS.pickAudioDirectory, async () => {
    if (!win) {
      return null;
    }

    const result = await dialog.showOpenDialog(win, {
      title: "Select Audio Library Directory",
      defaultPath: audioDirectory,
      properties: ["openDirectory", "createDirectory"],
    });

    if (result.canceled || result.filePaths.length === 0) {
      return null;
    }

    audioDirectory = result.filePaths[0];
    return audioDirectory;
  });

  ipcMain.handle(IPC_CHANNELS.pickVideoDirectory, async () => {
    if (!win) {
      return null;
    }

    const result = await dialog.showOpenDialog(win, {
      title: "Select Video Library Directory",
      defaultPath: videoDirectory,
      properties: ["openDirectory", "createDirectory"],
    });

    if (result.canceled || result.filePaths.length === 0) {
      return null;
    }

    videoDirectory = result.filePaths[0];
    return videoDirectory;
  });

  ipcMain.handle(IPC_CHANNELS.scanAudioLibrary, async () => {
    return scanAudioSnapshot();
  });

  ipcMain.handle(IPC_CHANNELS.scanVideoLibrary, async () => {
    return scanVideoSnapshot();
  });

  ipcMain.handle(
    IPC_CHANNELS.getMediaMetadata,
    async (_, filePath: string): Promise<MediaMetadata> => {
      try {
        /* Race against a 5-second timeout so one bad file doesn't block the queue */
        const metadataPromise = mm.parseFile(filePath);
        const timeoutPromise = new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("Metadata parse timeout")), 5000)
        );

        const metadata = await Promise.race([metadataPromise, timeoutPromise]);
        let pictureBase64: string | undefined = undefined;

        if (metadata.common.picture && metadata.common.picture.length > 0) {
          const pic = metadata.common.picture[0];
          pictureBase64 = `data:${pic.format};base64,${Buffer.from(pic.data).toString("base64")}`;
        }

        return {
          title: metadata.common.title,
          artist: metadata.common.artist,
          album: metadata.common.album,
          duration: metadata.format.duration,
          pictureBase64,
        };
      } catch {
        return {};
      }
    },
  );
}

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
    win = null;
  }
});

app.on("activate", () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

app.whenReady().then(() => {
  // Handle media:// protocol requests by serving local files
  protocol.handle("media", (request) => {
    const filePath = decodeURIComponent(request.url.slice("media://".length));
    return net.fetch(`file:///${filePath}`);
  });

  registerIpcHandlers();
  createWindow();
});
