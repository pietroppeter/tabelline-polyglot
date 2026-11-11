package tabelline;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.nio.file.Path;
import java.util.*;

/**
 * Great tables for the JVM: tabelline (Nim) through its C ABI, with the Foreign Function and
 * Memory API of Java 22+ (no JNI, no dependencies). A proof of concept.
 *
 * <pre>{@code
 * String html = Tabelline.table()
 *     .strings("planet", "Mercury", "Venus")
 *     .doubles("mass", 0.33, 4.87)
 *     .set("rownameCol", "planet")
 *     .verb("tabHeader", List.of("The planets", Tabelline.md("of the *Solar System*")))
 *     .verb("fmtNumber", Tabelline.args("columns", "mass", "decimals", 2))
 *     .render("html");
 * }</pre>
 */
public final class Tabelline {
    private static final Linker LINKER = Linker.nativeLinker();
    private static final SymbolLookup LIB = SymbolLookup.libraryLookup(
        Path.of(System.getProperty("tabelline.lib", "build/libtabelline.so")), Arena.global());

    private static MethodHandle fn(String name, MemoryLayout ret, MemoryLayout... args) {
        var f = ret == null ? FunctionDescriptor.ofVoid(args) : FunctionDescriptor.of(ret, args);
        return LINKER.downcallHandle(LIB.find(name).orElseThrow(), f);
    }

    private static final AddressLayout P = ValueLayout.ADDRESS;
    private static final ValueLayout.OfInt I = ValueLayout.JAVA_INT;
    private static final ValueLayout.OfLong N = ValueLayout.JAVA_LONG;
    private static final MethodHandle ERROR = fn("tbl_error", P);
    private static final MethodHandle FREE = fn("tbl_free", null, P);
    private static final MethodHandle NEW = fn("tbl_new", P);
    private static final MethodHandle DROP = fn("tbl_drop", null, P);
    private static final MethodHandle ADD_DOUBLES = fn("tbl_add_doubles", I, P, P, P, N);
    private static final MethodHandle ADD_INTS = fn("tbl_add_ints", I, P, P, P, N);
    private static final MethodHandle ADD_STRINGS = fn("tbl_add_strings", I, P, P, P, N);
    private static final MethodHandle SET = fn("tbl_set", I, P, P, P);
    private static final MethodHandle VERB = fn("tbl_verb", I, P, P, P);
    private static final MethodHandle RENDER = fn("tbl_render", P, P, P);
    private static final MethodHandle RENDER_SPEC = fn("tbl_render_spec", P, P, P);

    /** What went wrong, in tabelline's words. */
    public static final class TabellineException extends RuntimeException {
        TabellineException(String m) { super(m); }
    }

    private Tabelline() {}

    private static String lastError() {
        try { return ((MemorySegment) ERROR.invokeExact()).reinterpret(Long.MAX_VALUE).getString(0); }
        catch (Throwable e) { throw new RuntimeException(e); }
    }

    private static void check(int rc) { if (rc != 0) throw new TabellineException(lastError()); }

    private static String owned(MemorySegment p) throws Throwable {
        if (p.equals(MemorySegment.NULL)) throw new TabellineException(lastError());
        String s = p.reinterpret(Long.MAX_VALUE).getString(0);
        FREE.invokeExact(p);
        return s;
    }

    // ---------------------------------------------------------------- arguments, as JSON

    /** Markdown text, for a label or a note. */
    public static Map<String, Object> md(String s) { return Map.of("md", s); }

    /** Named arguments, in order: {@code args("columns", "mass", "decimals", 2)}. */
    public static Map<String, Object> args(Object... kv) {
        var m = new LinkedHashMap<String, Object>();
        for (int i = 0; i < kv.length; i += 2) m.put((String) kv[i], kv[i + 1]);
        return m;
    }

    static String json(Object v) {
        var b = new StringBuilder();
        json(b, v);
        return b.toString();
    }

