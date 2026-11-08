#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/web/statusicon.sh
#
# Every status icon on a Xymon page is written by statusicon() or, for the
# fixed image of the info, trends and client columns, columnicon()
# (lib/color.c). The tag carries a CLASS naming it "xmdot", then
# "xmdot-<colour>" with "xmdot-recent" or "xmdot-ack" when the image is
# that variant, or "xmdot-<column>", so a stylesheet can address the icons
# without knowing the image names. The bare colour names are not used:
# xymonbody.css gives them the page background.
# This pins the tag for each case the pages use, with and without
# --recentgifs, and checks that a page built by the real report code
# (generate_replog(), via the reportlog harness) carries it.

set -euo pipefail
# shellcheck source=tests/lib/assert.sh
. "$(dirname "$0")/../lib/assert.sh"

ROOT=$(find_root)

require_c_buildenv "$ROOT"

work=$(mktempdir)

pcre_libs=${PCRELIBS:-}
[ -n "$pcre_libs" ] || pcre_libs=$(sed -n 's/^PCRELIBS *= *//p' "$ROOT/Makefile")
harness_cflags=$(xymon_cflags "$ROOT")
harness_ldflags=$(xymon_ldflags "$ROOT")

for h in statusicon reportlog-text; do
	# shellcheck disable=SC2086  # flag lists are meant to split
	"$CC" $harness_cflags -o "$work/$h" \
		"$ROOT/tests/web/$h-harness.c" \
		"$ROOT/lib/libxymon.a" "$ROOT/lib/libxymoncomm.a" "$ROOT/lib/libxymon.a" \
		$pcre_libs $harness_ldflags 2>"$work/cc.log" \
		|| { cat "$work/cc.log" >&2; fail "the $h harness does not build"; }
done

# Fixed values, so the expected tags do not depend on the defaults.
export XYMONSKIN=/xymon/gifs DOTHEIGHT=16 DOTWIDTH=16 IMAGEFILETYPE=gif

tail='HEIGHT="16" WIDTH="16" BORDER=0>'

plain=$("$work/statusicon" 2>"$work/stderr.log") \
	|| fail "the statusicon harness failed: $(cat "$work/stderr.log")"
expected="<IMG SRC=\"/xymon/gifs/red.gif\" CLASS=\"xmdot xmdot-red\" ALT=\"red\" TITLE=\"red\" $tail
<IMG SRC=\"/xymon/gifs/yellow.gif\" CLASS=\"xmdot xmdot-yellow\" ALT=\"yellow\" TITLE=\"yellow\" $tail
<IMG SRC=\"/xymon/gifs/purple-ack.gif\" CLASS=\"xmdot xmdot-purple xmdot-ack\" ALT=\"purple\" TITLE=\"purple\" $tail
<IMG SRC=\"/xymon/dialup/green.gif\" CLASS=\"xmdot xmdot-green\" ALT=\"green\" $tail
<IMG SRC=\"/xymon/gifs/green.gif\" CLASS=\"xmdot xmdot-info\" ALT=\"info\" TITLE=\"info\" $tail"
assert_equal "$expected" "$plain" "without --recentgifs, no icon is a -recent one"

# No icon class may be one the shipped stylesheet already styles: a bare
# .green there is the page background, and it would paint every icon.
css_classes=$(sed -n 's/^\.\([[:alnum:]_-]*\)[[:space:]]*{.*/\1/p' "$ROOT/xymond/wwwfiles/gifs/xymonbody.css")
[ -n "$css_classes" ] || fail "found no class selectors in xymonbody.css"
icon_classes=$(printf '%s\n' "$plain" | sed -n 's/.* CLASS="\([^"]*\)".*/\1/p' | tr ' ' '\n' | sort -u)
for c in $css_classes; do
	case $'\n'"$icon_classes"$'\n' in
		*$'\n'"$c"$'\n'*) fail "icon class '$c' is also a selector in xymonbody.css" ;;
	esac
done

recent=$("$work/statusicon" recent 2>"$work/stderr.log") \
	|| fail "the statusicon harness failed: $(cat "$work/stderr.log")"
line2=$(printf '%s\n' "$recent" | sed -n 2p)
line3=$(printf '%s\n' "$recent" | sed -n 3p)
assert_equal "<IMG SRC=\"/xymon/gifs/yellow-recent.gif\" CLASS=\"xmdot xmdot-yellow xmdot-recent\" ALT=\"yellow\" TITLE=\"yellow\" $tail" \
	"$line2" "with --recentgifs, a recent change gets the -recent image and the class"
assert_equal "<IMG SRC=\"/xymon/gifs/purple-ack.gif\" CLASS=\"xmdot xmdot-purple xmdot-ack\" ALT=\"purple\" TITLE=\"purple\" $tail" \
	"$line3" "with --recentgifs, an acknowledged status still gets the -ack image and class"

# The legend of the HTML availability report, written by generate_replog().
mkdir -p "$work/web"
: >"$work/web/replog_header"
: >"$work/web/replog_footer"
TZ=UTC XYMONHOME="$work" "$work/reportlog-text" "$work/report.txt" >"$work/report.html" 2>"$work/stderr.log" \
	|| fail "the reportlog harness failed: $(cat "$work/stderr.log")"
report=$(cat "$work/report.html")
for c in green yellow red purple clear blue; do
	assert_contains "<IMG SRC=\"/xymon/gifs/$c.gif\" CLASS=\"xmdot xmdot-$c\" ALT=\"$c\" TITLE=\"$c\" $tail" \
		"$report" "the availability report's legend shows $c through statusicon()"
done

pass "status icons carry the xmdot class for their colour, recent, ack or column"
