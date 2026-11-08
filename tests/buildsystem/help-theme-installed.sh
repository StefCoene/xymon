#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/buildsystem/help-theme-installed.sh
#
# Every installed help page links help-theme.css and help-theme.js, and finds
# them where it looks. The two files give the help the black background of
# the Xymon pages and the button that switches it to white
# (docs/help-theme.css). A page that does not link them is the one white page
# among black ones, without the switch; a link that misses -- the manual
# pages sit two directories deeper, help/manpages/manN/, and the man-page
# index one deeper -- is the same page plus a 404 in the server log.
#
# The guides in docs/ carry the links in their own <head>; the manual pages
# get them from build/manpage-html.py, which makehtml.sh runs on mandoc's
# output, so a page generated from a new source has them too.
#
# Installed for real with docs/Makefile, from a copy of docs/, so the paths
# are checked where they land. No configured tree is needed.

set -euo pipefail
# shellcheck source=tests/lib/assert.sh
. "$(dirname "$0")/../lib/assert.sh"

ROOT=$(find_root)
require_gnu_make
[ -f "$ROOT/docs/help-theme.css" ] || fail "docs/help-theme.css is missing"
[ -f "$ROOT/docs/help-theme.js" ] || fail "docs/help-theme.js is missing"
# The older guides declare no character set and the server sends none, so a
# browser reads the two files in its own default one: any byte outside ASCII
# would show as two or three wrong characters, as the button's symbol once did.
for f in help-theme.css help-theme.js; do
	bad=$(LC_ALL=C grep -n '[^[:print:][:space:]]' "$ROOT/docs/$f" || true)
	[ -z "$bad" ] || fail "docs/$f is not plain ASCII, which a page without a charset misreads: $bad"
done

work=$(mktempdir)
cp -R "$ROOT/docs" "$work/docs"
www=$work/www
"$XYMON_MAKE" -C "$work/docs" all install INSTALLROOT= PKGBUILD=1 \
	INSTALLSTATICWWWDIR="$www" INSTALLWWWDIR="$www" INSTALLETCDIR=/etc/xymon \
	CGIDIR=/cgi SECURECGIDIR=/secure-cgi XYMONHOSTURL=/xymon \
	XYMONCGIURL=/xymon-cgi SECUREXYMONCGIURL=/xymon-seccgi \
	>"$work/make.log" 2>&1 \
	|| fail "installing docs/ failed: $(tail -n 5 "$work/make.log")"

help=$www/help
[ -d "$help" ] || fail "the install did not create $help"

pages=0
manpages=0
for page in $(cd "$help" && find . -name '*.html' | sort); do
	page=${page#./}
	dir=$(dirname "$help/$page")
	for kind in css js; do
		refs=$(grep -o -E "(href|src)=\"[^\"]*help-theme\.$kind\"" "$help/$page" || true)
		ref=$(first_line "$refs" | sed -e 's/^[a-z]*="//' -e 's/"$//')
		[ -n "$ref" ] || fail "help/$page does not link help-theme.$kind"
		[ -f "$dir/$ref" ] || fail "help/$page links help-theme.$kind as $ref, which is not there"
	done
	pages=$((pages + 1))
	case "$page" in manpages/man*/*) manpages=$((manpages + 1)) ;; esac
done

[ "$pages" -gt 0 ] || fail "no help pages were installed under $help"
[ "$manpages" -gt 0 ] || fail "no manual pages were installed under $help/manpages"

pass "all $pages installed help pages, $manpages of them manual pages, link help-theme.css and help-theme.js where they are"
