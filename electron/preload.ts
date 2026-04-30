import { ipcRenderer, contextBridge } from "electron";
import { IPC_CHANNELS, type LokiAppApi } from "../src/common/contracts";

const appApi: LokiAppApi = {
  getBootstrap: () => ipcRenderer.invoke(IPC_CHANNELS.bootstrap),
  pickDataDirectory: () => ipcRenderer.invoke(IPC_CHANNELS.pickDataDirectory),
  pickLibraryDirectory: () =>
    ipcRenderer.invoke(IPC_CHANNELS.pickLibraryDirectory),
  scanLibrary: () => ipcRenderer.invoke(IPC_CHANNELS.scanLibrary),
  getMediaMetadata: (filePath: string) =>
    ipcRenderer.invoke(IPC_CHANNELS.getMediaMetadata, filePath),
  onMainMessage: (listener) => {
    const wrappedListener = (
      _event: Electron.IpcRendererEvent,
      message: string,
    ) => {
      listener(message);
    };

    ipcRenderer.on(IPC_CHANNELS.mainMessage, wrappedListener);

    return () => {
      ipcRenderer.off(IPC_CHANNELS.mainMessage, wrappedListener);
    };
  },
};

contextBridge.exposeInMainWorld("appApi", appApi);
