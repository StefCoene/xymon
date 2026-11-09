#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/web/layout-templates.sh
#
# Every page header loads the page layout -- layout.css and layout.js from
# the directory XYMONLAYOUT names -- so switching XYMONLAYOUT changes every
# page. Rendered through web/xymonpage, which fills in a header template the
# way the CGIs and xymongen do: a template that does not load the layout, or
# loads it from a fixed place, shows here as a page that ignores the setting.
# Without an XYMONLAYOUT line in xymonserver.cfg the built-in default
# applies, the classic layout under XYMONSERVERWWWURL.
#
# The six headers that refresh their page keep the <meta refresh> only
# inside <noscript>, and with JavaScript start a reload timer of the same
# interval instead, which a layout's script may replace: a meta refresh
# outside <noscript> would reload the page whatever the script does.
#
# Each shipped layout has both files, in plain ASCII, as the pages may be
# served without a character set.
#
# xymonpage crashes on six templates outside a CGI request -- hist, histlog,
# hostsvc, info, replog, trends, which need a host to fill in -- with or
# without this change; those are checked in the template itself, which is
# a shipped file, for the same lines the rendered pages carry.

set -euo pipefail
# shellcheck source=tests/lib/assert.sh
. "$(dirname "$0")/../lib/assert.sh"

ROOT=$(find_root)
require_bin XYMONPAGE web/xymonpage
require_cfg XYMONSERVER_CFG xymond/etcfiles/xymonserver.cfg

work=$(mktempdir)
mkdir -p "$work/home/web" "$work/home/tmp"
cp "$ROOT"/xymond/webfiles/* "$work/home/web/"
sed -e 's|^XYMONHOME=.*|XYMONHOME="'"$work"'/home"|' \
    -e 's|^XYMONTMP=.*|XYMONTMP="'"$work"'/home/tmp"|' \
    -e 's|^XYMONSERVERWWWURL=.*|XYMONSERVERWWWURL="/xy"|' \
	"$XYMONSERVER_CFG" > "$work/base.cfg"
grep -v '^XYMONLAYOUT=' "$work/base.cfg" > "$work/nolayout.cfg"
cp "$work/nolayout.cfg" "$work/probe.cfg"
echo 'XYMONLAYOUT="/probe/layouts/test"' >> "$work/probe.cfg"

# render CFG PREFIX -- the page xymonpage makes from PREFIX_header, or
# nothing when xymonpage cannot render that template here
render() {
	printf 'body\n' | "$XYMONPAGE" --env="$1" --hffile="$2" 2>/dev/null || true
}

pages=0
static=0
for h in "$ROOT"/xymond/webfiles/*_header; do
	prefix=$(basename "$h" _header)
	case "$prefix" in
	divider|confreport) continue ;;	# a fragment, and a print report without styles
	esac
	out=$(render "$work/probe.cfg" "$prefix")
	if [ -n "$out" ]; then
		css='href="/probe/layouts/test/layout.css"'; js='src="/probe/layouts/test/layout.js"'
	else
		out=$(cat "$h"); css='href="&XYMONLAYOUT/layout.css"'; js='src="&XYMONLAYOUT/layout.js"'
		static=$((static + 1))
	fi
	assert_contains "$css" "$out" "the $prefix page does not load layout.css from XYMONLAYOUT"
	assert_contains "$js" "$out" "the $prefix page does not load layout.js from XYMONLAYOUT"
	pages=$((pages + 1))
done
[ "$pages" -gt 0 ] || fail "no page header templates under xymond/webfiles"

out=$(render "$work/nolayout.cfg" stdnormal)
assert_contains 'href="/xy/layouts/classic/layout.css"' "$out" \
	"without an XYMONLAYOUT line the page does not load the built-in default, the classic layout"

refreshing=0
for h in "$ROOT"/xymond/webfiles/*_header; do
	grep -q 'XYMWEBREFRESH' "$h" || continue
	prefix=$(basename "$h" _header)
	out=$(render "$work/probe.cfg" "$prefix")
	v=60
	[ -n "$out" ] || { out=$(cat "$h"); v='&XYMWEBREFRESH'; }
	assert_contains "<noscript><META HTTP-EQUIV=\"REFRESH\" CONTENT=\"$v\"></noscript>" "$out" \
		"the $prefix page has no meta refresh inside <noscript>"
	assert_contains "var xymonRefresh = parseInt(\"$v\", 10)" "$out" \
		"the $prefix page starts no reload timer of the refresh interval"
	stripped=$(printf '%s\n' "$out" | sed -e 's|<noscript>.*</noscript>||')
	case "$stripped" in
	*'HTTP-EQUIV="REFRESH"'*) fail "the $prefix page has a meta refresh outside <noscript>, which no layout can pause" ;;
	esac
	refreshing=$((refreshing + 1))
done
[ "$refreshing" -gt 0 ] || fail "no header template refreshes its page"

layouts=0
for d in "$ROOT"/xymond/wwwfiles/layouts/*/; do
	name=$(basename "$d")
	for f in layout.css layout.js; do
		[ -f "$d$f" ] || fail "layout '$name' has no $f"
		bad=$(LC_ALL=C grep -n '[^[:print:][:space:]]' "$d$f" || true)
		[ -z "$bad" ] || fail "layout '$name' $f is not plain ASCII: $bad"
	done
	layouts=$((layouts + 1))
done
[ -d "$ROOT/xymond/wwwfiles/layouts/classic" ] || fail "the default layout, classic, is not shipped"

pass "all $pages page headers ($static of them read as templates) load the layout XYMONLAYOUT names, classic by default; the $refreshing refreshing ones leave the refresh to a script; $layouts layouts ship both files"
