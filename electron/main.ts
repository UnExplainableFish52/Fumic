import { app, BrowserWindow, dialog, ipcMain, protocol, net } from "electron";
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
let libraryDirectory = app.getPath("music");

const supportedFormats: BootstrapPayload["supportedFormats"] = [
  "mp4",
  "mp3",
  "opus",
  "wav",
];
const supportedExtensions = new Set([".mp3", ".opus", ".wav", ".mp4"]);

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
    libraryDirectory,
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
): Promise<MediaLibraryItem[]> {
  const collected: MediaLibraryItem[] = [];
  const stack: string[] = [rootDirectory];

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
      if (!supportedExtensions.has(extension)) {
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

async function scanLibrarySnapshot(): Promise<LibrarySnapshot> {
  const items = await collectMediaFiles(libraryDirectory);
  return {
    rootDirectory: libraryDirectory,
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

  ipcMain.handle(IPC_CHANNELS.pickLibraryDirectory, async () => {
    if (!win) {
      return null;
    }

    const result = await dialog.showOpenDialog(win, {
      title: "Select Fumic Media Library Directory",
      defaultPath: libraryDirectory,
      properties: ["openDirectory", "createDirectory"],
    });

    if (result.canceled || result.filePaths.length === 0) {
      return null;
    }

    libraryDirectory = result.filePaths[0];
    return libraryDirectory;
  });

  ipcMain.handle(IPC_CHANNELS.scanLibrary, async () => {
    return scanLibrarySnapshot();
  });

  ipcMain.handle(
    IPC_CHANNELS.getMediaMetadata,
    async (_, filePath: string): Promise<MediaMetadata> => {
      try {
        const metadata = await mm.parseFile(filePath);
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
