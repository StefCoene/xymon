/* Harness for tests/web/statusicon.sh.
 *
 * Prints the HTML that statusicon() and columnicon() (lib/color.c) return
 * for the cases the pages use, one per line. With the argument "recent" it
 * runs with use_recentgifs set, as xymongen does with --recentgifs.
 */
#include <stdio.h>
#include <string.h>

#include "libxymon.h"

int main(int argc, char *argv[])
{
	use_recentgifs = ((argc > 1) && (strcmp(argv[1], "recent") == 0));

	/* A status that has not changed recently, from the default skin. */
	printf("%s\n", statusicon(NULL, COL_RED, 0, 1, "red", "red"));
	/* A status that changed recently. */
	printf("%s\n", statusicon(NULL, COL_YELLOW, 0, 0, "yellow", "yellow"));
	/* An acknowledged status that changed recently: -ack wins. */
	printf("%s\n", statusicon(NULL, COL_PURPLE, 1, 0, "purple", "purple"));
	/* A per-test skin, as --dialupskin gives, without a TITLE. */
	printf("%s\n", statusicon("/xymon/dialup", COL_GREEN, 0, 1, "green", NULL));
	/* The fixed image of the info column. */
	printf("%s\n", columnicon(NULL, "green.gif", "info", "info", "info"));

	return 0;
}
