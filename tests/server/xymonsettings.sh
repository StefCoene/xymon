#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/server/xymonsettings.sh
#
# xymonsettings reads and changes settings in xymonserver.cfg on an
# installed server. Both work with the value a Xymon program sees: the
# loader (loadenv, sanitize_input in lib/) takes a backslash as an escape,
# a '#' outside quotes as a comment and strips one pair of quotes, so "get"
# undoes that and "set" writes the escapes a value needs. "$NAME" is left
# unexpanded. "set" rewrites the NAME= lines in place and leaves every other
# line, the comment after the value, the file's mode and a symlink to it as
# they were.
# It refuses a name the file does not have unless -a is given, so a typo does
# not add a setting nothing reads, and it checks every assignment before it
# changes anything, so one bad assignment leaves the file untouched, and it
# writes the file before it prints what changed, so a reader that stops
# reading early does not stop the change. What it
# writes is read back through xymoncmd, the loader every Xymon program uses,
# so a value xymond would see differently fails here.
#
# Run on a copy of the shipped xymonserver.cfg.DIST, through /bin/sh, as an
# administrator would run the installed script.

set -euo pipefail
# shellcheck source=tests/lib/assert.sh
. "$(dirname "$0")/../lib/assert.sh"

require_cfg SETTINGS_DIST "xymond/xymonsettings.sh.DIST"
require_cfg SERVERCFG_DIST "xymond/etcfiles/xymonserver.cfg.DIST"
require_bin XYMONCMD common/xymoncmd

work=$(mktempdir)
sed -e "s!@XYMONHOME@!$work!g" "$SETTINGS_DIST" >"$work/xymonsettings.sh"
chmod 755 "$work/xymonsettings.sh"
mkdir "$work/etc"
cfg=$work/etc/xymonserver.cfg
cp "$SERVERCFG_DIST" "$cfg"
printf 'export EXPORTED=old\t# kept\n' >>"$cfg"
cp "$cfg" "$work/orig.cfg"

xs() { /bin/sh "$work/xymonsettings.sh" "$@"; }
# xymoncmd expands "$NAME" in its own arguments before it loads the file,
# so the loaded value is taken from the environment it hands to env.
loaded() { "$XYMONCMD" --env="$cfg" env | sed -n "s/^$1=//p"; }

# get: the value as written, without expanding it, from the default file.
got=$(XYMONHOME=$work xs get XYMONSKIN)
assert_equal '$XYMONSERVERWWWURL/gifs' "$got" "get XYMONSKIN from \$XYMONHOME/etc/xymonserver.cfg"
got=$(xs -c "$cfg" get PINGCOLUMN TRENDSCOLUMN)
assert_equal "PINGCOLUMN=conn
TRENDSCOLUMN=trends" "$got" "get with two names prints NAME=VALUE lines"
st=0; xs -c "$cfg" get NOSUCHSETTING >/dev/null 2>&1 || st=$?
assert_equal 1 "$st" "get of a name the file does not have"
got=$(xs -c "$cfg" get XYMONPAGEACKFONT)
assert_equal 'COLOR="#33ebf4" SIZE="-1"' "$got" "get unescapes the quotes and keeps the '#' inside them"

# set: rewrites the lines, keeps the comment, touches nothing else.
chmod 640 "$cfg"
ln -s "$cfg" "$work/link.cfg"
xs -c "$work/link.cfg" set PINGCOLUMN=ping 'IMAGEFILETYPE=svg' 'EXPORTED=a b\c' \
	'XYMONPAGEACKFONT=COLOR="#ff0000" it'"'"'s' >/dev/null
[ -L "$work/link.cfg" ] || fail "set replaced the symlink it was given with a file"
mode=$(ls -l "$cfg" | cut -c1-10)
assert_equal "-rw-r-----" "$mode" "set kept the file's mode"
assert_contains 'PINGCOLUMN="ping"		# Column where the ping-test reports results.' "$(cat "$cfg")" \
	"set kept the comment after PINGCOLUMN"
assert_contains $'export EXPORTED="a b\\\\c"\t# kept' "$(cat "$cfg")" \
	"set kept 'export' and the comment on an exported line"
changed=$(diff "$work/orig.cfg" "$cfg" | grep -c '^>' || true)
assert_equal 4 "$changed" "set changed exactly the four lines it was given"
assert_equal ping "$(loaded PINGCOLUMN)" "xymoncmd reads the new PINGCOLUMN"
assert_equal svg "$(loaded IMAGEFILETYPE)" "xymoncmd reads the new IMAGEFILETYPE"
assert_equal 'a b\c' "$(loaded EXPORTED)" "xymoncmd reads a value with a space and a backslash as given"
assert_equal 'COLOR="#ff0000" it'"'"'s' "$(loaded XYMONPAGEACKFONT)" \
	"xymoncmd reads a value with quotes, a '#' and an apostrophe as given"
assert_equal 'COLOR="#ff0000" it'"'"'s' "$(xs -c "$cfg" get XYMONPAGEACKFONT)" "get reads back what set wrote"

# A typo or a bad name: nothing changes, not even the good ones.
cp "$cfg" "$work/before.cfg"
st=0; xs -c "$cfg" set PINGCOLUMN=conn IMAGEFILETYP=gif >/dev/null 2>&1 || st=$?
assert_equal 1 "$st" "set with a misspelt name"
cmp -s "$work/before.cfg" "$cfg" || fail "set applied PINGCOLUMN although IMAGEFILETYP after it was refused"
st=0; xs -c "$cfg" set '1BAD=x' >/dev/null 2>&1 || st=$?
assert_equal 1 "$st" "set with a name that is not a variable name"
cmp -s "$work/before.cfg" "$cfg" || fail "a refused set changed the file"

# A reader that stops early -- here one that reads nothing -- cannot stop
# the change: the file is written before anything is printed.
xs -c "$cfg" set PINGCOLUMN=early | true || :
assert_equal early "$(loaded PINGCOLUMN)" "set applied its change although nothing read what it printed"

# -a adds a name the file does not have yet.
xs -c "$cfg" -a set NEWSETTING=added >/dev/null
assert_equal added "$(loaded NEWSETTING)" "xymoncmd reads a setting added with -a"

leftover=$(cd "$work/etc" && ls | grep -v '^xymonserver.cfg$' || true)
[ -z "$leftover" ] || fail "set left files behind next to the config: $leftover"

pass "xymonsettings reads values unexpanded, and changes only the lines asked for, as xymoncmd then reads them, or nothing at all"
