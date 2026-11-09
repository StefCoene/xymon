/* The modern Xymon layout's script: a summary bar with a count per colour,
 * where a click shows only the rows with that colour, and a countdown to
 * the next refresh that can be paused. See layout.css and ../README.
 *
 * The counts come from the status icons already on the page: by their
 * xmdot-<colour>, xmdot-recent and xmdot-ack classes where the page has
 * them, or else by the icon's file name (red.gif, yellow-recent.svg,
 * green-ack.png ...), which every Xymon version writes. The column icons
 * (info, trends, client) are not statuses and are not counted.
 *
 * The page headers keep their <meta refresh> inside <noscript> and start a
 * plain reload timer themselves (window.xymonRefreshTimer); this script
 * replaces that timer with the countdown. Plain ASCII on purpose: the pages
 * may be served without a character set.
 */
(function () {
	var COLORS = [
		["red", "Red"], ["yellow", "Yellow"], ["purple", "Purple"],
		["blue", "Blue"], ["clear", "Clear"], ["green", "Green"]
	];

	function hasClass(el, c) {
		return (" " + el.className + " ").indexOf(" " + c + " ") >= 0;
	}
	function el(tag, cls, text) {
		var e = document.createElement(tag);
		if (cls) e.className = cls;
		if (text !== undefined) e.appendChild(document.createTextNode(text));
		return e;
	}

	/* The status an icon shows -- {color, recent, ack} -- or null for an
	 * element that is not a status icon. */
	var NAMES = /(?:^|\/)(red|yellow|purple|blue|clear|green|unknown)(-recent|-ack)?\.(?:gif|svg|png|jpe?g)$/;
	function statusOf(icon) {
		var c, m;
		if (hasClass(icon, "xmdot")) {
			if (hasClass(icon, "xmdot-info") || hasClass(icon, "xmdot-trends") ||
			    hasClass(icon, "xmdot-client")) return null;
			for (c = 0; c < COLORS.length; c++) {
				if (hasClass(icon, "xmdot-" + COLORS[c][0])) {
					return { color: COLORS[c][0], recent: hasClass(icon, "xmdot-recent"),
						ack: hasClass(icon, "xmdot-ack") };
				}
			}
			return { color: "unknown", recent: hasClass(icon, "xmdot-recent"), ack: false };
		}
		if (icon.tagName !== "IMG") return null;
		m = NAMES.exec((icon.getAttribute("src") || "").split("?")[0]);
		if (!m) return null;
		return { color: m[1], recent: m[2] === "-recent", ack: m[2] === "-ack" };
	}
	function statusIcons(scope) {
		var all = (scope || document).querySelectorAll(".xmdot, img"), out = [], i, st;
		for (i = 0; i < all.length; i++) {
			st = statusOf(all[i]);
			if (st) out.push(st);
		}
		return out;
	}

	/* Show only the table rows that hold an icon matching test(status). */
	var activeCard = null;
	function filterRows(card, test) {
		var rows = document.querySelectorAll('table[summary$="Group Block"] tr');
		var i, j, icons, keep;
		if (activeCard) activeCard.className = activeCard.className.replace(" xm-active", "");
		if (activeCard === card) { card = null; test = null; }
		activeCard = card;
		if (card) card.className += " xm-active";
		for (i = 0; i < rows.length; i++) {
			rows[i].className = rows[i].className.replace(" xm-hidden", "");
			if (!test) continue;
			icons = statusIcons(rows[i]);
			if (icons.length === 0) continue;	/* headings stay */
			keep = false;
			for (j = 0; j < icons.length; j++) if (test(icons[j])) { keep = true; break; }
			if (!keep) rows[i].className += " xm-hidden";
		}
	}

	function card(label, n, color, test) {
		var b = el("button", "xm-card" + (n === 0 ? " xm-zero" : ""));
		b.type = "button";
		if (color) b.style.setProperty("--xm-c", "var(--xm-" + color + ")");
		b.appendChild(el("span", "xm-n", String(n)));
		b.appendChild(el("span", "xm-l", label));
		b.title = "Show only the rows with " + label.toLowerCase() + " statuses; click again for all";
		b.onclick = function () { filterRows(b, test); };
		return b;
	}

	function countdown(bar) {
		var secs = window.xymonRefresh;
		if (!secs || secs <= 0) return;
		if (window.xymonRefreshTimer) clearTimeout(window.xymonRefreshTimer);
		var left = secs, paused = false;
		var tool = el("div", "xm-tool");
		var txt = el("span", null, "Refresh in");
		var num = el("span", "xm-count", left + "s");
		var btn = el("button", null, "Pause");
		btn.type = "button";
		btn.onclick = function () {
			paused = !paused;
			btn.firstChild.nodeValue = paused ? "Resume" : "Pause";
			txt.firstChild.nodeValue = paused ? "Paused at" : "Refresh in";
			tool.className = paused ? "xm-tool xm-paused" : "xm-tool";
		};
		tool.appendChild(txt); tool.appendChild(num); tool.appendChild(btn);
		bar.appendChild(tool);
		setInterval(function () {
			if (paused) return;
			left--;
			num.firstChild.nodeValue = left + "s";
			if (left <= 0) window.location.reload();
		}, 1000);
	}

	function init() {
		var counts = {}, recent = 0, acked = 0, i, c, icons;
		for (i = 0; i < COLORS.length; i++) counts[COLORS[i][0]] = 0;
		icons = statusIcons();
		for (i = 0; i < icons.length; i++) {
			if (counts[icons[i].color] !== undefined) counts[icons[i].color]++;
			if (icons[i].recent) recent++;
			if (icons[i].ack) acked++;
		}

		var bar = el("div");
		bar.id = "xm-bar";
		if (icons.length) {
			for (c = 0; c < COLORS.length; c++) {
				(function (name, label) {
					bar.appendChild(card(label, counts[name], name,
						function (st) { return st.color === name; }));
				})(COLORS[c][0], COLORS[c][1]);
			}
			bar.appendChild(card("Recent (24h)", recent, "link",
				function (st) { return st.recent; }));
			bar.appendChild(card("Acked", acked, null,
				function (st) { return st.ack; }));
		}
		bar.appendChild(el("div", "xm-spacer"));
		countdown(bar);

		var top = document.querySelector('table[summary="Topline"]');
		if (top && top.parentNode) top.parentNode.insertBefore(bar, top.nextSibling);
		else document.body.insertBefore(bar, document.body.firstChild);

	}

	if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
	else init();
})();
