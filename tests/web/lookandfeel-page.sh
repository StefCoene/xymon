#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/web/lookandfeel-page.sh
#
# The Look and feel page (xymond/wwwfiles/lookandfeel/) previews a layout
# and an icon set in the browser and shows the xymonsettings.sh commands
# that make the choice permanent. This checks what can be checked without
# a browser: the shipped menu links the page, the page finds its script and
# stylesheet, all three are plain ASCII (the page may be served without a
# character set), and every command the page proposes is one
# xymonsettings.sh accepts -- a renamed command would otherwise leave the
# page telling administrators to run something that fails. skins/index.txt,
# and layouts/index.txt, which tell the page what icon sets and layouts
# there are, name every skin and layout shipped and nothing else.
#
# What the script does in the browser -- reading the current layout and
# icons from a page, rewriting it for the preview -- is not run here: the
# suite runs no JavaScript.

set -euo pipefail
# shellcheck source=tests/lib/assert.sh
. "$(dirname "$0")/../lib/assert.sh"

ROOT=$(find_root)
page=$ROOT/xymond/wwwfiles/lookandfeel
require_cfg MENU_CFG xymond/etcfiles/xymonmenu.cfg
require_cfg SETTINGS_DIST xymond/xymonsettings.sh.DIST
[ -f "$page/index.html" ] || fail "xymond/wwwfiles/lookandfeel/index.html is missing"

grep -q 'href="$XYMONSERVERWWWURL/lookandfeel/"' "$MENU_CFG" \
	|| fail "the shipped xymonmenu.cfg does not link the Look and feel page"

for ref in $(grep -o -E '(src|href)="[^"/:]+"' "$page/index.html" | sed -e 's/^[a-z]*="//' -e 's/"$//'); do
	[ -f "$page/$ref" ] || fail "lookandfeel/index.html links $ref, which is not there"
done
for f in index.html lookandfeel.js lookandfeel.css; do
	[ -f "$page/$f" ] || fail "lookandfeel/$f is missing"
	bad=$(LC_ALL=C grep -n '[^[:print:][:space:]]' "$page/$f" || true)
	[ -z "$bad" ] || fail "lookandfeel/$f is not plain ASCII: $bad"
done

cmds=$(grep -o -E '"xymonsettings\.sh (-a )?[a-z]+' "$page/lookandfeel.js" | sed -e 's/^"xymonsettings\.sh //' -e 's/^-a //' | sort -u)
[ -n "$cmds" ] || fail "lookandfeel.js proposes no xymonsettings.sh command"
for c in $cmds; do
	grep -q "^$c)" "$SETTINGS_DIST" || fail "lookandfeel.js proposes 'xymonsettings.sh $c', a command xymonsettings.sh does not have"
done

for kind in skins layouts; do
	index=$ROOT/xymond/wwwfiles/$kind/index.txt
	[ -f "$index" ] || fail "xymond/wwwfiles/$kind/index.txt is missing"
	listed=$(grep -v -e '^#' -e '^[[:space:]]*$' "$index" | sort)
	shipped=$(cd "$ROOT/xymond/wwwfiles/$kind" && for d in */; do printf '%s\n' "${d%/}"; done | sort)
	[ "$listed" = "$shipped" ] || fail "$kind/index.txt lists '$(echo $listed)', the $kind shipped are '$(echo $shipped)'"
done

pass "the menu links the Look and feel page, which finds its files, is plain ASCII, proposes only commands xymonsettings.sh has ($(echo $cmds)), and the index.txt files list the shipped skins and layouts"
