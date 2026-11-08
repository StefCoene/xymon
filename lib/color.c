/*----------------------------------------------------------------------------*/
/* Xymon monitor library.                                                     */
/*                                                                            */
/* This is a library module, part of libxymon.                                */
/* It contains routines for color <-> string conversion                       */
/*                                                                            */
/* Copyright (C) 2002-2011 Henrik Storner <henrik@storner.dk>                 */
/*                                                                            */
/* This program is released under the GNU General Public License (GPL),       */
/* version 2. See the file "COPYING" for details.                             */
/*                                                                            */
/*----------------------------------------------------------------------------*/

static char rcsid[] = "$Id$";

#include <string.h>
#include <stdlib.h>

#include "libxymon.h"

int use_recentgifs = 0;

char *colorname(int color)
{
	static char *cs = "";

	switch (color) {
	  case COL_CLEAR:  cs = "clear"; break;
	  case COL_BLUE:   cs = "blue"; break;
	  case COL_PURPLE: cs = "purple"; break;
	  case COL_GREEN:  cs = "green"; break;
	  case COL_YELLOW: cs = "yellow"; break;
	  case COL_RED:    cs = "red"; break;
	  default:
			   cs = "unknown";
			   break;
	}

	return cs;
}

int parse_color(char *colortext)
{
	char inpcolor[10];
	int n;

	if (!colortext) return -1;

	MEMDEFINE(inpcolor);

	strncpy(inpcolor, colortext, 7);
	inpcolor[7] = '\0';
	n = strspn(inpcolor, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
	inpcolor[n] = '\0';
	strncat(inpcolor, " ", sizeof(inpcolor)-strlen(inpcolor));

	if (strncasecmp(inpcolor, "green ", 6) == 0) {
		MEMUNDEFINE(inpcolor);
		return COL_GREEN;
	}
	else if (strncasecmp(inpcolor, "yellow ", 7) == 0) {
		MEMUNDEFINE(inpcolor);
		return COL_YELLOW;
	}
	else if (strncasecmp(inpcolor, "red ", 4) == 0) {
		MEMUNDEFINE(inpcolor);
		return COL_RED;
	}
	else if (strncasecmp(inpcolor, "blue ", 5) == 0) {
		MEMUNDEFINE(inpcolor);
		return COL_BLUE;
	}
	else if (strncasecmp(inpcolor, "clear ", 6) == 0) {
		MEMUNDEFINE(inpcolor);
		return COL_CLEAR;
	}
	else if (strncasecmp(inpcolor, "purple ", 7) == 0) {
		MEMUNDEFINE(inpcolor);
		return COL_PURPLE;
	}
	else if (strncasecmp(inpcolor, "client ", 7) == 0) {
		MEMUNDEFINE(inpcolor);
		return COL_CLIENT;
	}

	MEMUNDEFINE(inpcolor);
	return -1;
}

int eventcolor(char *colortext)
{
	if (!colortext) return -1;

	if 	(strcmp(colortext, "cl") == 0)	return COL_CLEAR;
	else if (strcmp(colortext, "bl") == 0)	return COL_BLUE;
	else if (strcmp(colortext, "pu") == 0)	return COL_PURPLE;
	else if (strcmp(colortext, "gr") == 0)	return COL_GREEN;
	else if (strcmp(colortext, "ye") == 0)	return COL_YELLOW;
	else if (strcmp(colortext, "re") == 0)	return COL_RED;
	else return -1;
}

char *dotgiffilename(int color, int acked, int oldage)
{
	static char *filename = NULL; /* yellow-recent.gif */
	unsigned int bytesleft = 1024; /* Max length of a the gif-file, without path */

	/* Allocate the first time, never free */
	if (filename == NULL) filename = (char *)malloc(bytesleft);

	strncpy(filename, colorname(color), bytesleft); bytesleft -= strlen(filename);
	if (acked) {
		strncat(filename, "-ack", bytesleft); bytesleft -= 4;
	}
	else if (use_recentgifs) {
		strncat(filename, (oldage ? "" : "-recent"), bytesleft); bytesleft -= 7;
	}
	snprintf(filename+strlen(filename), bytesleft, ".%s", xgetenv("IMAGEFILETYPE"));

	return filename;
}

/*
 * Every icon on a Xymon page is written by statusicon() or columnicon(),
 * so the pages carry one form of it. The CLASS names it "xmdot", then
 * what it shows: "xmdot-<colour>" plus "xmdot-recent" or "xmdot-ack" for
 * a status, as dotgiffilename() picks the image, or "xmdot-<column>" for
 * the fixed image of the info, trends and client columns. A stylesheet
 * can then address every icon, or one kind, without knowing the image
 * file names. The names carry the prefix because the bare colour names
 * are taken: xymonbody.css gives .green, .red and so on the page
 * background image, which would show through every icon.
 *
 * With ICONSTYLE=text the icon is a character in a SPAN instead of an
 * image, coloured by the classes in xymonbody.css. The character is
 * written as a numeric character reference, not as UTF-8: the header
 * templates declare no charset, so raw UTF-8 bytes could arrive garbled.
 * A recent change adds a "*", an acknowledgement a "~", so the state
 * survives when the text is copied out of the page.
 *
 * alttext and titletext go into the tag as given: callers pass text that
 * is already safe in an attribute. A NULL titletext leaves TITLE out.
 * The result is in a static buffer, overwritten by the next call.
 */
static char *iconhtml(char *skin, char *imgfile, char *classes, char *textchar, char *textmark,
		      char *alttext, char *titletext)
{
	static strbuffer_t *result = NULL;

	if (result == NULL) result = newstrbuffer(0); else clearstrbuffer(result);

	if (strcmp(xgetenv("ICONSTYLE"), "text") == 0) {
		addtobuffer_many(result, "<SPAN CLASS=\"", classes, "\" ROLE=\"img\" ARIA-LABEL=\"", alttext, "\"", NULL);
		if (titletext) addtobuffer_many(result, " TITLE=\"", titletext, "\"", NULL);
		addtobuffer_many(result, " STYLE=\"min-width: ", xgetenv("DOTWIDTH"), "px\">", textchar, NULL);
		if (textmark) addtobuffer_many(result, "<SPAN CLASS=\"xmdot-mark\">", textmark, "</SPAN>", NULL);
		addtobuffer(result, "</SPAN>");

		return STRBUF(result);
	}

	addtobuffer_many(result, "<IMG SRC=\"", (skin ? skin : xgetenv("XYMONSKIN")), "/", imgfile,
			 "\" CLASS=\"", classes, "\" ALT=\"", alttext, "\"", NULL);
	if (titletext) addtobuffer_many(result, " TITLE=\"", titletext, "\"", NULL);
	addtobuffer_many(result, " HEIGHT=\"", xgetenv("DOTHEIGHT"),
			 "\" WIDTH=\"", xgetenv("DOTWIDTH"), "\" BORDER=0>", NULL);

	return STRBUF(result);
}

char *statusicon(char *skin, int color, int acked, int oldage, char *alttext, char *titletext)
{
	char classes[64];
	char *textchar, *textmark = NULL;

	switch (color) {
	  case COL_GREEN:  textchar = "&#x2713;"; break;	/* check mark */
	  case COL_YELLOW: textchar = "&#x25B2;"; break;	/* black up-pointing triangle */
	  case COL_RED:    textchar = "&#x2715;"; break;	/* multiplication x */
	  case COL_PURPLE: textchar = "&#x25C6;"; break;	/* black diamond */
	  case COL_CLEAR:  textchar = "&#x25CB;"; break;	/* white circle */
	  case COL_BLUE:   textchar = "&#x2298;"; break;	/* circled division slash */
	  default:         textchar = "?"; break;
	}

	if (acked) textmark = "~";
	else if (use_recentgifs && !oldage) textmark = "*";

	snprintf(classes, sizeof(classes), "xmdot xmdot-%s%s", colorname(color),
		 (acked ? " xmdot-ack" : ((use_recentgifs && !oldage) ? " xmdot-recent" : "")));

	return iconhtml(skin, dotgiffilename(color, acked, oldage), classes, textchar, textmark,
			alttext, titletext);
}

char *columnicon(char *skin, char *imgfile, char *column, char *alttext, char *titletext)
{
	char classes[64];
	char *textchar;

	/* Not a status, so not a status character: a green check here would read as one. */
	if (strcmp(column, "info") == 0) textchar = "&#x24D8;";		/* circled latin small i */
	else if (strcmp(column, "trends") == 0) textchar = "&#x2197;";	/* north east arrow */
	else if (strcmp(column, "client") == 0) textchar = "&#x2630;";	/* trigram for heaven */
	else textchar = "&#x2022;";					/* bullet */

	snprintf(classes, sizeof(classes), "xmdot xmdot-%s", column);

	return iconhtml(skin, imgfile, classes, textchar, NULL, alttext, titletext);
}

#ifndef CLIENTONLY
int colorset(char *colspec, int excludeset)
{
	char *cspeccopy = strdup(colspec);
	int c, ac;
	char *p;
	char *pp = NULL;

	p = strtok_r(cspeccopy, ",", &pp);
	ac = 0;
	while (p) {
		c = parse_color(p);
		if (c != -1) ac = (ac | (1 << c));
		p = strtok_r(NULL, ",", &pp);
	}
	xfree(cspeccopy);

	/* Some color may be forbidden */
	ac = (ac & ~excludeset);
	return ac;
}
#endif

