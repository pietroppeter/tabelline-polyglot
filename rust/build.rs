// Links libtabelline, built by `nim r tools/polyglot.nim` into ../build (or $TABELLINE_LIB).
fn main() {
    let dir = std::env::var("TABELLINE_LIB").unwrap_or_else(|_| {
        let here = std::env::var("CARGO_MANIFEST_DIR").unwrap();
        format!("{here}/../build")
    });
    println!("cargo:rustc-link-search=native={dir}");
    println!("cargo:rustc-link-lib=dylib=tabelline");
    println!("cargo:rustc-link-arg=-Wl,-rpath,{dir}");
    println!("cargo:rerun-if-env-changed=TABELLINE_LIB");
}
