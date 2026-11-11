/* libtabelline: tabelline (great tables for Nim) behind a C ABI.
 *
 * Layer 1, one call: the whole table as JSON in, the rendered table out.
 *   char *html = tbl_render_spec("{\"data\": {\"dataset\": \"planets\"}, \"verbs\": [...]}", "html");
 *
 * Layer 2, a table you build: typed columns, the stub, one verb at a time.
 *   tbl_table *t = tbl_new();
 *   tbl_add_strings(t, "planet", names, 8);
 *   tbl_add_doubles(t, "mass", mass, 8);
 *   tbl_set(t, "rownameCol", "planet");
 *   tbl_verb(t, "tabHeader", "[\"The planets\"]");
 *   tbl_verb(t, "fmtNumber", "{\"columns\": \"mass\", \"decimals\": 3}");
 *   char *html = tbl_render(t, "html");
 *   tbl_free(html); tbl_drop(t);
 *
 * Formats: "html", "page" (a whole HTML page), "text", "markdown".
 * Verb and argument names ignore case and underscores: "fmt_number" is "fmtNumber".
 * On error a call returns NULL (or -1) and tbl_error() says why.
 * Every char * the library returns is freed with tbl_free.
 */
#ifndef TABELLINE_H
#define TABELLINE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tbl_table tbl_table;

const char *tbl_version(void);
const char *tbl_error(void);
void tbl_free(char *s);

/* layer 1 */
char *tbl_render_spec(const char *spec_json, const char *format);
char *tbl_verbs(void); /* every verb form, as JSON */

/* layer 2 */
tbl_table *tbl_new(void);
void tbl_drop(tbl_table *t);
int tbl_add_doubles(tbl_table *t, const char *name, const double *values, size_t n);   /* NaN: missing */
int tbl_add_ints(tbl_table *t, const char *name, const int64_t *values, size_t n);
int tbl_add_bools(tbl_table *t, const char *name, const uint8_t *values, size_t n);
int tbl_add_strings(tbl_table *t, const char *name, const char *const *values, size_t n); /* NULL: missing */
int tbl_add_json(tbl_table *t, const char *name, const char *values_json);
int tbl_set(tbl_table *t, const char *key, const char *value); /* rownameCol, groupnameCol, id, locale */
int tbl_verb(tbl_table *t, const char *verb, const char *args_json);
char *tbl_render(tbl_table *t, const char *format);

#ifdef __cplusplus
}
#endif

#endif
