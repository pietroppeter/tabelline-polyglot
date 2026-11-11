/* tabelline on the BEAM: one NIF over libtabelline's first layer, render_spec(Spec, Format).
 * Spec and Format are iodata (binaries); the answer is {ok, Binary} or {error, Binary}.
 * It runs on a dirty CPU scheduler, so a big table never blocks the normal schedulers. */
#include <string.h>
#include <erl_nif.h>
#include "tabelline.h"

static int cstr(ErlNifEnv *env, ERL_NIF_TERM t, ErlNifBinary *bin) {
  ErlNifBinary in;
  if (!enif_inspect_iolist_as_binary(env, t, &in)) return 0;
  if (!enif_alloc_binary(in.size + 1, bin)) return 0;
  memcpy(bin->data, in.data, in.size);
  bin->data[in.size] = '\0';
  return 1;
}

static ERL_NIF_TERM binary(ErlNifEnv *env, const char *s) {
  ERL_NIF_TERM t;
  size_t n = strlen(s);
  memcpy(enif_make_new_binary(env, n, &t), s, n);
  return t;
}

static ERL_NIF_TERM render_spec(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary spec, format;
  if (argc != 2 || !cstr(env, argv[0], &spec)) return enif_make_badarg(env);
  if (!cstr(env, argv[1], &format)) { enif_release_binary(&spec); return enif_make_badarg(env); }
  char *out = tbl_render_spec((const char *)spec.data, (const char *)format.data);
  enif_release_binary(&spec);
  enif_release_binary(&format);
  if (!out) return enif_make_tuple2(env, enif_make_atom(env, "error"), binary(env, tbl_error()));
  ERL_NIF_TERM r = enif_make_tuple2(env, enif_make_atom(env, "ok"), binary(env, out));
  tbl_free(out);
  return r;
}

static ERL_NIF_TERM version(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  return binary(env, tbl_version());
}

static ErlNifFunc funcs[] = {
  {"render_spec", 2, render_spec, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"version", 0, version, 0},
};

ERL_NIF_INIT(tabelline_nif, funcs, NULL, NULL, NULL, NULL)
