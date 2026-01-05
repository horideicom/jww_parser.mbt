#!/usr/bin/env node
import { execSync } from 'child_process';

/**
 * npm version (yyyy.MM.increment) を mooncakes version (0.yyyyMM.increment) に変換
 * 例: 2026.1.5 → 0.202601.5
 */
export function toMooncakesVersion(npmVersion) {
  const [year, month, increment] = npmVersion.split('.');
  const yyyymm = `${year}${String(month).padStart(2, '0')}`;
  return `0.${yyyymm}.${increment}`;
}

/**
 * npm version をパースして { year, month, increment } を返す
 */
export function parseNpmVersion(npmVersion) {
  const [year, month, increment] = npmVersion.split('.');
  return {
    year: parseInt(year, 10),
    month: parseInt(month, 10),
    increment: parseInt(increment, 10)
  };
}

/**
 * git タグから現在のバージョンを取得
 */
export function getCurrentVersionFromGit() {
  try {
    // 最新のタグを取得
    const latestTag = execSync('git describe --tags --abbrev=0 2>/dev/null || echo ""', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    }).trim();

    if (!latestTag) {
      return null;
    }

    // タグから v プレフィックスを除去
    const version = latestTag.replace(/^v/, '');
    return version;
  } catch {
    return null;
  }
}

/**
 * 現在の日付から次のバージョンを提案 (npm version 形式)
 */
export function suggestNextNpmVersion() {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;

  // git タグから現在の月の最大 increment を取得
  const currentVersion = getCurrentVersionFromGit();
  let nextIncrement = 1;

  if (currentVersion) {
    const parsed = parseNpmVersion(currentVersion);
    if (parsed.year === year && parsed.month === month) {
      // 同じ月の場合は increment を増やす
      nextIncrement = parsed.increment + 1;
    }
  }

  return `${year}.${month}.${nextIncrement}`;
}
