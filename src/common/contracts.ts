export type MediaFormat = "mp4" | "mp3" | "opus" | "wav";

export type LibraryTab = "audio" | "video";

export type MediaKind = LibraryTab;

export interface MediaLibraryItem {
  id: string;
  fileName: string;
  filePath: string;
  kind: MediaKind;
}

export interface MediaMetadata {
  title?: string;
  artist?: string;
  album?: string;
  duration?: number;
  pictureBase64?: string;
}

export interface LibrarySnapshot {
  rootDirectory: string;
  items: MediaLibraryItem[];
}

export interface ShortcutDefinition {
  id: string;
  label: string;
  combo: string;
  notes?: string;
}

export interface BootstrapPayload {
  appName: string;
  appVersion: string;
  platform: string;
  supportedFormats: MediaFormat[];
  dataDirectory: string;
  libraryDirectory: string;
  shortcuts: ShortcutDefinition[];
}

export interface LokiAppApi {
  getBootstrap: () => Promise<BootstrapPayload>;
  pickDataDirectory: () => Promise<string | null>;
  pickLibraryDirectory: () => Promise<string | null>;
  scanLibrary: () => Promise<LibrarySnapshot>;
  getMediaMetadata: (filePath: string) => Promise<MediaMetadata>;
  onMainMessage: (listener: (message: string) => void) => () => void;
}

export const IPC_CHANNELS = {
  bootstrap: "loki:bootstrap",
  pickDataDirectory: "loki:pick-data-directory",
  pickLibraryDirectory: "loki:pick-library-directory",
  scanLibrary: "loki:scan-library",
  getMediaMetadata: "loki:get-media-metadata",
  mainMessage: "loki:main-message",
} as const;
