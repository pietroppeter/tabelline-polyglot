//! Great tables for Rust: tabelline, a Nim port of R's gt and Python's Great Tables, called
//! through its C ABI (`libtabelline`). A proof of concept.
//!
//! ```no_run
//! use tabelline::{Table, Format, args, list, md};
//! let html = Table::new()
//!     .strings("planet", &["Mercury", "Venus"])
//!     .floats("mass", &[0.33, 4.87])
//!     .set("rownameCol", "planet")
//!     .verb("tab_header", list!["The planets", md("of the *Solar System*")])
//!     .verb("fmt_number", args! { columns: "mass", decimals: 2 })
//!     .render(Format::Html)?;
//! # Ok::<(), tabelline::Error>(())
//! ```
//!
//! Verb and argument names may be written the Rust way: the library ignores case and
//! underscores, so `fmt_number` is tabelline's `fmtNumber`.

use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::fmt;

mod ffi {
    use super::*;
    extern "C" {
        pub fn tbl_version() -> *const c_char;
        pub fn tbl_error() -> *const c_char;
        pub fn tbl_free(s: *mut c_char);
        pub fn tbl_render_spec(spec: *const c_char, format: *const c_char) -> *mut c_char;
        pub fn tbl_new() -> *mut c_void;
        pub fn tbl_drop(t: *mut c_void);
        pub fn tbl_add_doubles(t: *mut c_void, name: *const c_char, v: *const f64, n: usize) -> c_int;
        pub fn tbl_add_ints(t: *mut c_void, name: *const c_char, v: *const i64, n: usize) -> c_int;
        pub fn tbl_add_bools(t: *mut c_void, name: *const c_char, v: *const u8, n: usize) -> c_int;
        pub fn tbl_add_strings(t: *mut c_void, name: *const c_char, v: *const *const c_char, n: usize) -> c_int;
        pub fn tbl_set(t: *mut c_void, key: *const c_char, value: *const c_char) -> c_int;
        pub fn tbl_verb(t: *mut c_void, verb: *const c_char, args: *const c_char) -> c_int;
        pub fn tbl_render(t: *mut c_void, format: *const c_char) -> *mut c_char;
    }
}

/// What went wrong, in tabelline's words.
#[derive(Debug, Clone, PartialEq)]
pub struct Error(pub String);
impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result { write!(f, "tabelline: {}", self.0) }
}
impl std::error::Error for Error {}

fn last_error() -> Error {
    Error(unsafe { CStr::from_ptr(ffi::tbl_error()) }.to_string_lossy().into_owned())
}

fn owned(p: *mut c_char) -> Result<String, Error> {
    if p.is_null() { return Err(last_error()); }
    let s = unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
    unsafe { ffi::tbl_free(p) };
    Ok(s)
}

fn cs(s: &str) -> CString { CString::new(s).expect("no NUL bytes in tabelline strings") }

pub fn version() -> String { unsafe { CStr::from_ptr(ffi::tbl_version()) }.to_string_lossy().into_owned() }

// ---------------------------------------------------------------- arguments, as a small JSON

/// A verb's argument: what the C ABI reads as JSON. Build it with `list!`, `args!`, `md` and `From`.
#[derive(Debug, Clone, PartialEq)]
pub enum Arg { Null, Bool(bool), Int(i64), Float(f64), Str(String), List(Vec<Arg>), Map(Vec<(String, Arg)>) }

impl From<&str> for Arg { fn from(s: &str) -> Self { Arg::Str(s.into()) } }
impl From<String> for Arg { fn from(s: String) -> Self { Arg::Str(s) } }
impl From<bool> for Arg { fn from(b: bool) -> Self { Arg::Bool(b) } }
impl From<i64> for Arg { fn from(i: i64) -> Self { Arg::Int(i) } }
impl From<i32> for Arg { fn from(i: i32) -> Self { Arg::Int(i as i64) } }
impl From<f64> for Arg { fn from(x: f64) -> Self { Arg::Float(x) } }
impl<T: Into<Arg>, const N: usize> From<[T; N]> for Arg {
    fn from(a: [T; N]) -> Self { Arg::List(a.into_iter().map(Into::into).collect()) }
}
impl<T: Into<Arg>> From<Vec<T>> for Arg {
    fn from(a: Vec<T>) -> Self { Arg::List(a.into_iter().map(Into::into).collect()) }
}

