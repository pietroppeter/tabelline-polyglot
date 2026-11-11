// The few JavaScript functions the Gleam modules use: the same names as tabelline_ffi.erl.
import { Ok, Error } from "./gleam.mjs";
import { tabelline_render } from "./tabelline_nim.mjs";

export function render(spec, format) {
  const r = tabelline_render(spec, format);
  return r.ok ? new Ok(r.value) : new Error(r.value);
}

export const json_string = (s) => JSON.stringify(s);
export const json_int = (i) => JSON.stringify(i);
// A Gleam Float is a JavaScript number: 1898.0 would be written 1898, and tabelline would read
// an Int. Erlang writes 1898.0, so do the same.
export const json_float = (f) => (Number.isInteger(f) ? f.toFixed(1) : JSON.stringify(f));

export const now = () => performance.now();
export const print = (s) => { process.stdout.write(s); };
