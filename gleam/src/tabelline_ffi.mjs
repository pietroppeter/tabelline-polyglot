// The few JavaScript functions the Gleam modules use, with the names of tabelline_ffi.erl.
// tabelline_nim.mjs is tabelline compiled by nim js: `nim r js/build.nim` writes it.
import { Ok, Error, toList } from "./gleam.mjs";
import { tabelline_render } from "./tabelline_nim.mjs";

export function render(spec, format) {
  const r = tabelline_render(spec, format);
  return r.ok ? new Ok(r.value) : new Error(r.value);
}

export const json_string = (s) => JSON.stringify(s);
export const json_int = (i) => JSON.stringify(i);
// A Gleam Float is a JavaScript number, so 1898.0 would be written 1898 and tabelline would read
// an Int. Erlang writes 1898.0: do the same.
export const json_float = (f) => (Number.isInteger(f) ? f.toFixed(1) : JSON.stringify(f));

export function print(s) {
  globalThis.process ? process.stdout.write(s) : console.log(s);
}

export function arguments_() {
  // [node, the script, ...the arguments] under Node; none in a browser
  return toList(globalThis.process ? process.argv.slice(2) : []);
}
