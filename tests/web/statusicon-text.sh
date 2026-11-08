#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/web/statusicon-text.sh
#
# With ICONSTYLE=text, statusicon() and columnicon() (lib/color.c) write a
# character in a SPAN instead of an <IMG>: one per colour, "*" after a
# recent change, "~" after an acknowledgement, and for the info column a
# character that is not a status one. The SPAN keeps the classes the image
# carries, the ALT text as ARIA-LABEL, and DOTWIDTH as its minimum width.
# This pins the SPAN for each case the pages use, with and without
# --recentgifs, and checks that the shipped xymonbody.css colours each
# status class. statusicon.sh pins the image form.

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

# shellcheck disable=SC2086  # flag lists are meant to split
"$CC" $harness_cflags -o "$work/statusicon" \
	"$ROOT/tests/web/statusicon-harness.c" \
	"$ROOT/lib/libxymon.a" "$ROOT/lib/libxymoncomm.a" "$ROOT/lib/libxymon.a" \
	$pcre_libs $harness_ldflags 2>"$work/cc.log" \
	|| { cat "$work/cc.log" >&2; fail "the statusicon harness does not build"; }

export XYMONSKIN=/xymon/gifs DOTHEIGHT=16 DOTWIDTH=20 IMAGEFILETYPE=gif ICONSTYLE=text

w='STYLE="min-width: 20px"'

plain=$("$work/statusicon" 2>"$work/stderr.log") \
	|| fail "the statusicon harness failed: $(cat "$work/stderr.log")"
expected="<SPAN CLASS=\"xmdot xmdot-red\" ROLE=\"img\" ARIA-LABEL=\"red\" TITLE=\"red\" $w>&#x2715;</SPAN>
<SPAN CLASS=\"xmdot xmdot-yellow\" ROLE=\"img\" ARIA-LABEL=\"yellow\" TITLE=\"yellow\" $w>&#x25B2;</SPAN>
<SPAN CLASS=\"xmdot xmdot-purple xmdot-ack\" ROLE=\"img\" ARIA-LABEL=\"purple\" TITLE=\"purple\" $w>&#x25C6;<SPAN CLASS=\"xmdot-mark\">~</SPAN></SPAN>
<SPAN CLASS=\"xmdot xmdot-green\" ROLE=\"img\" ARIA-LABEL=\"green\" $w>&#x2713;</SPAN>
<SPAN CLASS=\"xmdot xmdot-info\" ROLE=\"img\" ARIA-LABEL=\"info\" TITLE=\"info\" $w>&#x24D8;</SPAN>"
assert_equal "$expected" "$plain" "text icons without --recentgifs"

recent=$("$work/statusicon" recent 2>"$work/stderr.log") \
	|| fail "the statusicon harness failed: $(cat "$work/stderr.log")"
line2=$(printf '%s\n' "$recent" | sed -n 2p)
assert_equal "<SPAN CLASS=\"xmdot xmdot-yellow xmdot-recent\" ROLE=\"img\" ARIA-LABEL=\"yellow\" TITLE=\"yellow\" $w>&#x25B2;<SPAN CLASS=\"xmdot-mark\">*</SPAN></SPAN>" \
	"$line2" "with --recentgifs, a recent change is marked with a *"

# An ICONSTYLE that is not "text" keeps the images.
other=$(ICONSTYLE=fancy "$work/statusicon" 2>"$work/stderr.log") \
	|| fail "the statusicon harness failed: $(cat "$work/stderr.log")"
assert_contains '<IMG SRC="/xymon/gifs/red.gif" CLASS="xmdot xmdot-red"' "$(first_line "$other")" \
	"an unknown ICONSTYLE draws images"

css=$(cat "$ROOT/xymond/wwwfiles/gifs/xymonbody.css")
for c in green yellow red purple clear blue; do
	assert_match "span\.xmdot-$c[[:space:]]*\{[[:space:]]*color:" "$css" \
		"xymonbody.css gives the $c text icon its colour"
done

pass "ICONSTYLE=text writes a coloured character per status, marked when recent or acknowledged"
