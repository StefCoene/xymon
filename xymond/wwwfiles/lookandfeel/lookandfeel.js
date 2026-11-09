/* The Look and feel page: preview a page layout and an icon set on a real
 * Xymon page, then show the xymonsettings.sh commands that make the choice
 * permanent. Nothing here changes the server.
 *
 * The preview fetches the page as the server made it, rewrites in the
 * browser what the choice changes -- the layout directory, the icon
 * directory and the icons' image type -- and shows the result in the frame,
 * with the page's own refresh switched off. Which image type and which
 * column icons a set has is decided as xymonsettings.sh decides it, by
 * asking the server for the files.
 *
 * The icon sets are the classic one (gifs) and those listed in skins/index.txt,
 * the layouts those listed in layouts/index.txt.
 *
 * ICONSTYLE=text -- icons drawn as characters -- is a setting of the
 * programs that write the pages; it is offered only when the installation
 * has it, which shows as span.xmdot rules in xymonbody.css. Its preview
 * turns each icon into the <SPAN> those programs write (lib/color.c), or
 * back; which icons are the info, trends and client columns it reads from
 * the icon's ALT text, which starts with the column's name.
 *
 * Plain ASCII on purpose: the page may be served without a character set.
 */
(function () {
	"use strict";

	var WWW = new URL("../", window.location.href).pathname;	/* e.g. "/xymon/" */
	var SKINS = ["classic"];		/* plus skins/index.txt */
	var LAYOUTS = ["classic"];		/* plus layouts/index.txt */
	var TYPES = ["svg", "png", "gif", "jpg"];
	var STATUS = /^(red|yellow|purple|blue|clear|green|unknown)(-recent|-ack)?$/;
	var COLUMNS = { info: "info", trends: "trends", clientlog: "clientlog", client: "clientlog" };
	/* ICONSTYLE=text, as lib/color.c writes it. */
	var CHARS = { green: "&#x2713;", yellow: "&#x25B2;", red: "&#x2715;", purple: "&#x25C6;",
		clear: "&#x25CB;", blue: "&#x2298;" };
	var COLCHARS = { info: "&#x24D8;", trends: "&#x2197;", client: "&#x2630;" };
	var COLTESTS = { info: "info", trends: "trends", clientlog: "client" };	/* test -> column */
	var textSupported = false;

	var cur = null;		/* what the server uses now, read from a page */
	var probes = {};	/* url -> Promise of whether it exists */
	var pages = {};		/* page -> Promise of its HTML */

	function $(id) { return document.getElementById(id); }
	function esc(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
	function skinDir(name) { return name === "classic" ? WWW + "gifs" : WWW + "skins/" + name; }
	function validName(name) { return /^[A-Za-z0-9_][A-Za-z0-9_.-]*$/.test(name); }

	function exists(url) {
		if (!probes[url]) {
			probes[url] = fetch(url, { method: "HEAD", cache: "no-store", credentials: "same-origin" })
				.then(function (r) { return r.ok; }, function () { return false; });
		}
		return probes[url];
	}

	/* The image type of the set in DIR: the first type it has a green
	 * status icon in, or null when it has none. */
	function typeOf(dir) {
		var i = 0;
		function next() {
			if (i >= TYPES.length) return Promise.resolve(null);
			var t = TYPES[i++];
			return exists(dir + "/green." + t).then(function (ok) { return ok ? t : next(); });
		}
		return next();
	}

	/* What a choice comes to: the icon directory, its image type, and which
	 * column icons it has; a column icon it lacks shows the green one. */
	function target(sel) {
		var dir = skinDir(sel.skin) + (sel.still ? "/static" : "");
		return typeOf(dir).then(function (t) {
			if (!t) {
				throw new Error("the icon set '" + sel.skin + "' has no " +
					(sel.still ? "static variant" : "status icons") + " in " + dir);
			}
			return Promise.all([exists(dir + "/info." + t), exists(dir + "/trends." + t),
					exists(dir + "/clientlog." + t)]).then(function (have) {
				return { dir: dir, type: t, columns: { info: have[0], trends: have[1], clientlog: have[2] } };
			});
		});
	}

	function load(page) {
		if (!pages[page]) {
			pages[page] = fetch(WWW + page, { cache: "no-store", credentials: "same-origin" })
				.then(function (r) {
					if (!r.ok) throw new Error(WWW + page + " answered " + r.status);
					return r.text();
				});
		}
		return pages[page];
	}

	/* The layout and the icon set the server uses, read from a page. */
	function readCurrent(html) {
		var c = { layout: "classic", skin: null, still: false, dir: null, text: false, css: null }, m, re, d;
		m = new RegExp(esc(WWW) + "layouts/([^/\"]+)/layout\\.css").exec(html);
		if (m) c.layout = m[1];
		c.text = /<SPAN CLASS="xmdot[^"]*" ROLE="img"/i.test(html);
		m = /href="([^"]*)\/xymonbody\.css"/i.exec(html);
		if (m) { c.css = m[1] + "/xymonbody.css"; c.dir = m[1]; }
		re = /src="([^"]*)\/([A-Za-z0-9_-]+)\.(?:gif|svg|png|jpe?g)"/gi;
		while ((m = re.exec(html))) {
			if (STATUS.test(m[2])) { c.dir = m[1]; break; }
		}
		if (c.dir) {
			d = c.dir;
			c.still = /\/static$/.test(d);
			if (c.still) d = d.replace(/\/static$/, "");
			if (d === WWW + "gifs") c.skin = "classic";
			else if (d.indexOf(WWW + "skins/") === 0) c.skin = d.substring((WWW + "skins/").length);
		}
		return c;
	}

	function attr(tag, name) {
		var m = new RegExp("\\b" + name + "=\"([^\"]*)\"", "i").exec(tag);
		return m ? m[1] : null;
	}

	function span(classes, label, title, ch, mark) {
		return '<SPAN CLASS="' + classes + '" ROLE="img" ARIA-LABEL="' + label + '"' +
			(title ? ' TITLE="' + title + '"' : "") + ' STYLE="min-width: 16px">' + ch +
			(mark ? '<SPAN CLASS="xmdot-mark">' + mark + "</SPAN>" : "") + "</SPAN>";
	}

	/* Every status and column icon from DIR as ICONSTYLE=text writes it. */
	function imagesToText(html, dir) {
		return html.replace(/<IMG\b[^>]*>/gi, function (tag) {
			var src = attr(tag, "SRC"), alt = attr(tag, "ALT") || "", title = attr(tag, "TITLE"), m, col, kind;
			if (!src || src.indexOf(dir + "/") !== 0) return tag;
			col = COLTESTS[alt.split(":")[0]];
			if (col) return span("xmdot xmdot-" + col, alt, title, COLCHARS[col], null);
			m = /\/([A-Za-z0-9_-]+)\.[a-z]+$/.exec(src);
			if (!m || !(m = STATUS.exec(m[1]))) return tag;
			kind = m[2] === "-ack" ? " xmdot-ack" : (m[2] === "-recent" ? " xmdot-recent" : "");
			return span("xmdot xmdot-" + m[1] + kind, alt, title, CHARS[m[1]] || "?",
				m[2] === "-ack" ? "~" : (m[2] === "-recent" ? "*" : null));
		});
	}

	/* Every ICONSTYLE=text icon as an image from the chosen set. */
	function textToImages(html, tgt) {
		var re = /<SPAN CLASS="(xmdot [^"]*)" ROLE="img" ARIA-LABEL="([^"]*)"(?: TITLE="([^"]*)")? STYLE="[^"]*">[^<]*(?:<SPAN CLASS="xmdot-mark">[^<]*<\/SPAN>)?<\/SPAN>/gi;
		return html.replace(re, function (all, classes, label, title) {
			var cls = " " + classes + " ", name = null, k;
			for (k in COLCHARS) if (cls.indexOf(" xmdot-" + k + " ") >= 0) name = COLUMNS[k];
			if (name) {
				name = tgt.columns[name] ? name : "green";
			} else {
				for (k in CHARS) if (cls.indexOf(" xmdot-" + k + " ") >= 0) name = k;
				if (!name) name = "unknown";
				if (cls.indexOf(" xmdot-ack ") >= 0) name += "-ack";
				else if (cls.indexOf(" xmdot-recent ") >= 0) name += "-recent";
			}
			return '<IMG SRC="' + tgt.dir + "/" + name + "." + tgt.type + '" CLASS="' + classes +
				'" ALT="' + label + '"' + (title ? ' TITLE="' + title + '"' : "") +
				' HEIGHT="16" WIDTH="16" BORDER=0>';
		});
	}

	/* The page as it would look with the choice. */
	function transform(html, sel, tgt) {
		var layout = WWW + "layouts/" + sel.layout + "/", lre;

		/* No refresh in the preview. */
		html = html.replace(/<META HTTP-EQUIV="REFRESH"[^>]*>/gi, "");
		html = html.replace(/var xymonRefresh = parseInt\("[^"]*", 10\)/, "var xymonRefresh = 0");

		/* The layout; a page whose header loads none gets one. */
		lre = new RegExp(esc(WWW) + "layouts/[^/\"]+/", "g");
		if (lre.test(html)) {
			html = html.replace(lre, layout);
		} else {
			html = html.replace(/<\/head>/i,
				'<link rel="stylesheet" type="text/css" href="' + layout + 'layout.css">\n' +
				'<script type="text/javascript" src="' + layout + 'layout.js"></script>\n</head>');
		}

		/* Characters back to images, before the directory is rewritten. */
		if (cur && cur.text && !sel.text) html = textToImages(html, tgt);

		/* Everything from the icon directory: icons in the new set's image
		 * type, the rest -- stylesheet, favicons, backgrounds -- by name. */
		if (cur && cur.dir) {
			html = html.replace(new RegExp(esc(cur.dir) + "/([A-Za-z0-9_.-]+)", "g"), function (all, file) {
				var m = /^(.*)\.(?:gif|svg|png|jpe?g)$/.exec(file), name;
				if (!m || /^bkg-/.test(m[1])) return tgt.dir + "/" + file;
				name = m[1];
				if (COLUMNS[name]) name = tgt.columns[COLUMNS[name]] ? COLUMNS[name] : "green";
				return tgt.dir + "/" + name + "." + tgt.type;
			});
		}

		/* Images to characters, from the new directory. */
		if (sel.text && !(cur && cur.text)) html = imagesToText(html, tgt.dir);

		/* Relative links resolve as on the real page. */
		return html.replace(/<head>/i, '<head>\n<base href="' + WWW + sel.page + '">');
	}

	function textChosen() {
		return textSupported && $("lf-style").value === "text";
	}

	/* With characters the hidden icon controls do not count: the set and
	 * its animation stay as the server has them. */
	function selection() {
		var text = textChosen();
		return {
			page: $("lf-page").value,
			layout: $("lf-layout").value,
			skin: text ? (cur.skin || "classic") : $("lf-skin").value,
			still: text ? cur.still : !$("lf-anim").checked,
			text: text
		};
	}

	function showError(e) {
		$("lf-error").textContent = String(e && e.message ? e.message : e);
		$("lf-error").hidden = false;
	}

	function option(sel, value, label) {
		var o = document.createElement("option");
		o.value = value;
		o.textContent = label || value;
		sel.appendChild(o);
		return o;
	}

	/* The icon set and its animation are choices for images only: with
	 * characters they are hidden. The animation can be switched off only
	 * when the chosen set has a static variant. */
	function updateAnimation() {
		var skin = $("lf-skin").value;
		$("lf-image-box").hidden = textChosen();
		return typeOf(skinDir(skin) + "/static").then(function (t) {
			var box = $("lf-anim");
			box.disabled = !t;
			if (!t) box.checked = true;
			$("lf-anim-note").textContent =
				t ? "" : "This set has no static variant: its icons move where they move.";
		});
	}

	function update() {
		var sel = selection();
		$("lf-error").hidden = true;
		$("lf-saved").hidden = true;
		return Promise.all([load(sel.page), target(sel)]).then(function (r) {
			$("lf-frame").srcdoc = transform(r[0], sel, r[1]);
		}).catch(showError);
	}

	function commands(sel) {
		var out = [];
		if (sel.layout !== cur.layout) out.push("xymonsettings.sh layout " + sel.layout);
		if (!sel.text && sel.skin !== cur.skin) out.push("xymonsettings.sh skin " + sel.skin);
		if (!sel.text && (sel.skin !== cur.skin || sel.still !== cur.still)) {
			out.push("xymonsettings.sh animation " + (sel.still ? "off" : "on"));
		}
		if (sel.text !== cur.text) out.push("xymonsettings.sh -a set ICONSTYLE=" + (sel.text ? "text" : "image"));
		if (!out.length) out.push("# Nothing to change: the server already uses this.");
		return out.join("\n");
	}

	function copy() {
		var text = $("lf-cmds").textContent, range;
		if (navigator.clipboard && window.isSecureContext) {
			navigator.clipboard.writeText(text).catch(showError);
			return;
		}
		range = document.createRange();
		range.selectNodeContents($("lf-cmds"));
		window.getSelection().removeAllRanges();
		window.getSelection().addRange(range);
		try { document.execCommand("copy"); } catch (e) { showError("select the commands and copy them by hand"); }
	}

	function addSkin() {
		var name = $("lf-other").value.trim();
		if (!validName(name)) { showError("'" + name + "' is not a directory name"); return; }
		typeOf(skinDir(name)).then(function (t) {
			if (!t) { showError("there is no icon set in " + skinDir(name)); return; }
			var sel = $("lf-skin"), i;
			for (i = 0; i < sel.options.length; i++) if (sel.options[i].value === name) break;
			if (i === sel.options.length) option(sel, name);
			sel.value = name;
			$("lf-other").value = "";
			updateAnimation().then(update);
		});
	}

	/* The names listed in DIR/index.txt, one per line. */
	function listed(dir) {
		return fetch(WWW + dir + "/index.txt", { cache: "no-store", credentials: "same-origin" })
			.then(function (r) { return r.ok ? r.text() : ""; }, function () { return ""; })
			.then(function (t) {
				return t.split("\n").map(function (l) { return l.trim(); })
					.filter(function (l) { return l && l.charAt(0) !== "#" && validName(l); });
			});
	}

	/* Whether this installation has ICONSTYLE=text: its body stylesheet
	 * then styles the characters. */
	function hasTextStyle(css) {
		if (!css) return Promise.resolve(false);
		return fetch(css, { cache: "no-store", credentials: "same-origin" })
			.then(function (r) { return r.ok ? r.text() : ""; }, function () { return ""; })
			.then(function (t) { return t.indexOf("span.xmdot") >= 0; });
	}

	function init() {
		Promise.all([load("xymon.html"), listed("skins"), listed("layouts")]).then(function (r) {
			var html = r[0], l = $("lf-layout"), s = $("lf-skin"), i;
			SKINS = SKINS.concat(r[1].filter(function (n) { return n !== "classic"; }));
			LAYOUTS = LAYOUTS.concat(r[2].filter(function (n) { return n !== "classic"; }));
			cur = readCurrent(html);
			for (i = 0; i < LAYOUTS.length; i++) option(l, LAYOUTS[i]);
			if (LAYOUTS.indexOf(cur.layout) < 0) option(l, cur.layout);
			l.value = cur.layout;
			for (i = 0; i < SKINS.length; i++) option(s, SKINS[i]);
			if (cur.skin && SKINS.indexOf(cur.skin) < 0) option(s, cur.skin);
			s.value = cur.skin || "classic";
			$("lf-anim").checked = !cur.still;
			$("lf-style").value = cur.text ? "text" : "image";
			$("lf-current").textContent = "The server uses now: layout " + cur.layout + ", icons " +
				(cur.skin || "from " + cur.dir) + (cur.still ? ", standing still." : ", animated.");
			if (cur.text) $("lf-current").textContent += " Icons drawn as characters.";
			if (!cur.dir) $("lf-current").textContent += " (No icon directory found on the main page.)";
			return hasTextStyle(cur.css).then(function (yes) {
				textSupported = yes || cur.text;
				$("lf-style-box").hidden = !textSupported;
			}).then(updateAnimation);
		}).then(update).catch(showError);

		$("lf-page").onchange = update;
		$("lf-layout").onchange = update;
		$("lf-skin").onchange = function () { updateAnimation().then(update); };
		$("lf-anim").onchange = update;
		$("lf-style").onchange = function () { updateAnimation().then(update); };
		$("lf-add").onclick = addSkin;
		$("lf-save").onclick = function () {
			if (!cur) return;
			$("lf-cmds").textContent = commands(selection());
			$("lf-saved").hidden = false;
		};
		$("lf-copy").onclick = copy;
	}

	/* For tests and for a curious reader's console. */
	window.lookAndFeel = { readCurrent: readCurrent, transform: transform, commands: commands,
		imagesToText: imagesToText, textToImages: textToImages,
		setCurrent: function (c) { cur = c; } };

	if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
	else init();
})();
