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
# served as pages' images, so none may carry a script. An icon that moves in
# gifs -- an animated GIF, which carries a NETSCAPE2.0 loop block -- moves in
# every skin too, with a CSS animation, and every animation stops when the
# browser asks for reduced motion.
#
# Every set -- gifs and each skin -- has a "static" directory beside its
# icons for pages that should not move: complete in the same way, and with
# nothing in it that moves, neither a GIF with a loop block nor an SVG with
# an animation.
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

# check_set DIR LABEL EXT STILL -- every icon gifs has, as DIR/NAME.EXT,
# and every background, favicon and the stylesheet with the content gifs
# has. With STILL=1 nothing in DIR may move.
checked=0
check_set() {
	local dir=$1 label=$2 ext=$3 still=$4 f name icon
	[ -d "$dir" ] || fail "$label was not installed at $dir"
	for f in "$gifs"/*; do
		name=${f##*/}
		case "$name" in
		README|static) ;;
		bkg-*|favicon-*|xymonbody.css)
			[ -e "$dir/$name" ] || fail "$label has no working $name: the page would ask $dir/$name"
			cmp -s "$f" "$dir/$name" || fail "$label $name differs from the one in gifs"
			;;
		*.gif)
			icon=$dir/${name%.gif}.$ext
			[ -f "$icon" ] || fail "$label has no ${icon##*/}, the icon gifs has as $name"
			if [ "$ext" = svg ]; then
				grep -q '<svg' "$icon" || fail "$label ${icon##*/} is not an SVG image"
				if grep -qi '<script' "$icon"; then fail "$label ${icon##*/} carries a script"; fi
				if [ "$still" = 0 ] && grep -q NETSCAPE2.0 "$f" && ! grep -q '@keyframes' "$icon"; then
					fail "$label ${icon##*/} stands still, while $name in gifs moves"
				fi
				if grep -q '@keyframes' "$icon"; then
					[ "$still" = 0 ] || fail "$label ${icon##*/} moves, in a set that should stand still"
					grep -q 'prefers-reduced-motion' "$icon" \
						|| fail "$label ${icon##*/} moves, but does not stop for prefers-reduced-motion"
				fi
			elif [ "$still" = 1 ] && grep -q NETSCAPE2.0 "$icon"; then
				fail "$label ${icon##*/} is an animated GIF, in a set that should stand still"
			fi
			checked=$((checked + 1))
			;;
		esac
	done
}

check_set "$gifs/static" "gifs/static" gif 1

skins=$(cd "$ROOT/xymond/wwwfiles/skins" && for d in */; do printf '%s\n' "${d%/}"; done)
[ -n "$skins" ] || fail "no skin directories under xymond/wwwfiles/skins"
for s in $skins; do
	check_set "$dest/var/www/skins/$s" "skin '$s'" svg 0
	check_set "$dest/var/www/skins/$s/static" "skin '$s/static'" svg 1
done

pass "the info, trends and client columns have their own installed icon; every skin has every icon of gifs in SVG, moving where gifs moves, and every set has a complete static variant that does not move ($checked icons checked)"
