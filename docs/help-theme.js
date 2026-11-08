/* Black/white switch for the Xymon help pages; see help-theme.css.
 *
 * Loaded from <head>, so the chosen colours are set before the page is
 * drawn and a white page does not first flash black. The choice is kept in
 * the browser (localStorage), shared by every help page of this server; a
 * browser that refuses storage still switches, for that page only.
 *
 * Plain ASCII, with the button's symbols written as \u escapes: the older
 * help pages declare no character set, and a browser then reads this file in
 * its own default one.
 */
(function () {
	var KEY = "xymon-help-theme";
	var root = document.documentElement;

	function saved() {
		try { return window.localStorage.getItem(KEY); } catch (e) { return null; }
	}
	function save(theme) {
		try { window.localStorage.setItem(KEY, theme); } catch (e) { }
	}
	function isLight() {
		return root.getAttribute("data-theme") === "light";
	}
	function apply(theme) {
		if (theme === "light") root.setAttribute("data-theme", "light");
		else root.removeAttribute("data-theme");
	}

	apply(saved());

	function addButton() {
		if (document.getElementById("help-theme-toggle")) return;
		var b = document.createElement("button");
		b.id = "help-theme-toggle";
		b.type = "button";
		function label() {
			var light = isLight();
			b.textContent = light ? "\u263E Black" : "\u2600 White";
			b.title = light ? "Show the help on a black background"
				: "Show the help on a white background";
			b.setAttribute("aria-pressed", light ? "true" : "false");
		}
		b.onclick = function () {
			var theme = isLight() ? "dark" : "light";
			apply(theme);
			save(theme);
			label();
		};
		label();
		document.body.insertBefore(b, document.body.firstChild);
	}

	if (document.body) addButton();
	else document.addEventListener("DOMContentLoaded", addButton);
})();
