#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/web/skins-installed.sh
#
# The skins shipped under xymond/wwwfiles/skins/ are complete once
# installed. Pointing XYMONSKIN at one, with IMAGEFILETYPE=svg, makes every
# page ask that directory for each status icon, the event-log arrow and the
# graph zoom icon, and for the backgrounds, favicons and xymonbody.css the
# default "gifs" directory holds. A missing file is a broken image on a
# live page, so each installed skin is checked against the installed gifs:
# every icon there as an SVG of the same name, and every other file there
# reachable, with the same content, through the skin's links. The SVGs are
# served as pages' images, so none may carry a script.
#
# The info, trends and client columns are not tests, so the shipped
# xymonserver.cfg gives each its own icon instead of the green status one;
# each of INFOCOLUMNGIF, TRENDSCOLUMNGIF and CLIENTCOLUMNGIF must name such
# an icon that the install put in gifs, or those columns show a broken image.
#
# Installed for real into a scratch tree, as install-empty-ext-dir.sh does
# and for the same reasons, so the links are checked where they land.

set -euo pipefail
# shellcheck source=tests/lib/assert.sh
. "$(dirname "$0")/../lib/assert.sh"

ROOT=$(find_root)
PATH=$PATH:/usr/sbin:/sbin
require_gnu_make
[ -f "$ROOT/Makefile" ] || skip "requires a configured source tree with a top-level Makefile"
require_bin XYMOND xymond/xymond

work=$(mktempdir)
dest=$work/inst
vars=(
	INSTALLROOT= PKGBUILD=1
	XYMONUSER="$(id -un)" HTTPDGID="$(id -gn)"
	XYMONTOPDIR="$dest/top" XYMONHOME="$dest/top/server" XYMONVAR="$dest/var"
	CGIDIR="$dest/top/cgi-bin" SECURECGIDIR="$dest/top/cgi-secure"
	XYMONLOGDIR="$dest/log" MANROOT="$dest/man"
	INSTALLBINDIR="$dest/top/server/bin" INSTALLETCDIR="$dest/etc"
	INSTALLEXTDIR="$dest/top/server/ext" INSTALLTMPDIR="$dest/var/tmp"
	INSTALLWEBDIR="$dest/etc/web" INSTALLWWWDIR="$dest/var/www"
)

"$XYMON_MAKE" -C "$ROOT" install "${vars[@]}" >"$work/install.log" 2>&1 \
	|| fail "a full install into a scratch tree failed: $(tail -n 5 "$work/install.log")"

gifs=$dest/var/www/gifs
[ -d "$gifs" ] || fail "the install did not create $gifs"

cfg=$dest/etc/xymonserver.cfg
[ -f "$cfg" ] || fail "the install did not create $cfg"
for var in INFOCOLUMNGIF TRENDSCOLUMNGIF CLIENTCOLUMNGIF; do
	val=$(sed -n "s/^$var=\"\([^\"]*\)\".*/\1/p" "$cfg")
	[ -n "$val" ] || fail "the installed xymonserver.cfg sets no $var"
	case "$val" in
	green.*|yellow.*|red.*|purple.*|clear.*|blue.*|unknown.*|*-recent.*|*-ack.*)
		fail "$var=\"$val\" in the installed xymonserver.cfg is a status icon, not one for that column" ;;
	esac
	[ -f "$gifs/$val" ] || fail "$var=\"$val\" in the installed xymonserver.cfg, but the install put no $val in gifs"
done

skins=$(cd "$ROOT/xymond/wwwfiles/skins" && for d in */; do printf '%s\n' "${d%/}"; done)
[ -n "$skins" ] || fail "no skin directories under xymond/wwwfiles/skins"

checked=0
for s in $skins; do
	dir=$dest/var/www/skins/$s
	[ -d "$dir" ] || fail "skin '$s' was not installed at $dir"

	for f in "$gifs"/*; do
		name=${f##*/}
		case "$name" in
		README) ;;
		bkg-*|favicon-*|xymonbody.css)
			[ -e "$dir/$name" ] || fail "skin '$s' has no working $name: the page would ask $dir/$name"
			cmp -s "$f" "$dir/$name" || fail "skin '$s' $name differs from the one in gifs"
			;;
		*.gif)
			svg=$dir/${name%.gif}.svg
			[ -f "$svg" ] || fail "skin '$s' has no ${name%.gif}.svg, the icon gifs has as $name"
			grep -q '<svg' "$svg" || fail "skin '$s' ${svg##*/} is not an SVG image"
			if grep -qi '<script' "$svg"; then fail "skin '$s' ${svg##*/} carries a script"; fi
			checked=$((checked + 1))
			;;
		esac
	done
done

pass "the info, trends and client columns have their own installed icon, and every installed skin has all $checked icons in SVG and reaches the backgrounds, favicons and stylesheet of gifs"
