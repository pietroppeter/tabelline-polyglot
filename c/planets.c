/* The planets table from C: typed columns, then one verb at a time. */
#include <stdio.h>
#include "tabelline.h"

#define CHECK(call) do { if ((call) != 0) { fprintf(stderr, "%s\n", tbl_error()); return 1; } } while (0)

int main(void) {
  const char *planet[] = {"Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"};
  const char *type[] = {"Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial",
                        "Gas giant", "Gas giant", "Ice giant", "Ice giant"};
  int64_t diameter[] = {4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528};
  double mass[] = {0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0};
  double distance[] = {57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0};
  int64_t moons[] = {0, 0, 1, 2, 95, 146, 28, 16};

  tbl_table *t = tbl_new();
  CHECK(tbl_add_strings(t, "planet", planet, 8));
  CHECK(tbl_add_strings(t, "type", type, 8));
  CHECK(tbl_add_ints(t, "diameter", diameter, 8));
  CHECK(tbl_add_doubles(t, "mass", mass, 8));
  CHECK(tbl_add_doubles(t, "distance", distance, 8));
  CHECK(tbl_add_ints(t, "moons", moons, 8));
  CHECK(tbl_set(t, "rownameCol", "planet"));
  CHECK(tbl_set(t, "groupnameCol", "type"));
  CHECK(tbl_set(t, "id", "planets"));

  CHECK(tbl_verb(t, "tabHeader", "[\"The planets\", {\"md\": \"of the *Solar System*\"}]"));
  CHECK(tbl_verb(t, "tabSpanner", "[\"Size\", [\"diameter\", \"mass\"]]"));
  CHECK(tbl_verb(t, "colsLabel", "{\"labels\": {\"diameter\": \"Diameter (km)\", \"mass\": \"Mass (10²⁴ kg)\","
                                 " \"distance\": \"From the Sun (10⁶ km)\", \"moons\": \"Moons\"}}"));
  CHECK(tbl_verb(t, "fmtInteger", "[\"diameter\"]"));
  CHECK(tbl_verb(t, "fmtNumber", "{\"columns\": \"mass\", \"decimals\": 2}"));
  CHECK(tbl_verb(t, "fmtNumber", "{\"columns\": \"distance\", \"decimals\": 1}"));
  CHECK(tbl_verb(t, "dataColor", "{\"columns\": \"moons\", \"palette\": \"blues\"}"));
  CHECK(tbl_verb(t, "tabStyle", "[{\"text\": {\"weight\": \"bold\"}}, [{\"body\": {\"columns\": \"moons\","
                                " \"rows\": {\"where\": [\"moons\", \">\", 50]}}}]]"));
  CHECK(tbl_verb(t, "tabFootnote", "[\"Moons confirmed by 2025.\", [{\"columnLabels\": \"moons\"}]]"));
  CHECK(tbl_verb(t, "tabSourceNote", "[\"NASA, Planetary Fact Sheet\"]"));

  char *html = tbl_render(t, "html");
  if (!html) { fprintf(stderr, "%s\n", tbl_error()); return 1; }
  fputs(html, stdout);
  tbl_free(html);
  tbl_drop(t);
  return 0;
}
