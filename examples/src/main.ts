import DxfParser from "@f12o/dxf-parser";
import { Viewer } from "@f12o/three-dxf";
import { jww_to_dxf } from "jww-parser";
import "./styles.css";

type StatusType = "info" | "success" | "error";

type ProgressUpdate = {
  layerCount: number;
  entityCount: number;
  blockCount: number;
};

// Get commit hash from env or use placeholder
const BUILD_COMMIT = import.meta.env.VITE_COMMIT_HASH ?? "dev";
const PACKAGE_VERSION = "2025.12.5";

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
let downloadUrl: string | null = null;

// Initialize
init();

async function init(): Promise<void> {
  setCommitHash();
  setVersion();
  attachEventHandlers();
  setStatus("JWW ファイルを選択してください。", "success");
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
  elements.convertBtn.disabled = !selectedFile;
}

async function convertFile(): Promise<void> {
  if (!selectedFile) {
    alert("JWW ファイルを選択してください。");
    return;
  }

  try {
    setStatus("JWW を読み込み中…");
    const buffer = await selectedFile.arrayBuffer();
    const bytes = new Uint8Array(buffer);

    // Convert JWW to DXF string using jww-parser-mbt
    setStatus("DXF を生成しています…");
    const dxfString = jww_to_dxf(bytes);

    if (!dxfString) {
      throw new Error("DXF 変換に失敗しました");
    }

    elements.dxfOutput.value = dxfString;
    updateDownloadLink(dxfString);

    // Parse DXF to get counts
    setStatus("DXF を解析中…");
    const parser = new DxfParser();
    const parsed = parser.parseSync(dxfString);

    // Count entities, layers, and blocks
    let entityCount = 0;
    let layerCount = 0;
    let blockCount = 0;

    if (parsed.entities) {
      entityCount = parsed.entities.length;
    }

    if (parsed.tables?.layer) {
      // layer can be an array or an object with layers property
      const layers = parsed.tables.layer;
      if (Array.isArray(layers)) {
        layerCount = layers.length;
      } else if (layers.layers && Array.isArray(layers.layers)) {
        layerCount = layers.layers.length;
      }
    }

    if (parsed.tables?.block) {
      const blocks = parsed.tables.block;
      if (Array.isArray(blocks)) {
        blockCount = blocks.length;
      } else if (blocks.blocks && Array.isArray(blocks.blocks)) {
        blockCount = blocks.blocks.length;
      }
    }

    updateMeta({
      layerCount,
      entityCount,
      blockCount,
    });

    await renderPreview(dxfString);

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

function setVersion(): void {
  if (!elements.jwwVersion) return;
  elements.jwwVersion.textContent = PACKAGE_VERSION;
}
