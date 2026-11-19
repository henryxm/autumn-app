#!/usr/bin/env bash
# 源仓发版：对齐 packages/*.yaml + ios/*.podspec 版本，打 annotated tag ops-vX.Y.Z 并推送。
# 用法：
#   ./scripts/release_ops_tag.sh 0.1.1 "一句话变更说明"
#   ./scripts/release_ops_tag.sh 0.1.1 "说明" --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NEW="${1:-}"
MSG="${2:-}"
DRY=0
[[ "${3:-}" == "--dry-run" ]] && DRY=1

if [[ -z "$NEW" || -z "$MSG" ]]; then
  echo "用法: $0 <X.Y.Z> \"变更说明\" [--dry-run]" >&2
  exit 1
fi

if [[ ! "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "版本须为 SemVer 数字段，例如 0.1.1" >&2
  exit 1
fi

TAG="ops-v${NEW}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "本地已存在 tag $TAG，禁止覆盖。请升 PATCH/MINOR。" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "工作区不干净，请先提交或 stash。" >&2
  git status -sb
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "请在 main 上发版（当前: $BRANCH）" >&2
  exit 1
fi

git fetch origin main --tags
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse origin/main)"
if [[ "$LOCAL" != "$REMOTE" ]]; then
  echo "本地 HEAD 与 origin/main 不一致，请先 pull/push 对齐。" >&2
  echo "  local  $LOCAL"
  echo "  remote $REMOTE"
  exit 1
fi

bump_yaml() {
  local f="$1"
  perl -i -pe "s/^version:\\s*.*/version: $NEW/" "$f"
}

bump_podspec() {
  local f="$1"
  perl -i -pe "s/s\\.version\\s*=\\s*'[^']*'/s.version          = '$NEW'/" "$f"
}

bump_yaml packages/autumn_ops/pubspec.yaml
bump_yaml packages/autumn_ops_ui/pubspec.yaml
bump_podspec ios/AutumnOpsCore/AutumnOpsCore.podspec
bump_podspec ios/AutumnOpsUI/AutumnOpsUI.podspec

echo "==> 版本已改为 $NEW"
git diff --stat

if [[ "$DRY" -eq 1 ]]; then
  echo "dry-run：不提交、不打 tag。可用 git checkout -- 还原。"
  exit 0
fi

git add packages/autumn_ops/pubspec.yaml packages/autumn_ops_ui/pubspec.yaml \
  ios/AutumnOpsCore/AutumnOpsCore.podspec ios/AutumnOpsUI/AutumnOpsUI.podspec
git commit -m "chore(ops): 发版 ${TAG}。" -m "${MSG}"

git tag -a "$TAG" -m "ops packages v${NEW}: ${MSG}"
echo "==> 已创建本地 tag $TAG @ $(git rev-parse --short HEAD)"
echo "推送："
echo "  git push origin main"
echo "  git push origin $TAG"
echo "宿主跟版：crchat_flutter/scripts/sync_autumn_ops.sh $TAG"
