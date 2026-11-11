//! tabelline for Zig: a thin wrapper over libtabelline's C ABI.
//! Columns go in as slices; a verb's arguments are any Zig value, written as JSON by std.json:
//! a tuple `.{ "Size", .{ "diameter", "mass" } }` is positional, a struct `.{ .decimals = 2 }` named.
const std = @import("std");

/// The C ABI of libtabelline (capi/tabelline.h), declared by hand (Zig 0.17 has no @cImport; this is all of it that we use).
const c = struct {
    const tbl_table = opaque {};
    extern fn tbl_error() [*:0]const u8;
    extern fn tbl_free(s: [*:0]u8) void;
    extern fn tbl_new() ?*tbl_table;
    extern fn tbl_drop(t: *tbl_table) void;
    extern fn tbl_add_doubles(t: *tbl_table, name: [*:0]const u8, values: [*]const f64, n: usize) c_int;
    extern fn tbl_add_ints(t: *tbl_table, name: [*:0]const u8, values: [*]const i64, n: usize) c_int;
    extern fn tbl_add_strings(t: *tbl_table, name: [*:0]const u8, values: [*]const ?[*:0]const u8, n: usize) c_int;
    extern fn tbl_set(t: *tbl_table, key: [*:0]const u8, value: [*:0]const u8) c_int;
    extern fn tbl_verb(t: *tbl_table, verb: [*:0]const u8, args: [*:0]const u8) c_int;
    extern fn tbl_render(t: *tbl_table, format: [*:0]const u8) ?[*:0]u8;
};

pub const Error = error{Tabelline};

/// The message of the last error, from the library.
pub fn lastError() []const u8 {
    return std.mem.span(c.tbl_error());
}

fn check(rc: c_int) Error!void {
    if (rc != 0) return error.Tabelline;
}

pub const Format = enum { html, page, text, markdown };

/// A string the library made, freed with `deinit`.
pub const Rendered = struct {
    ptr: [*:0]u8,
    pub fn slice(self: Rendered) []const u8 {
        return std.mem.span(self.ptr);
    }
    pub fn deinit(self: Rendered) void {
        c.tbl_free(self.ptr);
    }
};

/// Text in a label or note: plain by default, or Markdown or HTML.
pub fn md(s: []const u8) struct { md: []const u8 } {
    return .{ .md = s };
}

pub const Table = struct {
    handle: *c.tbl_table,
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) Error!Table {
        const h = c.tbl_new() orelse return error.Tabelline;
        return .{ .handle = h, .gpa = gpa };
    }
    pub fn deinit(self: *Table) void {
        c.tbl_drop(self.handle);
    }

    pub fn strings(self: *Table, name: [:0]const u8, values: []const [*:0]const u8) Error!void {
        try check(c.tbl_add_strings(self.handle, name, @ptrCast(values.ptr), values.len));
    }
    pub fn ints(self: *Table, name: [:0]const u8, values: []const i64) Error!void {
        try check(c.tbl_add_ints(self.handle, name, values.ptr, values.len));
    }
    pub fn floats(self: *Table, name: [:0]const u8, values: []const f64) Error!void {
        try check(c.tbl_add_doubles(self.handle, name, values.ptr, values.len));
    }
    /// "rownameCol", "groupnameCol", "id" or "locale".
    pub fn set(self: *Table, key: [:0]const u8, value: [:0]const u8) Error!void {
        try check(c.tbl_set(self.handle, key, value));
    }

    /// Any verb of tabelline, with its arguments as a Zig value.
    pub fn verb(self: *Table, name: [:0]const u8, args: anytype) !void {
        const json = try std.json.Stringify.valueAlloc(self.gpa, args, .{});
        defer self.gpa.free(json);
        const z = try self.gpa.dupeSentinel(u8, json, 0);
        defer self.gpa.free(z);
        try check(c.tbl_verb(self.handle, name, z));
    }

    pub fn render(self: *Table, format: Format) Error!Rendered {
        const p = c.tbl_render(self.handle, @tagName(format)) orelse return error.Tabelline;
        return .{ .ptr = p };
    }
};
