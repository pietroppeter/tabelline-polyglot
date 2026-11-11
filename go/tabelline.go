// Package tabelline draws display tables: built from parts, formatted and styled, written as
// HTML, text or Markdown. It calls tabelline, a Nim library, through its C ABI (libtabelline).
//
// A table starts from a slice of structs; a field's tag names its column:
//
//	type Planet struct {
//		Name string  `tabelline:"planet"`
//		Mass float64 `tabelline:"mass"`
//	}
//
//	t := tabelline.FromSlice(planets)
//	defer t.Close()
//	t.Stub("planet")
//	t.Header("The planets", tabelline.Markdown("of the *Solar System*"))
//	t.FmtNumber([]string{"mass"}, 2)
//	html, err := t.HTML()
//
// Steps do not return errors: the first one that fails is kept, and returned by HTML, Text or
// Markdown, as bufio.Scanner does. Nothing is drawn until then.
package tabelline

/*
#cgo CFLAGS: -I${SRCDIR}/../capi
#cgo LDFLAGS: -L${SRCDIR}/../build -ltabelline -Wl,-rpath,${SRCDIR}/../build
#include <stdlib.h>
#include "tabelline.h"
*/
import "C"

import (
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"unsafe"
)

// A Table is a table being built. Close it when done: it holds memory in libtabelline.
type Table struct {
	t   *C.tbl_table
	err error
}

// Text is a title, a label or a note: a plain string, or Markdown or HTML.
type Text interface{ text() any }

type plain string
type markdown string
type html string

func (s plain) text() any    { return string(s) }
func (s markdown) text() any { return map[string]string{"md": string(s)} }
func (s html) text() any     { return map[string]string{"html": string(s)} }

// Plain is text as it is.
func Plain(s string) Text { return plain(s) }

// Markdown is text written in Markdown: "of the *Solar System*".
func Markdown(s string) Text { return markdown(s) }

// HTML is text written in HTML.
func HTML(s string) Text { return html(s) }

// Rows chooses rows of the body, for a style or a format: AllRows, RowsAt, Where.
type Rows any

// AllRows is every row.
var AllRows Rows = map[string]bool{"all": true}

// RowsAt is the rows at these positions, counted from 0.
func RowsAt(indices ...int) Rows { return indices }

// Where is the rows whose value in column compares to value: Where("moons", ">", 50).
// The operators are == != < <= > >=.
func Where(column, op string, value any) Rows {
	return map[string]any{"where": []any{column, op, value}}
}

// A Location is a part of the table, for a style or a footnote.
type Location any

var (
	Title       Location = "title"
	Subtitle    Location = "subtitle"
	Stubhead    Location = "stubhead"
	SourceNotes Location = "sourceNotes"
	Footnotes   Location = "footnotes"
)

// ColumnLabels is the labels of these columns.
func ColumnLabels(columns ...string) Location { return map[string]any{"columnLabels": columns} }

// Body is the cells of these columns, in these rows.
func Body(columns []string, rows Rows) Location {
	return map[string]any{"body": map[string]any{"columns": columns, "rows": rows}}
}

// Stub is the names of these rows.
func Stub(rows Rows) Location { return map[string]any{"stub": map[string]any{"rows": rows}} }

// A Style is how a cell looks.
type Style map[string]any

// Bold text.
var Bold = Style{"text": map[string]string{"weight": "bold"}}

// Italic text.
var Italic = Style{"text": map[string]string{"style": "italic"}}

// Fill is the cell filled with a CSS colour.
func Fill(colour string) Style { return Style{"fill": colour} }

// TextColor is text in a CSS colour.
func TextColor(colour string) Style { return Style{"text": map[string]string{"color": colour}} }

// New is an empty table: add columns with Column.
func New() *Table { return &Table{t: C.tbl_new()} }

// FromSlice is a table of a slice of structs: one row for each element, and one column for
// each field with a `tabelline:"name"` tag, in the order of the fields. A field that is a
// pointer is a column with missing values (nil).
func FromSlice[T any](rows []T) *Table {
	t := New()
	typ := reflect.TypeFor[T]()
	if typ.Kind() != reflect.Struct {
		t.fail(fmt.Errorf("tabelline: FromSlice needs a slice of structs, not of %s", typ))
		return t
	}
	for i := range typ.NumField() {
		name := typ.Field(i).Tag.Get("tabelline")
		if name == "" {
			continue
		}
		values := make([]any, len(rows))
		for r := range rows {
			values[r] = reflect.ValueOf(rows[r]).Field(i).Interface()
		}
		t.Column(name, values)
	}
	return t
}

// Close frees the table.
func (t *Table) Close() {
	if t.t != nil {
		C.tbl_drop(t.t)
		t.t = nil
	}
}

// Err is the first error of a step, if any.
func (t *Table) Err() error { return t.err }

func (t *Table) fail(err error) {
	if t.err == nil {
		t.err = err
	}
}

func lastError() error { return errors.New("tabelline: " + C.GoString(C.tbl_error())) }

func cstr(s string) (*C.char, func()) {
	c := C.CString(s)
	return c, func() { C.free(unsafe.Pointer(c)) }
}

