#!/usr/bin/env bash
# Kopiert die ausgewählte Teilmenge der Agents aus einem Klon von
# https://github.com/msitarzewski/agency-agents (MIT) nach .claude/agents/ und
# die Lizenz nach .claude/agency-agents-LICENSE.
#
# Aufruf:   .scripts/sync_agency_agents.sh /pfad/zum/agency-agents-klon
# Danach:   `git diff .claude` LESEN (die Dateien sind Fremd-Prompts, die Claude Code
#           als Subagents mit allen Rechten der Sitzung ausführt), den Commit-Hash in
#           .claude/agency-agents-NOTICE.md nachtragen, committen.
#
# Auswahl und Begründung: .claude/agency-agents-NOTICE.md
set -euo pipefail

SRC="${1:?Pfad zum Klon von msitarzewski/agency-agents angeben}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.claude/agents"

# <Division>/<Dateiname ohne .md> im Upstream-Repo
AGENTS=(
  engineering/engineering-mobile-app-builder
  engineering/engineering-mobile-release-engineer
  engineering/engineering-code-reviewer
  engineering/engineering-privacy-engineer
  engineering/engineering-software-architect
  engineering/engineering-technical-writer
  design/design-ui-designer
  design/design-ux-researcher
  testing/testing-accessibility-auditor
  testing/testing-test-results-analyzer
  product/product-feedback-synthesizer
  product/product-sprint-prioritizer
  support/support-legal-compliance-checker
  marketing/marketing-app-store-optimizer
)

[[ -d "$SRC/.git" ]] || { echo "kein Git-Klon: $SRC" >&2; exit 1; }
[[ -f "$SRC/LICENSE" ]] || { echo "LICENSE fehlt im Klon: $SRC" >&2; exit 1; }

mkdir -p "$DEST"
for agent in "${AGENTS[@]}"; do
  [[ -f "$SRC/$agent.md" ]] || { echo "fehlt im Klon: $agent.md" >&2; exit 1; }
  cp "$SRC/$agent.md" "$DEST/$(basename "$agent").md"
done
cp "$SRC/LICENSE" "$ROOT/.claude/agency-agents-LICENSE"

echo "Quelle: $(git -C "$SRC" rev-parse --short HEAD) ($(git -C "$SRC" log -1 --format=%cs))"
echo "${#AGENTS[@]} Agents nach .claude/agents/ kopiert."
