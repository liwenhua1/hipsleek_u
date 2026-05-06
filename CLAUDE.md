# HipSleek Project — Claude Context

## Build & Run

```bash
eval $(opam env)   # needed once per terminal (added to ~/.bashrc — automatic on new terminals)
dune exec ./sleek.exe <file.slk>
dune exec ./hip.exe <file.ss>
```

Primary test file: `typetest.slk` (in project root).

## Environment

- OCaml 4.10.0 via opam (`~/.opam/4.10.0`)
- Build system: dune
- Key opam packages: `xml-light`, `cppo`, `z3`, `fileutils`, `batteries`, `ocamlgraph`, `camlp4`
- Running on WSL2 (Windows Subsystem for Linux)

## WSL2-Specific Fixes Applied

### `FileUtil.which` crashes on WSL2 (EACCES on Windows AppData paths)

**Problem:** `FileUtil.which` iterates all PATH entries including inaccessible Windows paths like
`/mnt/c/WINDOWS/system32/config/systemprofile/AppData/Local/Microsoft/WindowsApps/...`.
The `Unix.lstat` call on these raises `Unix.Unix_error(EACCES)`, which was not caught.

**Fix:** Added `| Unix.Unix_error _ -> ""` alongside the existing `| Not_found -> ""` in all
`FileUtil.which` call sites. This is safe on non-WSL2 machines — `Unix.Unix_error` is never
raised there, so the new handler is dead code on those machines.

**Files changed:**
- `common/smtsolver.ml:786` — searching for `z3-4.3.2`
- `common/omega.ml:249` — searching for `oc`
- `common/redlog.ml:133` — searching for `redcsl`
- `src/isabelle.ml:21` — searching for `MyImage`
- `src/isabelle.ml:284` — searching for `MyImage`
- `src/isabelle.ml:462` — searching for `MyImage`
- `src/minisat.ml:28` — searching for `minisat`
- `src/mona.ml:39` — searching for `mona_inter`
- `src/fixcalc.ml:349` — searching for `fixcalc`
- `src/tpdispatcher.ml:353` — searching for `mona`
- `src/tpdispatcher.ml:395` — searching for `redcsl`
- `src/share_prover_w2.ml:169` — searching for `minisat`
- `src/other/shares_z3_lib.ml:419` — searching for `minisat`

## Key Source Files

| File | Role |
|------|------|
| `sleek.ml` | Sleek entrypoint |
| `hip.ml` | Hip entrypoint |
| `src/typechecker.ml` | Type checker (large file, active development) |
| `common/smtsolver.ml` | Z3/SMT solver integration |
| `common/parser.ml` | Common parser |
| `src/tpdispatcher.ml` | Theorem prover dispatcher (mona, z3, redlog, etc.) |
| `src/isabelle.ml` | Isabelle prover integration |
| `src/minisat.ml` | MiniSAT integration |
| `typetest.slk` | Primary test file for sleek |

## OCaml 5.x Compatibility

`String.lowercase` and `String.uppercase` were replaced with `String.lowercase_ascii` and
`String.uppercase_ascii` throughout for OCaml 5.3 compatibility (commit `79f91967b`).

## Type Variable Entailment Checking (Active Development)

### Feature: polymorphic data declarations with type parameters

Data declarations support type parameters, e.g. `data list[T] { ... }`. Entailment checking
for separation logic formulas must account for these type parameters.

**Key representation facts:**
- Heap node type params stored in `CF.h_formula_data_type_params : typ list` as `TypeVar of ident` (e.g. `TypeVar "T"`)
- Type variable equalities in the LHS pure formula (e.g. `& T=U`) appear as `CP.SpecVar(TVar _, "T") = CP.SpecVar(TVar _, "U")` — note the variable *name* carries the type var identity, not the `TVar` index
- Use `MCP.pure_of_mix l_p` to extract a `CP.formula` from the LHS `mix_formula`

**Fix: `src/solver.ml` around line 10880** (`match (l_node, r_node)` DataNode branch)

Old code allowed any `TypeVar` to unify with anything:
```ocaml
| TypeVar _, _ | _, TypeVar _ -> true   (* too permissive *)
```

New code:
1. Collects type variable equalities from the LHS pure formula by scanning for
   `CP.Eq(CP.Var(SpecVar(TVar _, n1)), CP.Var(SpecVar(TVar _, n2)))` conjuncts
2. `TypeVar a` is compatible with `TypeVar b` only if `a = b` or `(a,b)` (or `(b,a)`) appears in those equalities

**Tests in `typetest.slk`:**
- Test 75: `list[T] * list[U] |- list[T] * list[T]` → **Fail** (T ≠ U, no constraint)
- Test 76: `list[T] * list[U] & T=U |- list[T] * list[T]` → **Valid** (T=U makes it hold)
- Test 77: `list[T] * list[U] & T=U |- list[T] * list[V]` → **Fail** (T=U does not imply T=V)
