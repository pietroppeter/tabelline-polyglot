const std = @import("std");
const tbl = @import("tabelline.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var t = try tbl.Table.init(gpa);
    defer t.deinit();
    try t.strings("planet", &.{ "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune" });
    try t.strings("type", &.{ "Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial", "Gas giant", "Gas giant", "Ice giant", "Ice giant" });
    try t.ints("diameter", &.{ 4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528 });
    try t.floats("mass", &.{ 0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0 });
    try t.floats("distance", &.{ 57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0 });
    try t.ints("moons", &.{ 0, 0, 1, 2, 95, 146, 28, 16 });
    try t.set("rownameCol", "planet");
    try t.set("groupnameCol", "type");
    try t.set("id", "planets");

    try t.verb("tabHeader", .{ "The planets", tbl.md("of the *Solar System*") });
    try t.verb("tabSpanner", .{ "Size", .{ "diameter", "mass" } });
    try t.verb("colsLabel", .{ .labels = .{
        .diameter = "Diameter (km)",
        .mass = "Mass (10²⁴ kg)",
        .distance = "From the Sun (10⁶ km)",
        .moons = "Moons",
    } });
    try t.verb("fmtInteger", .{"diameter"});
    try t.verb("fmtNumber", .{ .columns = "mass", .decimals = 2 });
    try t.verb("fmtNumber", .{ .columns = "distance", .decimals = 1 });
    try t.verb("dataColor", .{ .columns = "moons", .palette = "blues" });
    try t.verb("tabStyle", .{ .{ .text = .{ .weight = "bold" } }, .{.{ .body = .{ .columns = "moons", .rows = .{ .where = .{ "moons", ">", 50 } } } }} });
    try t.verb("tabFootnote", .{ "Moons confirmed by 2025.", .{.{ .columnLabels = "moons" }} });
    try t.verb("tabSourceNote", .{"NASA, Planetary Fact Sheet"});

    const html = t.render(.html) catch {
        std.debug.print("tabelline: {s}\n", .{tbl.lastError()});
        return error.Tabelline;
    };
    defer html.deinit();
    var buf: [4096]u8 = undefined;
    var w = std.Io.File.stdout().writer(init.io, &buf);
    try w.interface.writeAll(html.slice());
    try w.interface.flush();
}