// Column adds a column: any slice that encoding/json writes as an array of numbers, strings,
// booleans and nulls.
func (t *Table) Column(name string, values any) *Table {
	if t.err != nil {
		return t
	}
	j, err := json.Marshal(values)
	if err != nil {
		t.fail(fmt.Errorf("tabelline: column %q: %w", name, err))
		return t
	}
	n, freeN := cstr(name)
	defer freeN()
	v, freeV := cstr(string(j))
	defer freeV()
	if C.tbl_add_json(t.t, n, v) != 0 {
		t.fail(lastError())
	}
	return t
}

func (t *Table) set(key, value string) *Table {
	if t.err != nil {
		return t
	}
	k, freeK := cstr(key)
	defer freeK()
	v, freeV := cstr(value)
	defer freeV()
	if C.tbl_set(t.t, k, v) != 0 {
		t.fail(lastError())
	}
	return t
}

// Stub sets the column whose values name the rows.
func (t *Table) Stub(column string) *Table { return t.set("rownameCol", column) }

// GroupBy sets the column whose values group the rows.
func (t *Table) GroupBy(column string) *Table { return t.set("groupnameCol", column) }

// ID sets the table's HTML id.
func (t *Table) ID(id string) *Table { return t.set("id", id) }

// Locale sets the locale of every format: "it", "de", "en-GB".
func (t *Table) Locale(locale string) *Table { return t.set("locale", locale) }

// Args are a verb's arguments by name: Args{"columns": []string{"mass"}, "decimals": 2}.
type Args map[string]any

// Verb adds any of tabelline's verbs, by name ("fmtDate" or "fmt_date"), with its arguments:
// Args, or a slice of positional ones. Text values are written as tabelline reads them.
func (t *Table) Verb(name string, args any) *Table {
	if t.err != nil {
		return t
	}
	j, err := json.Marshal(texts(args))
	if err != nil {
		t.fail(fmt.Errorf("tabelline: %s: %w", name, err))
		return t
	}
	n, freeN := cstr(name)
	defer freeN()
	a, freeA := cstr(string(j))
	defer freeA()
	if C.tbl_verb(t.t, n, a) != 0 {
		t.fail(lastError())
	}
	return t
}

// texts replaces every Text in args by the JSON tabelline reads for it.
func texts(v any) any {
	switch x := v.(type) {
	case Text:
		return x.text()
	case Args:
		out := map[string]any{}
		for k, e := range x {
			out[k] = texts(e)
		}
		return out
	case map[string]Text:
		out := map[string]any{}
		for k, e := range x {
			out[k] = e.text()
		}
		return out
	case []any:
		out := make([]any, len(x))
		for i, e := range x {
			out[i] = texts(e)
		}
		return out
	}
	return v
}

// Header sets the title and the subtitle (nil for none).
func (t *Table) Header(title string, subtitle Text) *Table {
	if subtitle == nil {
		return t.Verb("tabHeader", Args{"title": title})
	}
	return t.Verb("tabHeader", Args{"title": title, "subtitle": subtitle})
}

// Spanner puts a label over these columns.
func (t *Table) Spanner(label string, columns ...string) *Table {
	return t.Verb("tabSpanner", Args{"label": label, "columns": columns})
}

// Labels sets the labels shown for columns, by name.
func (t *Table) Labels(labels map[string]Text) *Table {
	return t.Verb("colsLabel", Args{"labels": labels})
}

// FmtInteger writes these columns as whole numbers with a thousands separator.
func (t *Table) FmtInteger(columns ...string) *Table {
	return t.Verb("fmtInteger", Args{"columns": columns})
}

// FmtNumber writes these columns with this many decimals.
func (t *Table) FmtNumber(columns []string, decimals int) *Table {
	return t.Verb("fmtNumber", Args{"columns": columns, "decimals": decimals})
}

// FmtCurrency writes these columns as money, in a currency given by its code ("EUR").
func (t *Table) FmtCurrency(columns []string, currency string) *Table {
	return t.Verb("fmtCurrency", Args{"columns": columns, "currency": currency})
}

// DataColor colours these columns' cells by value along a palette ("blues", "viridis", ...).
func (t *Table) DataColor(columns []string, palette string) *Table {
	return t.Verb("dataColor", Args{"columns": columns, "palette": palette})
}

// Style styles these parts of the table.
func (t *Table) Style(styles []Style, at ...Location) *Table {
	return t.Verb("tabStyle", Args{"style": styles, "locations": at})
}

// Footnote marks these parts of the table and adds the note at its foot.
func (t *Table) Footnote(note Text, at ...Location) *Table {
	return t.Verb("tabFootnote", Args{"note": note, "locations": at})
}

// SourceNote adds a note that says where the data comes from.
func (t *Table) SourceNote(note Text) *Table {
	return t.Verb("tabSourceNote", Args{"note": note})
}

func (t *Table) render(format string) (string, error) {
	if t.err != nil {
		return "", t.err
	}
	if t.t == nil {
		return "", errors.New("tabelline: the table is closed")
	}
	f, freeF := cstr(format)
	defer freeF()
	out := C.tbl_render(t.t, f)
	if out == nil {
		return "", lastError()
	}
	defer C.tbl_free(out)
	return C.GoString(out), nil
}

// HTML draws the table as HTML, with its own styles.
func (t *Table) HTML() (string, error) { return t.render("html") }

// Page draws the table as a whole HTML page.
func (t *Table) Page() (string, error) { return t.render("page") }

// Text draws the table with box characters, for a terminal.
func (t *Table) Text() (string, error) { return t.render("text") }

// Markdown draws the table in Markdown.
func (t *Table) Markdown() (string, error) { return t.render("markdown") }
