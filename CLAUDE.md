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

## Union/Intersection Type Narrowing in Entailment (Active Development)

### Feature: subtype preserves constraints across union/intersection annotations

**Problem:** `checkentail x:int & x > 0 |- x:int\/bool & x > 0` was failing with
`TYPE ERROR 1: Found int\/boolean but expecting NUM`.

**Root cause** (`src/typeinfer.ml`, function `unify_type_modify`, inner `unify`):
When the found type `t1` (e.g., `Int` from LHS) is a subtype of the expected type `t2`
(e.g., `Union(Int,Bool)` from the RHS annotation), the old code widened x's type to
`Union(Int,Bool)`. Subsequent pure constraints like `x > 0` then failed because
`Union(Int,Bool)` is not numeric.

**Fix** (`src/typeinfer.ml:239`): When `sub_type t1 t2` and `t2` is `Union _` or
`Intersection _`, keep the more specific found type `t1` instead of widening to `t2`:
```ocaml
if sub_type t1 t2 then (
  match t2 with
  | Union _ | Intersection _ -> (tlist, Some k1)  (* keep specific found type *)
  | _ -> (tlist, Some k2))
```

**Why it is general:** applies to any found type being a subtype of any union or
intersection annotation — not just `int` vs `int\/bool`. The narrower LHS type is
always more informative than the compound RHS annotation.

**Known pre-existing failures (unrelated):**
- Test 38: `x:int |- x:NUM` — `NUM` is parsed as `TypeVar["NUM"]` instead of the
  primitive `NUM` type (parser issue, not fixed here)
- Test 39: `x:float |- x:NUM` — same parser issue
- Test 66: `x:int/\str |- x:int/\str` — structural `sub_type` incorrectly rejects
  `Intersection(A,B) ≤ Intersection(A,B)` when A and B are unrelated (see SMT section).
  Fixed by `--smt-subtype`.

## SMT-Based Subtype Checking (Alternative Mode)

### Overview

An alternative subtype checker uses Z3 directly instead of the recursive structural
decomposition. Enable it with:

```bash
dune exec ./sleek.exe -- --smt-subtype <file.slk>
```

### Key files

| File | Role |
|------|------|
| `common/globals.ml` | `use_smt_subtype : bool ref` flag; `smt_sub_type_ref : (typ → typ → bool) ref` indirection |
| `common/smtsolver.ml` | `smt_sub_type` implementation; wires itself into `smt_sub_type_ref` at module load |
| `common/exc.ml` | `sub_type` dispatches to SMT or structural; internal recursion is `sub_type_structural` |
| `src/scriptarguments.ml` | `--smt-subtype` CLI flag registration |

### Why a ref indirection

`exc.ml` must not import `smtsolver.ml` (it would create a circular dependency since
`smtsolver.ml` transitively depends on `cpure.ml` which depends on things below `exc.ml`
in the build order). The solution: `globals.ml` holds a `smt_sub_type_ref` initialised
to `fun _ _ -> false`; `smtsolver.ml` overwrites it with the real implementation at
module initialisation (`let () = Globals.smt_sub_type_ref := smt_sub_type`).

### SMT encoding

The core idea: interpret each type `T` as the **set of values** inhabiting it.
Subtyping `T1 ≤ T2` is set inclusion. To check it, negate and ask Z3:

> Is `∃ witness. encode(T1, witness) ∧ ¬encode(T2, witness)` satisfiable?
> UNSAT → T1 ≤ T2.   SAT → T1 ≢ T2.

**Type encoding** (`encode T witness` produces an SMT Boolean expression):

```
encode(Int,                v) = (is_Int v)
encode(Bool,               v) = (is_Bool v)
encode(Float,              v) = (is_Float v)
encode(NUM,                v) = (is_NUM v)
encode(Void,               v) = (is_Void v)
encode(TypeVar "X",        v) = (is_TypeVar_X v)     -- uninterpreted predicate
encode(Named("C", _),      v) = (is_Named_C v)        -- uninterpreted predicate
encode(Union(A, B),        v) = (or  (encode A v) (encode B v))
encode(Intersection(A, B), v) = (and (encode A v) (encode B v))
```

Compound types are inlined — no recursive SMT function needed.

**Full query skeleton** (sent via `check_formula` into the running Z3 process):

```smt2
(declare-sort SMTValue 0)

; One uninterpreted predicate per leaf type that appears in T1 or T2
(declare-fun is_Int   (SMTValue) Bool)
(declare-fun is_Bool  (SMTValue) Bool)
(declare-fun is_Float (SMTValue) Bool)
(declare-fun is_NUM   (SMTValue) Bool)
; ... TypeVar and Named predicates as needed ...

; Inhabitedness: every leaf type has at least one value
(declare-const smt_wit_is_Int   SMTValue) (assert (is_Int   smt_wit_is_Int))
(declare-const smt_wit_is_Bool  SMTValue) (assert (is_Bool  smt_wit_is_Bool))
; ...

; Primitive subtype axioms
(assert (forall ((v SMTValue)) (=> (is_Int   v) (is_NUM v))))
(assert (forall ((v SMTValue)) (=> (is_Float v) (is_NUM v))))

; Disjointness: the witness of one base type does not belong to another
(assert (not (is_Bool  smt_wit_is_Int)))
(assert (not (is_Int   smt_wit_is_Bool)))
; ... all known disjoint pairs ...

; Negated subtype query
(declare-const smt_sub_witness SMTValue)
(assert (and <encode T1 smt_sub_witness>
             (not <encode T2 smt_sub_witness>)))
(check-sat)
```

The query is wrapped with `(push)/(pop)` by `check_formula` so it does not pollute the
incremental Z3 session state.

**TypeVar equality constraints** (future extension): if the LHS pure formula contains
`T = U`, assert `(forall ((v SMTValue)) (= (is_TypeVar_T v) (is_TypeVar_U v)))` before
the negated query. This lets Z3 prove `list[T] * list[U] & T=U |- list[T] * list[V]`
correctly without relying on name-equality heuristics.

### Structural algorithm incompleteness (why SMT gives different results)

The structural `sub_type_structural` uses OCaml pattern matching. When **both** sides
are `Intersection`, the left-intersection pattern fires first:

```ocaml
| Intersection(t1, t2), t -> sub_type_structural t1 t || sub_type_structural t2 t
```

For `Intersection(A,B) ≤ Intersection(A,B)` this expands to:
```
(A ≤ Intersection(A,B)) ∨ (B ≤ Intersection(A,B))
= ((A≤A)∧(A≤B)) ∨ ((B≤A)∧(B≤B))
```
which is `false` when `A` and `B` are unrelated types (e.g. `Int` and `Named "str"`),
even though the relation is trivially reflexive.

The SMT encoding is immune to this because `encode(T,v) ∧ ¬encode(T,v)` is always UNSAT
by propositional tautology, regardless of the structure of `T`.

**Verified comparison** (full `typetest.slk` run): all 78 tests give identical verdicts
between structural and SMT modes **except Test 66**, where:
- Structural: `EXCast / UNIFICATION ERROR: types int/\str and int/\str are inconsistent`
- SMT (`--smt-subtype`): `Valid`

The SMT result is correct. Test 66 is the only test where the two modes disagree.
