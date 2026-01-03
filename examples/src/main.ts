import { parse, to_json_string } from "jww-parser";
import "./styles.css";

type StatusType = "info" | "success" | "error";

// Get commit hash from env or use placeholder
const BUILD_COMMIT = import.meta.env.VITE_COMMIT_HASH ?? "dev";
const PACKAGE_VERSION = "2026.1.3";

const elements = {
  fileInput: document.getElementById("fileInput") as HTMLInputElement,
  fileLabel: document.getElementById("fileLabel") as HTMLSpanElement,
  convertBtn: document.getElementById("convertBtn") as HTMLButtonElement,
  status: document.getElementById("status") as HTMLDivElement,
  meta: document.getElementById("meta") as HTMLDListElement,
  jsonOutput: document.getElementById("jsonOutput") as HTMLTextAreaElement,
  downloadLink: document.getElementById("downloadLink") as HTMLAnchorElement,
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

    // Parse JWW to JSON
    setStatus("JSON を生成しています…");
    const jsonString = to_json_string(parse(bytes));

    elements.jsonOutput.value = jsonString;
    updateDownloadLink(jsonString);

    // Display parsed info
    try {
      const parsed = JSON.parse(jsonString);
      updateMeta({
        version: parsed.version || "unknown",
        entityCount: parsed.entities?.length ?? 0,
        layerCount: 256,
      });
    } catch {
      updateMeta({
        version: "unknown",
        entityCount: 0,
        layerCount: 256,
      });
    }

    setStatus("JSON を生成しました。ダウンロードが利用できます。", "success");
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    setStatus(`変換に失敗しました: ${message}`, "error");
    elements.downloadLink.classList.add("disabled");
    elements.downloadLink.setAttribute("aria-disabled", "true");
    elements.downloadLink.removeAttribute("href");
  }
}

type MetaInfo = {
  version: string | number;
  entityCount: number;
  layerCount: number;
};

function updateMeta(info: MetaInfo): void {
  const entries = [
    { label: "バージョン", value: String(info.version) },
    { label: "エンティティ数", value: String(info.entityCount) },
    { label: "レイヤー数", value: String(info.layerCount) },
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

function updateDownloadLink(jsonString: string): void {
  if (downloadUrl) {
    URL.revokeObjectURL(downloadUrl);
  }

  const blob = new Blob([jsonString], { type: "application/json" });
  downloadUrl = URL.createObjectURL(blob);

  elements.downloadLink.href = downloadUrl;
  elements.downloadLink.download = `${selectedFile?.name || "output"}.json`;
  elements.downloadLink.classList.remove("disabled");
  elements.downloadLink.setAttribute("aria-disabled", "false");
}

function setCommitHash(): void {
  if (!elements.commitHash) return;
  elements.commitHash.textContent = BUILD_COMMIT;
}

function setVersion(): void {
  if (!elements.jwwVersion) return;
  elements.jwwVersion.textContent = PACKAGE_VERSION;
}
