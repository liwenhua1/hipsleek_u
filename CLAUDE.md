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
