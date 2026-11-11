# frozen_string_literal: true

# Great tables for Ruby: display tables built from parts, formatted and styled, drawn as HTML,
# text or Markdown by tabelline (a Nim library), called through Fiddle, from the standard
# library: no gem to compile.
#
#   Planet = Data.define(:name, :mass)
#
#   table = Tabelline.table([Planet.new("Mercury", 0.33), Planet.new("Venus", 4.87)]) do
#     stub :name
#     header "The planets", subtitle: md("of the *Solar System*")
#     fmt_number :mass, decimals: 2
#   end
#   puts table.to_html
#
# Inside the block every one of tabelline's verbs is a method, in snake_case: `fmt_percent`,
# `cols_hide`, `summary_rows`. A few have helpers for their arguments (`md`, `bold`, `body`,
# `where`).
require "fiddle"
require "fiddle/import"
require "json"

module Tabelline
  class Error < StandardError; end

  # libtabelline, from TABELLINE_LIB or ../build/libtabelline.so beside this repository.
  module Lib
    extend Fiddle::Importer
    dlload ENV.fetch("TABELLINE_LIB", File.expand_path("../../build/libtabelline.so", __dir__))
    extern "void* tbl_render_spec(const char*, const char*)"
    extern "const char* tbl_error()"
    extern "void tbl_free(void*)"
  end

  # Draws a spec (the table as JSON) as "html", "page", "text" or "markdown".
  def self.render_spec(spec, format)
    out = Lib.tbl_render_spec(spec, format)
    raise Error, Lib.tbl_error.to_s.force_encoding(Encoding::UTF_8) if out.null?

    out.to_s.force_encoding(Encoding::UTF_8)
  ensure
    Lib.tbl_free(out) if out && !out.null?
  end

  # A table of these rows, built by the block.
  def self.table(rows, **settings, &block)
    Table.new(rows, **settings).tap { |t| t.instance_eval(&block) if block }
  end

  # A table: rows (hashes, Structs or Data objects), settings, and the verbs added to it.
  class Table
    attr_reader :verbs

    def initialize(rows, columns: nil, **settings)
      @rows = rows.map { |r| r.respond_to?(:to_h) ? r.to_h : r }
      @columns = columns || @rows.first&.keys || []
      @settings = settings
      @verbs = []
    end

    # The column whose values name the rows.
    def stub(column) = @settings[:rownameCol] = column.to_s
    # The column whose values group the rows.
    def group_by(column) = @settings[:groupnameCol] = column.to_s
    def id(id) = @settings[:id] = id
    def locale(locale) = @settings[:locale] = locale

    # Text in Markdown or HTML, for a title, a label or a note.
    def md(text) = { md: text }
    def html(text) = { html: text }

    # Styles.
    def bold = { text: { weight: "bold" } }
    def italic = { text: { style: "italic" } }
    def fill(colour) = { fill: colour }
    def text_color(colour) = { text: { color: colour } }

    # Rows: all, at positions, or where a column compares to a value (`where :moons, :>, 50`).
    def all_rows = { all: true }
    def where(column, op, value) = { where: [column.to_s, op.to_s, value] }

    # Locations.
    def title = "title"
    def subtitle = "subtitle"
    def source_notes = "sourceNotes"
    def column_labels(*columns) = { columnLabels: columns.map(&:to_s) }
    def body(*columns, rows: all_rows) = { body: { columns: columns.map(&:to_s), rows: rows } }

    # `header "The planets", subtitle: md("...")` is tabelline's tab_header.
    def header(title, subtitle: nil) = verb(:tab_header, title, **{ subtitle: subtitle }.compact)
    # `spanner "Size", columns: %i[diameter mass]` is tab_spanner.
    def spanner(label, columns:) = verb(:tab_spanner, label, columns: columns)
    # `labels diameter: "Diameter (km)"` is cols_label.
    def labels(**labels) = verb(:cols_label, labels: labels)
    # `style bold, at: body(:moons)` is tab_style.
    def style(*styles, at:) = verb(:tab_style, styles, locations: list(at))
    # `footnote "...", at: column_labels(:moons)` is tab_footnote.
    def footnote(note, at:) = verb(:tab_footnote, note, locations: list(at))

    # `source_note "NASA"` is tab_source_note.
    def source_note(note) = verb(:tab_source_note, note)

    # Any verb, by name, with positional and keyword arguments.
    def verb(name, *args, **kwargs)
      args = args.map { |a| a.is_a?(Symbol) ? a.to_s : a }
      @verbs << { name.to_s => args.empty? ? kwargs : kwargs.merge(_args: args) }
      self
    end

    # Every other method is a verb: `fmt_number :mass, decimals: 2`.
    def method_missing(name, *args, **kwargs)
      return super if name.end_with?("?", "!", "=")

      verb(name, *args, **kwargs)
    end

    def respond_to_missing?(name, include_private = false) = !name.end_with?("?", "!", "=") || super

    # One location or several (Array() would split a Hash into pairs).
    private def list(at) = at.is_a?(Array) ? at : [at]

    # The table as the JSON tabelline reads.
    def to_spec
      columns = @columns.to_h { |c| [c.to_s, @rows.map { |r| r[c] }] }
      JSON.generate({ data: { columns: columns }, **@settings, verbs: @verbs })
    end

    def to_html = Tabelline.render_spec(to_spec, "html")
    def to_page = Tabelline.render_spec(to_spec, "page")
    def to_text = Tabelline.render_spec(to_spec, "text")
    def to_markdown = Tabelline.render_spec(to_spec, "markdown")
    alias to_s to_text
  end
end
