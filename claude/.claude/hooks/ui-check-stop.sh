#!/usr/bin/env bash
#
# Stop hook: if this session edited UI files and hasn't run ui-check since the
# last such edit, block once and ask Claude to render and check its work.
# Silent (zero context) in sessions that never touch UI files.
#
# Opt-in per project (not enabled globally): add to the project's
# .claude/settings.json (shared) or .claude/settings.local.json (just you):
#   { "hooks": { "Stop": [ { "hooks": [
#       { "type": "command", "command": "~/.claude/hooks/ui-check-stop.sh" } ] } ] } }
set -euo pipefail

# shellcheck disable=SC2016 # backticks are literal Markdown in the message
readonly REASON='You changed UI files. Before calling this done, check the rendered result:
1. Run `ui-check <url> [--storage-state FILE]` against each changed page (screenshots at
   1280/768/375 plus layout checks). Use the dev server URL, or a file path for static HTML.
   For pages behind a login, sign in once with Playwright and save the session first.
2. Look at every screenshot. Edges should line up, siblings in a row share their alignment,
   repeated cards match part by part, nothing scrolls sideways or is clipped, and icons sit
   centred on their text.
3. Fix causes, not symptoms: use the project'"'"'s tokens, never literal values; `gap` for
   sibling spacing; flex/grid alignment, never pixel nudges; delete a stray value rather
   than adding an override.
4. Re-run until clean. Report what you measured, and label anything you could not measure
   as unverified. If there is nothing to render (not a web UI, or no way to run it), say so
   in one line and finish.'

input="$(cat)"
[[ "$(jq -r '.stop_hook_active // false' <<<"${input}")" == "true" ]] && exit 0
transcript="$(jq -r '.transcript_path // empty' <<<"${input}")"
[[ -r "${transcript}" ]] || exit 0

# Positions (in tool-call order) of the last UI-file edit and the last ui-check run.
read -r last_edit last_check < <(jq -rs '
  [.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")]
  | to_entries
  | ([.[] | select((.value.name | test("^(Edit|Write|MultiEdit)$"))
       and ((.value.input.file_path // "")
         | test("\\.(css|scss|sass|less|html?|vue|svelte|astro|jsx|tsx)$|\\.component\\.ts$")))]
     | last | .key // -1) as $edit
  | ([.[] | select(.value.name == "Bash" and ((.value.input.command // "") | test("\\bui-check\\b")))]
     | last | .key // -1) as $check
  | "\($edit) \($check)"' "${transcript}")

(( last_edit >= 0 && last_check < last_edit )) || exit 0
jq -n --arg reason "${REASON}" '{decision: "block", reason: $reason}'
