(*
  Create the input file for Coq
*)

open Globals
module CP = Cpure

let coq_file_number = ref 0
let result_file_name = "res"
let log_all_flag = ref false
let log_file = open_out "allinput.v"
let max_flag = ref false
let choice = ref 1
let bag_flag = ref false

(* pretty printing for primitive types *)
let coq_of_prim_type = function
  | Bool          -> "int"
  | Float         -> "float"	(* all types will be ints. *)
  | Int           -> "int"
  | Void          -> "unit" 	(* all types will be ints. *)
  | Bag		      -> "int set"
;;

(* pretty printing for spec_vars *)
let coq_of_spec_var (sv : CP.spec_var) = match sv with
  | CP.SpecVar (_, v, p) -> v ^ (if CP.is_primed sv then Oclexer.primed_str else "")

(*----------------------------------*)
(* checking if exp contains bags *)
let rec is_bag_exp e0 = match e0 with
  | CP.Var (CP.SpecVar(t, _, _), _) ->
	if (CP.is_int_type t) then true
	else false
  | CP.Bag (_, _)
  | CP.BagUnion (_, _)
  | CP.BagIntersect (_, _)
  | CP.BagDiff (_, _, _) -> true
  | _ -> false


(* checking if b formula contains bags *)
and is_bag_b_formula b = match b with
  | CP.Eq (a1, a2, _)
  | CP.Neq (a1, a2, _) -> ((is_bag_exp a1) || (is_bag_exp a2))
  | CP.BagIn (_, _, _)
  | CP.BagNotIn (_, _, _)
  | CP.BagSub (_, _, _)
  | CP.BagMin (_, _, _)
  | CP.BagMax (_, _, _) -> true
  | _ -> false

(*----------------------------------*)

(* pretty printing for expressions *)
let rec coq_of_exp e0 = match e0 with
  | CP.Null _ -> "0"
  | CP.Var (sv, _) -> coq_of_spec_var sv
  | CP.IConst (i, _) -> string_of_int i
  | CP.Add (a1, a2, _) ->  " ( " ^ (coq_of_exp a1) ^ " + " ^ (coq_of_exp a2) ^ ")"
  | CP.Subtract (a1, a2, _) ->  " ( " ^ (coq_of_exp a1) ^ " - " ^ (coq_of_exp a2) ^ ")"
  | CP.Mult (c, a, _) -> " ( " ^ (string_of_int c) ^ " * " ^ (coq_of_exp a)	^ ")"
  | CP.Max _
  | CP.Min _ -> failwith ("coq.coq_of_exp: min/max can never appear here")
  | _ -> failwith ("No bags in Coq yet")

(* pretty printing for a list of expressions *)
and coq_of_formula_exp_list l = match l with
  | []         -> ""
  | h::[]      -> coq_of_exp h
  | h::t       -> (coq_of_exp h) ^ ", " ^ (coq_of_formula_exp_list t)


(* pretty printing for boolean vars *)
and coq_of_b_formula b = match b with
  | CP.BConst (c, _) -> if c then "True" else "False"
  | CP.BVar (bv, _) -> "(" ^ (coq_of_spec_var bv) ^ " = 1)"
  | CP.Lt (a1, a2, _) -> " ( " ^ (coq_of_exp a1) ^ " < " ^ (coq_of_exp a2) ^ ")"
  | CP.Lte (a1, a2, _) -> " ( " ^ (coq_of_exp a1) ^ " <= " ^ (coq_of_exp a2) ^ ")"
  | CP.Gt (a1, a2, _) -> " ( " ^ (coq_of_exp a1) ^ " > " ^ (coq_of_exp a2) ^ ")"
  | CP.Gte (a1, a2, _) -> "(" ^ (coq_of_exp a1) ^ " >= " ^ (coq_of_exp a2) ^ ")"
  | CP.Eq (a1, a2, _) -> " ( " ^ (coq_of_exp a1) ^ " = " ^ (coq_of_exp a2) ^ ")"
  | CP.Neq (a1, a2, _) -> "( " ^ (coq_of_exp a1) ^ " <> " ^ (coq_of_exp a2) ^ ")"
  | CP.EqMax (a1, a2, a3, _) ->
	  let a1str = coq_of_exp a1 in
	  let a2str = coq_of_exp a2 in
	  let a3str = coq_of_exp a3 in
	      "((" ^ a1str ^ " = " ^ a3str ^ " /\\ " ^ a3str ^ " > " ^ a2str ^ ") \\/ ("
	      ^ a2str ^ " >= " ^ a3str ^ " /\\ " ^ a1str ^ " = " ^ a2str ^ "))" ^ Util.new_line_str;
  | CP.EqMin (a1, a2, a3, _) ->
	  let a1str = coq_of_exp a1 in
	  let a2str = coq_of_exp a2 in
	  let a3str = coq_of_exp a3 in
          "((" ^ a1str ^ " = " ^ a3str ^ " /\\ " ^ a2str ^ " >= " ^ a3str ^ ") \\/ ("
	   ^ a2str ^ " <= " ^ a3str ^ " /\\ " ^ a1str ^ " = " ^ a2str ^ "))" ^ Util.new_line_str
  | _ -> failwith ("No bags in Coq yet")

