#include "xdebug.cppo"
(*
  Created 19-Feb-2006

  Input pure constraints, including arithmetic and pure pointer
*)

open Globals
open Gen.Basic
open VarGen
(* open Label_only *)
open Label
module LO = Label_only.LOne

type spec_var = ident * primed

type xpure_view = {
  xpure_view_node : ident option;
  xpure_view_name : ident;
  xpure_view_arguments : ident list;
  xpure_view_remaining_branches :  (formula_label list) option;
  xpure_view_pos : loc;
  (* xpure_view_derv : bool; *)
  (* xpure_view_imm : ann; *)
  (* xpure_view_perm : cperm; (\*LDK: permission*\) *)
  (* xpure_view_arguments : CP.spec_var list; *)
  (* xpure_view_modes : mode list; *)
  (* xpure_view_coercible : bool; *)
  (* (\* if this view is generated by a coercion from another view c,  *)
  (*    then c is in xpure_view_origins. Used to avoid loopy coercions *\) *)
  (* xpure_view_origins : ident list; *)
  (* xpure_view_original : bool; *)
  (* xpure_view_lhs_case : bool; (\* to allow LHS case analysis prior to unfolding and lemma *\) *)
  (* (\* to allow LHS case analysis prior to unfolding and lemma *\) *)
  (* xpure_view_unfold_num : int; (\* to prevent infinite unfolding *\) *)
  (* (\* xpure_view_orig_fold_num : int; (\\* depth of originality for folding *\\) *\) *)
  (* (\* used to indicate a specialised view *\) *)
  (* xpure_view_pruning_conditions :  (CP.b_formula * formula_label list ) list; *)
  (* xpure_view_label : formula_label option; *)
}

type ann = ConstAnn of heap_ann | PolyAnn of ((ident * primed) * loc) | NoAnn

(*annotations *)
let imm_ann_top = ConstAnn imm_top
let imm_ann_bot = ConstAnn imm_bot

type formula = 
  | BForm of (b_formula*(formula_label option))
  | And of (formula * formula * loc)
  | AndList of (LO.t * formula) list
  | Or of (formula * formula *(formula_label option) * loc)
  | Not of (formula *(formula_label option)* loc)
  | Forall of ((ident * primed) * formula *(formula_label option)* loc)
  | Exists of (( ident * primed) * formula *(formula_label option)* loc)

(* Boolean constraints *)
and b_formula = p_formula * ((bool * int * (exp list)) option)
(* (is_linking, label, list of linking expressions in b_formula) *)

and p_formula = 
  | Frm of ((ident * primed) * loc)
  | XPure of xpure_view
  | BConst of (bool * loc)
  | BVar of ((ident * primed) * loc)
  (* Ann Subtyping v1 <: v2 *)
  | SubAnn of (exp * exp * loc) 
  | Lt of (exp * exp * loc)
  | Lte of (exp * exp * loc)
  | Gt of (exp * exp * loc)
  | Gte of (exp * exp * loc)
  | Eq of (exp * exp * loc) (* these two could be arithmetic or pointer or bags or lists *)
  | Neq of (exp * exp * loc)
  | EqMax of (exp * exp * exp * loc) (* first is max of second and third *)
  | EqMin of (exp * exp * exp * loc) (* first is min of second and third *)
  (* bags and bag formulae *)
  | LexVar of (term_ann * (exp list) * (exp list) * loc)
  | BagIn of ((ident * primed) * exp * loc)
  | BagNotIn of ((ident * primed) * exp * loc)
  | BagSub of (exp * exp * loc)
  | BagMin of ((ident * primed) * (ident * primed) * loc)
  | BagMax of ((ident * primed) * (ident * primed) * loc)
  (* lists and list formulae *)
  (* | VarPerm of (vp_ann * ((ident * primed) list) * loc) *)
  | ListIn of (exp * exp * loc)
  | ListNotIn of (exp * exp * loc)
  | ListAllN of (exp * exp * loc)  (* allN 0 list *)
  | ListPerm of (exp * exp * loc)  (* perm L2 L2 *)
  (* | HRelForm of (ident * (exp list) * loc) *)
  | RelForm of (ident * (exp list) * loc)           (* An Hoa: Relational formula to capture relations, for instance, s(a,b,c) or t(x+1,y+2,z+3), etc. *)
  | ImmRel of (p_formula * imm_ann * loc)