    private static void json(StringBuilder b, Object v) {
        switch (v) {
            case null -> b.append("null");
            case String s -> {
                b.append('"');
                for (char c : s.toCharArray()) {
                    switch (c) {
                        case '"' -> b.append("\\\"");
                        case '\\' -> b.append("\\\\");
                        default -> { if (c < 0x20) b.append(String.format("\\u%04x", (int) c)); else b.append(c); }
                    }
                }
                b.append('"');
            }
            case Double d when d.isNaN() || d.isInfinite() -> b.append("null");
            case Number n -> b.append(n);
            case Boolean bo -> b.append(bo);
            case Map<?, ?> m -> {
                b.append('{');
                var first = true;
                for (var e : m.entrySet()) {
                    if (!first) b.append(',');
                    first = false;
                    json(b, e.getKey().toString());
                    b.append(':');
                    json(b, e.getValue());
                }
                b.append('}');
            }
            case Collection<?> c -> {
                b.append('[');
                var first = true;
                for (var x : c) { if (!first) b.append(','); first = false; json(b, x); }
                b.append(']');
            }
            case Object[] a -> json(b, Arrays.asList(a));
            default -> throw new IllegalArgumentException("no JSON for " + v.getClass());
        }
    }

    // ------------------------------------------------------------------------------- tables

    public static Table table() { return new Table(); }

    /** A whole table from its JSON spec, in one call. */
    public static String renderSpec(String spec, String format) {
        try (var arena = Arena.ofConfined()) {
            return owned((MemorySegment) RENDER_SPEC.invokeExact(arena.allocateFrom(spec), arena.allocateFrom(format)));
        } catch (TabellineException e) { throw e; } catch (Throwable e) { throw new RuntimeException(e); }
    }

    /** A table, built one call at a time. Close it, or let try-with-resources do it. */
    public static final class Table implements AutoCloseable {
        private final MemorySegment h;

        private Table() {
            try { h = (MemorySegment) NEW.invokeExact(); } catch (Throwable e) { throw new RuntimeException(e); }
        }

        @FunctionalInterface private interface Call { int run(Arena a) throws Throwable; }

        private Table call(Call c) {
            try (var arena = Arena.ofConfined()) { check(c.run(arena)); }
            catch (TabellineException e) { throw e; } catch (Throwable e) { throw new RuntimeException(e); }
            return this;
        }

        public Table doubles(String name, double... v) {
            return call(a -> (int) ADD_DOUBLES.invokeExact(h, a.allocateFrom(name),
                a.allocateFrom(ValueLayout.JAVA_DOUBLE, v), (long) v.length));
        }
        public Table ints(String name, long... v) {
            return call(a -> (int) ADD_INTS.invokeExact(h, a.allocateFrom(name),
                a.allocateFrom(ValueLayout.JAVA_LONG, v), (long) v.length));
        }
        public Table strings(String name, String... v) {
            return call(a -> {
                var ptrs = a.allocate(P, v.length);
                for (int i = 0; i < v.length; i++)
                    ptrs.setAtIndex(P, i, v[i] == null ? MemorySegment.NULL : a.allocateFrom(v[i]));
                return (int) ADD_STRINGS.invokeExact(h, a.allocateFrom(name), ptrs, (long) v.length);
            });
        }
        /** "rownameCol", "groupnameCol", "id" or "locale". */
        public Table set(String key, String value) {
            return call(a -> (int) SET.invokeExact(h, a.allocateFrom(key), a.allocateFrom(value)));
        }
        /** Any verb of tabelline; {@code args} is a List (positional) or a Map (named). */
        public Table verb(String name, Object args) {
            var j = json(args);
            return call(a -> (int) VERB.invokeExact(h, a.allocateFrom(name), a.allocateFrom(j)));
        }
        public String render(String format) {
            try (var arena = Arena.ofConfined()) {
                return owned((MemorySegment) RENDER.invokeExact(h, arena.allocateFrom(format)));
            } catch (TabellineException e) { throw e; } catch (Throwable e) { throw new RuntimeException(e); }
        }
        @Override public void close() {
            try { DROP.invokeExact(h); } catch (Throwable e) { throw new RuntimeException(e); }
        }
    }
}