(* pretty printing for formulas *)
and coq_of_formula f =
    match f with
    | CP.BForm b -> "(" ^ (coq_of_b_formula b) ^ ")"
    | CP.Not (p, _) ->
	    begin match p with
		| CP.BForm (CP.BVar (bv, _)) -> (coq_of_spec_var bv) ^ " = 0"
		| _ -> " (~ (" ^ (coq_of_formula p) ^ ")) "
        end
    | CP.Forall (sv, p, _) ->
	    " (forall " ^ (coq_of_spec_var sv) ^ "," ^ (coq_of_formula p) ^ ") "
    | CP.Exists (sv, p, _) ->
	    " (exists " ^ (coq_of_spec_var sv) ^ ":Z," ^ (coq_of_formula p) ^ ") "
    | CP.And (p1, p2, _) ->
	    "(" ^ (coq_of_formula p1) ^ " /\\ " ^ (coq_of_formula p2) ^ ")"
    | CP.Or (p1, p2, _) ->
	    "(" ^ (coq_of_formula p1) ^ " \\/ " ^ (coq_of_formula p2) ^ ")"

(* checking the result given by Coq *)
let rec check fd coq_file_name : bool=
  try while true do
    let line = input_line fd in
    if line = "No subgoals!" then raise Exit else ()
  done; false
  with Exit -> 
    if !log_all_flag==true then
      output_string log_file ("[coq.ml]: --> SUCCESS\n");
    (*ignore (Sys.remove coq_file_name);*)
    true
  | _ ->
	  if !log_all_flag==true then
		output_string log_file ("[coq.ml]: --> Error in file " ^ coq_file_name ^ "\n");
	  (*ignore (Sys.remove coq_file_name);	*)
	  false
;;

let get_vars_formula p = List.map coq_of_spec_var (CP.fv p)

let coq_of_var_list l = String.concat "" (List.map (fun s -> "forall " ^ s ^ ":Z, ") l)

(* writing the Coq file *)
let write (pe : CP.formula) : bool =
  coq_file_number.contents <- !coq_file_number + 1;
  let coq_file_name = "test" ^ string_of_int !coq_file_number ^ ".v" in
  let coq_file = open_out coq_file_name in
  let vstr = coq_of_var_list (Util.remove_dups (get_vars_formula pe)) in
  let fstr = coq_of_formula pe in
  output_string coq_file "Require Import decidez.\n";
(*  output_string coq_file "Require Import PresTac.\n";*)
  output_string coq_file "Set Firstorder Depth 5.\n";
  output_string coq_file ("Lemma test" ^ string_of_int !coq_file_number ^ " : (" ^ vstr ^ fstr ^ ")%Z.\n");
  output_string coq_file ("intros; try do 10 hyp; auto with *; try do 10 hyp; auto with *;try do 10 hyp; auto with *; repeat hyp; auto with *.\nQed.\n"); (* || prestac *)
  flush coq_file;
  close_out coq_file;
  (* if log_all_flag is on -> writing the formula in the coq log file  *)
  if !log_all_flag == true then	begin
    output_string log_file ("  Lemma test" ^ string_of_int !coq_file_number ^ " :\n  " ^ vstr ^ "\n  " ^ fstr ^ ".\n");
	flush log_file;
  end;
  match (Sys.command ("coqc -R ../Presburger Presburger " ^ coq_file_name ^ " > res 2> /dev/null")) with (* -byte *)
  | 0 -> 
      if !log_all_flag==true then output_string log_file ("[coq.ml]: --> SUCCESS\n");
      true
  | _ ->
      if !log_all_flag==true then output_string log_file ("[coq.ml]: --> FAIL\n");
      false

let imply (ante : CP.formula) (conseq : CP.formula) : bool =
  if !log_all_flag == true then
	output_string log_file "\n[coq.ml]: #imply\n";
  max_flag := false;
  choice := 1;
  write (CP.mkOr (CP.mkNot ante no_pos) conseq no_pos)

let is_sat (f : CP.formula) : bool =
  if !log_all_flag == true then
	output_string log_file "\n[coq.ml]: #is_sat\n";
  let tmp_form = (imply f (CP.BForm(CP.BConst(false, no_pos)))) in
  match tmp_form with
  | true ->
	  if !log_all_flag == true then output_string log_file "[coq.ml]: is_sat --> false\n";
	  false
  | false ->
	  if !log_all_flag == true then output_string log_file "[coq.ml]: is_sat --> true\n";
	  true

let building_image _ = ()

(* TODO: implement the following procedures; now they are only dummies *)
let hull (pe : CP.formula) : CP.formula = begin
	if !log_all_flag == true then
	  output_string log_file "\n[coq.ml]: #hull\n";
	pe
	end
let pairwisecheck (pe : CP.formula) : CP.formula = begin
	if !log_all_flag == true then
	  output_string log_file "\n[coq.ml]: #pairwisecheck\n";
	pe
	end
let simplify (pe : CP.formula) : CP.formula = begin
	if !log_all_flag == true then
	  output_string log_file "\n[coq.ml]: #simplify\n";
	pe
	end