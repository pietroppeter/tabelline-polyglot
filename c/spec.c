/* Layer 1: a whole table as JSON (a file, or stdin), rendered in one call. */
#include <stdio.h>
#include <stdlib.h>
#include "tabelline.h"

int main(int argc, char **argv) {
  FILE *f = argc > 1 ? fopen(argv[1], "rb") : stdin;
  if (!f) { perror(argv[1]); return 1; }
  size_t cap = 1 << 16, len = 0, got;
  char *spec = malloc(cap);
  while ((got = fread(spec + len, 1, cap - len - 1, f)) > 0) {
    len += got;
    if (len + 1 == cap) spec = realloc(spec, cap *= 2);
  }
  spec[len] = '\0';
  char *out = tbl_render_spec(spec, argc > 2 ? argv[2] : "html");
  if (!out) { fprintf(stderr, "tabelline: %s\n", tbl_error()); return 1; }
  fputs(out, stdout);
  tbl_free(out);
  free(spec);
  return 0;
}
