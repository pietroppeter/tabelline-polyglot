# The planets table, the one every port of tabelline draws.
#
#   ruby planets.rb         # HTML
#   ruby planets.rb text    # for the terminal
require_relative "lib/tabelline"

Planet = Data.define(:planet, :type, :diameter, :mass, :distance, :moons)

PLANETS = [
  Planet.new("Mercury", "Terrestrial", 4879, 0.33, 57.9, 0),
  Planet.new("Venus", "Terrestrial", 12_104, 4.87, 108.2, 0),
  Planet.new("Earth", "Terrestrial", 12_756, 5.97, 149.6, 1),
  Planet.new("Mars", "Terrestrial", 6792, 0.642, 228.0, 2),
  Planet.new("Jupiter", "Gas giant", 142_984, 1898.0, 778.5, 95),
  Planet.new("Saturn", "Gas giant", 120_536, 568.0, 1432.0, 146),
  Planet.new("Uranus", "Ice giant", 51_118, 86.8, 2867.0, 28),
  Planet.new("Neptune", "Ice giant", 49_528, 102.0, 4515.0, 16)
].freeze

table = Tabelline.table(PLANETS) do
  stub :planet
  group_by :type
  id "planets"
  header "The planets", subtitle: md("of the *Solar System*")
  spanner "Size", columns: %i[diameter mass]
  labels diameter: "Diameter (km)", mass: "Mass (10²⁴ kg)",
         distance: "From the Sun (10⁶ km)", moons: "Moons"
  fmt_integer :diameter
  fmt_number :mass, decimals: 2
  fmt_number :distance, decimals: 1
  data_color :moons, palette: "blues"
  style bold, at: body(:moons, rows: where(:moons, :>, 50))
  footnote "Moons confirmed by 2025.", at: column_labels(:moons)
  source_note "NASA, Planetary Fact Sheet"
end

$stdout.write(ARGV.first == "text" ? table.to_text : table.to_html)