impl fmt::Display for Arg {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Arg::Null => write!(f, "null"),
            Arg::Bool(b) => write!(f, "{b}"),
            Arg::Int(i) => write!(f, "{i}"),
            Arg::Float(x) => if x.is_finite() { write!(f, "{x:?}") } else { write!(f, "null") },
            Arg::Str(s) => {
                f.write_str("\"")?;
                for ch in s.chars() {
                    match ch {
                        '"' => f.write_str("\\\"")?,
                        '\\' => f.write_str("\\\\")?,
                        '\n' => f.write_str("\\n")?,
                        c if (c as u32) < 0x20 => write!(f, "\\u{:04x}", c as u32)?,
                        c => write!(f, "{c}")?,
                    }
                }
                f.write_str("\"")
            }
            Arg::List(items) => {
                f.write_str("[")?;
                for (i, a) in items.iter().enumerate() { if i > 0 { f.write_str(",")?; } write!(f, "{a}")?; }
                f.write_str("]")
            }
            Arg::Map(fields) => {
                f.write_str("{")?;
                for (i, (k, v)) in fields.iter().enumerate() {
                    if i > 0 { f.write_str(",")?; }
                    write!(f, "{}:{v}", Arg::Str(k.clone()))?;
                }
                f.write_str("}")
            }
        }
    }
}

/// Positional arguments: `list!["Size", ["diameter", "mass"]]`.
#[macro_export]
macro_rules! list {
    ($($v:expr),* $(,)?) => { $crate::Arg::List(vec![$($crate::Arg::from($v)),*]) };
}

/// Named arguments: `args! { columns: "mass", decimals: 2 }` (`r#where` for the `where` key).
#[macro_export]
macro_rules! args {
    ($($k:ident : $v:expr),* $(,)?) => {
        $crate::Arg::Map(vec![$((stringify!($k).trim_start_matches("r#").to_string(), $crate::Arg::from($v))),*])
    };
}

/// Markdown text, for a label or a note.
pub fn md(s: &str) -> Arg { Arg::Map(vec![("md".into(), s.into())]) }

// ------------------------------------------------------------------------------------- tables

#[derive(Debug, Clone, Copy)]
pub enum Format { Html, Page, Text, Markdown }
impl Format {
    fn name(self) -> &'static str {
        match self { Format::Html => "html", Format::Page => "page", Format::Text => "text", Format::Markdown => "markdown" }
    }
}

/// A table, built one call at a time; the first error is kept and returned by `render`.
pub struct Table { h: *mut c_void, err: Option<Error> }

impl Drop for Table { fn drop(&mut self) { unsafe { ffi::tbl_drop(self.h) } } }

impl Default for Table { fn default() -> Self { Self::new() } }

impl Table {
    pub fn new() -> Self { Table { h: unsafe { ffi::tbl_new() }, err: None } }

    fn step(mut self, rc: c_int) -> Self {
        if rc != 0 && self.err.is_none() { self.err = Some(last_error()); }
        self
    }

    pub fn strings<S: AsRef<str>>(self, name: &str, values: &[S]) -> Self {
        let owned: Vec<CString> = values.iter().map(|s| cs(s.as_ref())).collect();
        let ptrs: Vec<*const c_char> = owned.iter().map(|s| s.as_ptr()).collect();
        let rc = unsafe { ffi::tbl_add_strings(self.h, cs(name).as_ptr(), ptrs.as_ptr(), ptrs.len()) };
        self.step(rc)
    }
    pub fn ints(self, name: &str, values: &[i64]) -> Self {
        let rc = unsafe { ffi::tbl_add_ints(self.h, cs(name).as_ptr(), values.as_ptr(), values.len()) };
        self.step(rc)
    }
    /// A number column; `f64::NAN` is a missing value.
    pub fn floats(self, name: &str, values: &[f64]) -> Self {
        let rc = unsafe { ffi::tbl_add_doubles(self.h, cs(name).as_ptr(), values.as_ptr(), values.len()) };
        self.step(rc)
    }
    pub fn bools(self, name: &str, values: &[bool]) -> Self {
        let v: Vec<u8> = values.iter().map(|&b| b as u8).collect();
        let rc = unsafe { ffi::tbl_add_bools(self.h, cs(name).as_ptr(), v.as_ptr(), v.len()) };
        self.step(rc)
    }
    /// "rownameCol", "groupnameCol", "id" or "locale".
    pub fn set(self, key: &str, value: &str) -> Self {
        let rc = unsafe { ffi::tbl_set(self.h, cs(key).as_ptr(), cs(value).as_ptr()) };
        self.step(rc)
    }
    /// Any verb of tabelline: `verb("fmt_number", args! { columns: "mass", decimals: 2 })`.
    pub fn verb(self, name: &str, args: impl Into<Arg>) -> Self {
        let a = args.into().to_string();
        let rc = unsafe { ffi::tbl_verb(self.h, cs(name).as_ptr(), cs(&a).as_ptr()) };
        self.step(rc)
    }
    pub fn render(&self, format: Format) -> Result<String, Error> {
        if let Some(e) = &self.err { return Err(e.clone()); }
        owned(unsafe { ffi::tbl_render(self.h, cs(format.name()).as_ptr()) })
    }
}

/// A whole table from its JSON spec, in one call.
pub fn render_spec(spec: &str, format: Format) -> Result<String, Error> {
    owned(unsafe { ffi::tbl_render_spec(cs(spec).as_ptr(), cs(format.name()).as_ptr()) })
}