and term_ann = 
  | Term    (* definite termination *)
  | Loop    (* definite non-termination *)
  | MayLoop (* possible non-termination *)
  | Fail of term_fail (* Failure because of invalid trans *)
  | TermU of uid  (* unknown precondition, need to be inferred *)
  | TermR of uid  (* unknown postcondition, need to be inferred *)

and uid = {
  tu_id: int;
  tu_sid: ident;
  tu_fname: ident;
  tu_args: exp list;
  tu_cond: formula; 
  tu_pos: loc;
}

and term_fail =
  | TermErr_May
  | TermErr_Must

and imm_ann = 
  | PreImm of p_formula
  | PostImm of p_formula

(* Expression *)
and exp = 
  | Ann_Exp of (exp * typ * loc)
  | Null of loc
  | Level of ((ident * primed) * loc)
  | Var of ((ident * primed) * loc)
  (* variables could be of type pointer, int, bags, lists etc *)
  | IConst of (int * loc)
  | FConst of (float * loc)
  | AConst of (heap_ann * loc)
  | InfConst of (ident * loc) (* Constant for Infinity  *)
  | NegInfConst of (ident * loc) (* Constant for Negative Infinity *)
  | Tsconst of (Tree_shares.Ts.t_sh * loc)
  | Bptriple of ((exp * exp * exp) * loc) (*triple for bounded permissions*)
  | Tup2 of ((exp * exp) * loc) (* a pair *)
  (*| Tuple of (exp list * loc)*)
  | Add of (exp * exp * loc)
  | Subtract of (exp * exp * loc)
  | Mult of (exp * exp * loc)
  | Div of (exp * exp * loc)
  | Max of (exp * exp * loc)
  | Min of (exp * exp * loc)
  | TypeCast of (typ * exp * loc)
  (* bag expressions *)
  | Bag of (exp list * loc)
  | BagUnion of (exp list * loc)
  | BagIntersect of (exp list * loc)
  | BagDiff of (exp * exp * loc)
  (* list expressions *)
  | List of (exp list * loc)
  | ListCons of (exp * exp * loc)
  | ListHead of (exp * loc)
  | ListTail of (exp * loc)
  | ListLength of (exp * loc)
  | ListAppend of (exp list * loc)
  | ListReverse of (exp * loc)
  | ArrayAt of ((ident * primed) * (exp list) * loc)      (* An Hoa : array access, extend the index to a list of indices for multi-dimensional array *)
  | Func of (ident * (exp list) * loc)
  | BExpr of formula
  | Template of template

and template = {
  (* ax + by + cz + d *)
  templ_id: ident;
  templ_args: exp list; (* [x, y, z] *)
  templ_unks: exp list; (* [a, b, c, d] *)
  templ_body: exp option;
  templ_pos: loc;
}

and relation = (* for obtaining back results from Omega Calculator. Will see if it should be here*)
  | ConstRel of bool
  | BaseRel of (exp list * formula)
  | UnionRel of (relation * relation)

(* let print_formula = ref (fun (c:formula) -> "cpure printer has not been initialized") *)
(* let print_id = ref (fun (c:(ident*primed)) -> "cpure printer has not been initialized") *)

(* module Exp_Pure = *)
(* struct  *)
(*   type e = formula *)
(*   let comb x y = And (x,y,no_pos) *)
(*   let string_of = !print_formula *)
(*   let ref_string_of = print_formula *)
(* end;; *)

(* module Label_Pure = LabelExpr(Lab_List)(Exp_Pure);;  *)

let string_of_ann ann =
  match ann with
  | ConstAnn ha -> "ConstAnn " ^ (string_of_heap_ann ha)
  | PolyAnn _ -> "PolyAnn"
  | NoAnn -> "NoAnn"
