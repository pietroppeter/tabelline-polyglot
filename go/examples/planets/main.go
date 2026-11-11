// The planets table, the one every port of tabelline draws.
//
//	go run ./examples/planets         # HTML
//	go run ./examples/planets text    # for the terminal
package main

import (
	"fmt"
	"os"

	"github.com/pietroppeter/tabelline-polyglot/go"
)

type Planet struct {
	Name     string  `tabelline:"planet"`
	Type     string  `tabelline:"type"`
	Diameter int     `tabelline:"diameter"`
	Mass     float64 `tabelline:"mass"`
	Distance float64 `tabelline:"distance"`
	Moons    int     `tabelline:"moons"`
}

var planets = []Planet{
	{"Mercury", "Terrestrial", 4879, 0.33, 57.9, 0},
	{"Venus", "Terrestrial", 12104, 4.87, 108.2, 0},
	{"Earth", "Terrestrial", 12756, 5.97, 149.6, 1},
	{"Mars", "Terrestrial", 6792, 0.642, 228.0, 2},
	{"Jupiter", "Gas giant", 142984, 1898.0, 778.5, 95},
	{"Saturn", "Gas giant", 120536, 568.0, 1432.0, 146},
	{"Uranus", "Ice giant", 51118, 86.8, 2867.0, 28},
	{"Neptune", "Ice giant", 49528, 102.0, 4515.0, 16},
}

func main() {
	t := tabelline.FromSlice(planets)
	defer t.Close()
	t.Stub("planet").GroupBy("type").ID("planets")
	t.Header("The planets", tabelline.Markdown("of the *Solar System*"))
	t.Spanner("Size", "diameter", "mass")
	t.Labels(map[string]tabelline.Text{
		"diameter": tabelline.Plain("Diameter (km)"),
		"mass":     tabelline.Plain("Mass (10²⁴ kg)"),
		"distance": tabelline.Plain("From the Sun (10⁶ km)"),
		"moons":    tabelline.Plain("Moons"),
	})
	t.FmtInteger("diameter")
	t.FmtNumber([]string{"mass"}, 2)
	t.FmtNumber([]string{"distance"}, 1)
	t.DataColor([]string{"moons"}, "blues")
	t.Style([]tabelline.Style{tabelline.Bold},
		tabelline.Body([]string{"moons"}, tabelline.Where("moons", ">", 50)))
	t.Footnote(tabelline.Plain("Moons confirmed by 2025."), tabelline.ColumnLabels("moons"))
	t.SourceNote(tabelline.Plain("NASA, Planetary Fact Sheet"))

	draw := t.HTML
	if len(os.Args) > 1 && os.Args[1] == "text" {
		draw = t.Text
	}
	out, err := draw()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Print(out)
}
