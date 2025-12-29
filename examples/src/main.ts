import DxfParser from "@f12o/dxf-parser";
import { Viewer } from "@f12o/three-dxf";
import "./styles.css";
import { loadWasm, isWasmSupported } from "./wasm-loader";

type StatusType = "info" | "success" | "error";

type ProgressUpdate = {
  layerCount: number;
  entityCount: number;
  blockCount: number;
};

// Get commit hash from env or use placeholder
const BUILD_COMMIT = import.meta.env.VITE_COMMIT_HASH ?? "dev";

const elements = {
  fileInput: document.getElementById("fileInput") as HTMLInputElement,
  fileLabel: document.getElementById("fileLabel") as HTMLSpanElement,
  convertBtn: document.getElementById("convertBtn") as HTMLButtonElement,
  status: document.getElementById("status") as HTMLDivElement,
  meta: document.getElementById("meta") as HTMLDListElement,
  dxfOutput: document.getElementById("dxfOutput") as HTMLTextAreaElement,
  downloadLink: document.getElementById("downloadLink") as HTMLAnchorElement,
  viewer: document.getElementById("viewer") as HTMLDivElement,
  viewerMessage: document.getElementById("viewerMessage") as HTMLDivElement,
  commitHash: document.getElementById("commitHash") as HTMLElement,
  jwwVersion: document.getElementById("jwwVersion") as HTMLElement,
};

let selectedFile: File | null = null;
let wasmReady = false;
let downloadUrl: string | null = null;

// Initialize
init();

async function init(): Promise<void> {
  setCommitHash();
  attachEventHandlers();

  if (!isWasmSupported()) {
    setStatus("WASM がサポートされていないブラウザです。", "error");
    return;
  }

  try {
    setStatus("WASM を読み込んでいます…");
    await loadWasm();
    wasmReady = true;
    setStatus("WASM がロードされました。JWW ファイルを選択してください。", "success");
    updateConvertButton();
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : "Unknown WASM load error";
    setStatus(`WASM のロードに失敗しました: ${message}`, "error");
  }
}

function attachEventHandlers(): void {
  elements.fileInput.addEventListener("change", (event) => {
    const target = event.target as HTMLInputElement;
    selectedFile = target.files?.[0] ?? null;
    elements.fileLabel.textContent = selectedFile?.name ?? "ファイルを選択";
    updateConvertButton();
  });

  elements.convertBtn.addEventListener("click", async () => {
    elements.convertBtn.disabled = true;
    await convertFile();
    updateConvertButton();
  });
}

function setStatus(message: string, type: StatusType = "info"): void {
  elements.status.textContent = message;
  elements.status.dataset.type = type;
}

function updateConvertButton(): void {
  elements.convertBtn.disabled = !wasmReady || !selectedFile;
}

async function convertFile(): Promise<void> {
  if (!selectedFile) {
    alert("JWW ファイルを選択してください。");
    return;
  }

  if (!wasmReady) {
    alert("WASM のロードに失敗しています。ページを再読み込みしてください。");
    return;
  }

  try {
    setStatus("JWW を読み込み中…");
    const buffer = await selectedFile.arrayBuffer();
    const bytes = new Uint8Array(buffer);

    const wasm = await loadWasm();

    // Convert JWW to DXF string using MoonBit WASM
    setStatus("DXF を生成しています…");
    const dxfString = wasm.jww_to_dxf(bytes);

    if (!dxfString) {
      throw new Error("DXF 変換に失敗しました");
    }

    elements.dxfOutput.value = dxfString;
    updateDownloadLink(dxfString);
    await renderPreview(dxfString);

    // Update meta info (placeholder for now)
    updateMeta({
      layerCount: 0,
      entityCount: 0,
      blockCount: 0,
    });

    setStatus(
      "DXF を生成しました。プレビューとダウンロードが利用できます。",
      "success"
    );
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    setStatus(`変換に失敗しました: ${message}`, "error");
    resetViewer("プレビューを表示できませんでした。");
    elements.downloadLink.classList.add("disabled");
    elements.downloadLink.setAttribute("aria-disabled", "true");
    elements.downloadLink.removeAttribute("href");
  }
}

function updateMeta(update: ProgressUpdate): void {
  const entries = [
    { label: "レイヤー数", value: update.layerCount },
    { label: "エンティティ数", value: update.entityCount },
    { label: "ブロック数", value: update.blockCount },
  ];

  elements.meta.innerHTML = entries
    .map(
      (entry) => `
        <div>
            <dt>${entry.label}</dt>
            <dd>${entry.value}</dd>
        </div>
      `
    )
    .join("");
}

function updateDownloadLink(dxfString: string): void {
  if (downloadUrl) {
    URL.revokeObjectURL(downloadUrl);
  }

  const blob = new Blob([dxfString], { type: "application/dxf" });
  downloadUrl = URL.createObjectURL(blob);

  elements.downloadLink.href = downloadUrl;
  elements.downloadLink.download = `${selectedFile?.name || "output"}.dxf`;
  elements.downloadLink.classList.remove("disabled");
  elements.downloadLink.setAttribute("aria-disabled", "false");
}

async function renderPreview(dxfString: string): Promise<void> {
  resetViewer("プレビューを準備しています…");

  try {
    const parser = new DxfParser();
    const parsed = parser.parseSync(dxfString);
    const width = elements.viewer.clientWidth || 640;
    const height = elements.viewer.clientHeight || 480;

    const fontUrl = "https://fonts.gstatic.com/s/notosansjp/v55/-F6jfjtqLzI2JPCgQBnw7HFyzSD-AsregP8VFBEj756wwr4v0qHnANADNsISRDl2PRkiiWsg.0.woff2";

    const viewer = new Viewer(
      parsed,
      elements.viewer,
      width,
      height,
      fontUrl
    );
    viewer.renderer?.setClearColor?.(0x000000, 1);
    viewer.render();
    elements.viewerMessage.textContent =
      "右クリックでパン、マウスホイールでズームできます。";
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    resetViewer(`DXF プレビューの生成に失敗しました: ${message}`);
  }
}

function resetViewer(message: string): void {
  elements.viewer.innerHTML = "";
  elements.viewer.appendChild(elements.viewerMessage);
  elements.viewerMessage.textContent = message;
}

function setCommitHash(): void {
  if (!elements.commitHash) return;
  elements.commitHash.textContent = BUILD_COMMIT;
}
