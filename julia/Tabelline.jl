"""
Great tables for Julia: tabelline (Nim) through its C ABI, `libtabelline`. A proof of concept.

    using .Tabelline
    t = tabella((planet = ["Mercury", "Venus"], mass = [0.33, 4.87]); rownameCol = "planet") |>
        tab_header("The planets", md("of the *Solar System*")) |>
        fmt_number(columns = "mass", decimals = 2)
    print(render(t))

Every verb of the library is a Julia function, made when the module loads from the list the
library gives (`tbl_verbs`): `fmtNumber` becomes `fmt_number`. Called with a table it applies the
verb; called without one it returns a function, for `|>`.
"""
module Tabelline

export tabella, render, md, html, verb, Tabella

const lib = get(ENV, "TABELLINE_LIB", joinpath(@__DIR__, "..", "build", "libtabelline.so"))

lasterror() = unsafe_string(ccall((:tbl_error, lib), Cstring, ()))
check(rc) = rc == 0 || error("tabelline: " * lasterror())
function owned(p::Cstring)
    p == C_NULL && error("tabelline: " * lasterror())
    s = unsafe_string(p)
    ccall((:tbl_free, lib), Cvoid, (Cstring,), p)
    s
end

# -------------------------------------------------------------------- Julia values as JSON

json(io, ::Nothing) = print(io, "null")
json(io, ::Missing) = print(io, "null")
json(io, b::Bool) = print(io, b)
json(io, x::Integer) = print(io, x)
json(io, x::AbstractFloat) = isfinite(x) ? print(io, x) : print(io, "null")
json(io, s::Symbol) = json(io, String(s))
function json(io, s::AbstractString)
    print(io, '"')
    for c in s
        c == '"' ? print(io, "\\\"") : c == '\\' ? print(io, "\\\\") :
        c < ' ' ? print(io, "\\u", string(UInt16(c), base = 16, pad = 4)) : print(io, c)
    end
    print(io, '"')
end
function json(io, xs::Union{AbstractVector, Tuple})
    print(io, '[')
    for (i, x) in enumerate(xs); i > 1 && print(io, ','); json(io, x); end
    print(io, ']')
end
function jsonpairs(io, ps)
    print(io, '{')
    for (i, (k, v)) in enumerate(ps); i > 1 && print(io, ','); json(io, string(k)); print(io, ':'); json(io, v); end
    print(io, '}')
end
json(io, nt::NamedTuple) = jsonpairs(io, pairs(nt))
json(io, d::AbstractDict) = jsonpairs(io, pairs(d))
json(io, p::Pair) = jsonpairs(io, (p,))
json(x) = sprint(json, x)

"Markdown text, for a label or a note."
md(s) = (md = s,)
"Raw HTML text."
html(s) = (html = s,)

# ------------------------------------------------------------------------------------ tables

mutable struct Tabella
    h::Ptr{Cvoid}
    function Tabella()
        t = new(ccall((:tbl_new, lib), Ptr{Cvoid}, ()))
        finalizer(t -> ccall((:tbl_drop, lib), Cvoid, (Ptr{Cvoid},), t.h), t)
    end
end

addcol(t, name, v::AbstractVector{<:Bool}) =
    check(ccall((:tbl_add_bools, lib), Cint, (Ptr{Cvoid}, Cstring, Ptr{UInt8}, Csize_t), t.h, name, UInt8.(v), length(v)))
addcol(t, name, v::AbstractVector{<:Integer}) =
    check(ccall((:tbl_add_ints, lib), Cint, (Ptr{Cvoid}, Cstring, Ptr{Int64}, Csize_t), t.h, name, Int64.(v), length(v)))
addcol(t, name, v::AbstractVector{<:Union{Missing, Real}}) =
    check(ccall((:tbl_add_doubles, lib), Cint, (Ptr{Cvoid}, Cstring, Ptr{Float64}, Csize_t), t.h, name,
                Float64[ismissing(x) ? NaN : Float64(x) for x in v], length(v)))
function addcol(t, name, v::AbstractVector{<:Union{Missing, AbstractString}})
    ptrs = [ismissing(s) ? Cstring(C_NULL) : Base.unsafe_convert(Cstring, s) for s in v]
    GC.@preserve v check(ccall((:tbl_add_strings, lib), Cint, (Ptr{Cvoid}, Cstring, Ptr{Cstring}, Csize_t),
                               t.h, name, ptrs, length(v)))
end
addcol(t, name, v::AbstractVector) =
    check(ccall((:tbl_add_json, lib), Cint, (Ptr{Cvoid}, Cstring, Cstring), t.h, name, json(collect(v))))

"""
    tabella(columns; rownameCol = "", groupnameCol = "", id = "", locale = "")

A table from columns: a NamedTuple of vectors (or anything with `pairs`, such as a Dict, or a
DataFrame's `eachcol` pairs).
"""
function tabella(columns; settings...)
    t = Tabella()
    for (name, v) in pairs(columns); addcol(t, string(name), v); end
    for (k, v) in settings
        check(ccall((:tbl_set, lib), Cint, (Ptr{Cvoid}, Cstring, Cstring), t.h, string(k), string(v)))
    end
    t
end

"Any verb, by its name in the library (case and underscores ignored)."
function verb(t::Tabella, name, args...; kw...)
    a = isempty(kw) ? json(collect(args)) :
        isempty(args) ? json(NamedTuple(kw)) : json(merge((_args = collect(args),), NamedTuple(kw)))
    check(ccall((:tbl_verb, lib), Cint, (Ptr{Cvoid}, Cstring, Cstring), t.h, string(name), a))
    t
end
verb(name, args...; kw...) = t -> verb(t, name, args...; kw...)

render(t::Tabella, format = "html") = owned(ccall((:tbl_render, lib), Cstring, (Ptr{Cvoid}, Cstring), t.h, format))
Base.show(io::IO, ::MIME"text/html", t::Tabella) = print(io, render(t, "html"))
Base.show(io::IO, ::MIME"text/plain", t::Tabella) = print(io, render(t, "text"))

snake(s) = lowercase(replace(s, r"([a-z0-9])([A-Z])" => s"\1_\2"))

# One Julia function per verb, from the library's own list.
const verbnames = unique(m.captures[1] for m in eachmatch(r"\"verb\":\"(\w+)\"", owned(ccall((:tbl_verbs, lib), Cstring, ()))))
for v in verbnames
    f = Symbol(snake(v))
    @eval begin
        $f(t::Tabella, args...; kw...) = verb(t, $v, args...; kw...)
        $f(args...; kw...) = t -> verb(t, $v, args...; kw...)
        export $f
    end
end

end
