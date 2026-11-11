package tabelline_test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/pietroppeter/tabelline-polyglot/go"
)

type fruit struct {
	Name  string  `tabelline:"fruit"`
	Price float64 `tabelline:"price"`
	Stock *int    `tabelline:"stock"`
	note  string
}

func fruits() []fruit {
	ten := 10
	return []fruit{{"apple", 1.5, &ten, ""}, {"kiwi", 0.25, nil, ""}}
}

func ExampleFromSlice() {
	t := tabelline.FromSlice(fruits())
	defer t.Close()
	t.FmtCurrency([]string{"price"}, "EUR")
	t.Verb("subMissing", tabelline.Args{"columns": "stock", "missingText": "sold out"})
	md, _ := t.Markdown()
	fmt.Println(md)
	// Output:
	// | fruit | price | stock |
	// |:--|--:|--:|
	// | apple | €1.50 | 10 |
	// | kiwi | €0.25 | sold out |
}

func TestTheFirstErrorIsKept(t *testing.T) {
	tab := tabelline.FromSlice(fruits())
	defer tab.Close()
	tab.FmtInteger("weight").FmtNumber([]string{"price"}, 2)
	_, err := tab.HTML()
	if err == nil || !strings.Contains(err.Error(), "weight") {
		t.Fatalf("want an error about the column weight, got %v", err)
	}
}

func TestFromSliceNeedsStructs(t *testing.T) {
	tab := tabelline.FromSlice([]int{1, 2})
	defer tab.Close()
	if _, err := tab.HTML(); err == nil {
		t.Fatal("want an error for a slice of ints")
	}
}
