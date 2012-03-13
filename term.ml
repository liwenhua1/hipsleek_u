module CP = Cpure
module MCP = Mcpure
module DD = Debug
module TP = Tpdispatcher
module Inf = Infer

open Gen.Basic
open Globals
open Cprinter
open Cformula

type phase_trans = int * int

(* Transition on termination annotation with measures (if any) *)
type term_ann_trans = (term_ann * CP.exp list) * (term_ann * CP.exp list)

(* Transition on program location 
 * src: post_pos
 * dst: proving_loc *)
type term_trans_loc = loc * loc 

type term_reason =
  (* The variance is not well-founded *)
  | Not_Decreasing_Measure of term_ann_trans option   
  | Not_Bounded_Measure of CP.exp list
  (* The variance is well-founded *)
  | Valid_Measure  
  | Decreasing_Measure of term_ann_trans option
  | Bounded_Measure
  (* Reachability *)
  | Base_Case_Reached
  | Non_Term_Reached
  (* Reason for error *)
  | Invalid_Phase_Trans
  | Variance_Not_Given
  | Invalid_Status_Trans of term_ann_trans

(* The termination can only be determined when 
 * a base case or an infinite loop is reached *)  
type term_status =
  | Term_S of term_reason
  | NonTerm_S of term_reason
  | MayTerm_S of term_reason (* used for not decreasing or not bounded measures *)
  | Unreachable
  | UnsoundLoop 
  | TermErr of term_reason (* used for invalid status transition *)

(* Location of the transition (from spec to call),
 * Termination Annotation transition,
 * Context and 
 * Its termination status *)
type term_res = term_trans_loc * term_ann_trans option * formula option * term_status

(* We are only interested in two kinds 
 * of constraints in phase inference:
 * p2>p1 and p2>=p1 *)
exception Invalid_Phase_Constr
type phase_constr =
  | P_Gt of (CP.spec_var * CP.spec_var)  (* p2>p1 *)
  | P_Gte of (CP.spec_var * CP.spec_var) (* p2>=p1 *)

(* Using stack to store term_res *)
let term_res_stk : term_res Gen.stack = new Gen.stack

(* Using stack to store term error messages *)
let term_err_stk : string Gen.stack = new Gen.stack

let add_term_res_stk m = 
  if !Globals.dis_term_msg then ()
  else term_res_stk # push m

let add_term_err_stk m =
  if !Globals.dis_term_msg then ()
  else term_err_stk # push m

(* Using stack to store inferred phase
 * transition constraints by inference *)
let phase_constr_stk : CP.formula Gen.stack = new Gen.stack

(* Using hash table to store inferred 
 * phase transition constraints by 
 * inference by mutual scc group *)
let phase_constr_tbl : (int, (ident * CP.formula list) list) Hashtbl.t = 
  Hashtbl.create 20

(* Printing Utilities *)
let pr_phase_trans (trans: phase_trans) =
  let (src, dst) = trans in
  fmt_string "Transition ";
  pr_int src; fmt_string "->"; pr_int dst

let string_of_phase_trans (trans: phase_trans) = 
  poly_string_of_pr pr_phase_trans trans

let pr_term_ann_trans ((ann_s, m_s), (ann_d, m_d)) =
  (*
  let str_ctx =
    match ctx with
    | None -> ""
    | Some ctx ->
        let mfv = List.fold_left (fun acc e -> 
          acc @ (CP.afv e)) [] (m_s @ m_d) in
        if Gen.is_empty mfv then ""
        else
          let h_f, p_f, _, _, _ = split_components ctx in
          let str_h = 
            if (Gen.BList.overlap_eq CP.eq_spec_var (h_fv h_f) mfv)
            then (string_of_h_formula h_f) ^ " & "
            else ""
          in 
          let str_p =
            let p_f = MCP.pure_of_mix p_f in
            let fs = CP.split_conjunctions p_f in
            let f_fs = List.filter (fun f -> 
              Gen.BList.overlap_eq CP.eq_spec_var (CP.fv f) mfv) fs in
            if Gen.is_empty f_fs then ""
            else 
              poly_string_of_pr (pr_list_op " & " pr_pure_formula) f_fs
          in 
          str_h ^ str_p
  in 
  *)
  fmt_open_hbox();
  (*(if str_ctx == "" then () else fmt_string (str_ctx ^ " & "));*)
  fmt_string (string_of_term_ann ann_s);
  pr_seq "" pr_formula_exp m_s;
  fmt_string " -> ";
  fmt_string (string_of_term_ann ann_d);
  pr_seq "" pr_formula_exp m_d;
  fmt_close_box()

let string_of_term_ann_trans = poly_string_of_pr pr_term_ann_trans

let pr_term_reason = function
  | Not_Decreasing_Measure _ -> fmt_string "The variance is not well-founded (not decreasing)."
  | Not_Bounded_Measure _ -> fmt_string "The variance is not well-founded (not bounded)."
  | Valid_Measure -> fmt_string "The given variance is well-founded."
  | Decreasing_Measure _ -> fmt_string "The variance is decreasing."
  | Bounded_Measure -> fmt_string "The variance is bounded."
  | Base_Case_Reached -> fmt_string "The base case is reached."
  | Non_Term_Reached -> fmt_string "A non-terminating state is reached."
  | Invalid_Phase_Trans -> fmt_string "The phase transition number is invalid."
  | Invalid_Status_Trans trans -> 
      pr_term_ann_trans trans;
      fmt_string " transition is invalid."
  | Variance_Not_Given -> 
      fmt_string "The recursive case needs a given/inferred variance for termination proof."
			
let pr_term_reason_short = function
  | Not_Decreasing_Measure ann_trans -> 
      fmt_string "not decreasing)";
      (match ann_trans with
        | None -> ()
        | Some trans ->  
          fmt_string " ";
          pr_term_ann_trans trans)
  | Decreasing_Measure ann_trans -> 
      fmt_string "decreasing)";
      (match ann_trans with
        | None -> ()
        | Some trans ->  
          fmt_string " ";
          pr_term_ann_trans trans)
  | Not_Bounded_Measure le -> 
      fmt_string "not bounded)";
      pr_seq "" pr_formula_exp le;
  | Bounded_Measure -> fmt_string "bounded)"
  | Invalid_Status_Trans ann_trans ->
      fmt_string "invalid transition)";
      fmt_string " ";
      pr_term_ann_trans ann_trans
  | _ -> ()

let string_of_term_reason (reason: term_reason) =
  poly_string_of_pr pr_term_reason reason

let pr_term_status = function
  | Term_S reason -> fmt_string "Terminating: "; pr_term_reason reason
  | NonTerm_S reason -> fmt_string "Non-terminating: "; pr_term_reason reason
  | MayTerm_S reason -> fmt_string "May-terminating: "; pr_term_reason reason
  | Unreachable -> fmt_string "Unreachable state."
  | UnsoundLoop -> fmt_string "Unsound context with Loop."
  | TermErr reason -> fmt_string "Error: "; pr_term_reason reason

let pr_term_status_short = function
  | Term_S r -> 
      fmt_string "(OK: ";
      pr_term_reason_short r;
      (* fmt_string ")" *)
  | Unreachable -> fmt_string "(UNR)"
  | MayTerm_S r -> 
      fmt_string "(MayTerm ERR: ";
      pr_term_reason_short r;
      (* fmt_string ")" *)
  | UnsoundLoop -> fmt_string "(ERR: unsound Loop (expecting false ctx))"
  | TermErr r -> 
      fmt_string "(ERR: ";
      pr_term_reason_short r
  | NonTerm_S _ -> fmt_string "(NonTerm_S)"

let string_of_term_status = poly_string_of_pr pr_term_status

let pr_term_ctx (ctx: formula) =
  let h_f, p_f, _, _, _ = split_components ctx in
  begin
    fmt_string "Current context";
    fmt_print_newline ();
    pr_wrap_test "heap: " is_true pr_h_formula h_f;
    pr_wrap_test "pure: " MCP.isConstMTrue pr_mix_formula p_f;
    fmt_print_newline ();
  end 

let string_of_term_ctx = poly_string_of_pr pr_term_ctx

let pr_term_trans_loc (src, dst) =
(*  let fname = src.start_pos.Lexing.pos_fname in*)
  let src_line = src.start_pos.Lexing.pos_lnum in
  let dst_line = dst.start_pos.Lexing.pos_lnum in
  (* fmt_string (fname ^ " "); *)
  fmt_string ("(" ^ (string_of_int src_line) ^ ")");
  if (dst_line != 0) then
    (fmt_string ("->");
    fmt_string ("(" ^ (string_of_int dst_line) ^ ")"))

let pr_term_res pr_ctx (pos, trans, ctx, status) =
  pr_term_trans_loc pos;
  fmt_string " ";
  pr_term_status_short status;
  (match ctx with
  | None -> ();
  | Some c -> 
      if pr_ctx then (fmt_string ":\n"; pr_term_ctx c) else (););
  (*
  if pr_ctx then fmt_string ">>>>> " else fmt_string ": ";
  pr_term_status status;
  *)
  if pr_ctx then fmt_print_newline () else ()

let string_of_term_res = poly_string_of_pr (pr_term_res false)

let pr_term_res_stk stk =
  let stk =
    let (err, ok) = List.partition (fun (_, _, _, status) ->
      match status with
      | Term_S _
      | Unreachable -> false
      | _ -> true
    ) stk in
    if (!Globals.term_verbosity == 0) then err@ok
    else err
  in 
  List.iter (fun r -> 
    pr_term_res (!Globals.term_verbosity == 0) r; 
    fmt_print_newline ();) stk

let pr_term_err_stk stk =
  List.iter (fun m -> fmt_string m; fmt_print_newline ()) stk

let pr_phase_constr = function
  | P_Gt (v1, v2) -> 
      pr_spec_var v1; fmt_string ">"; pr_spec_var v2
  | P_Gte (v1, v2) -> 
      pr_spec_var v1; fmt_string ">="; pr_spec_var v2 

let string_of_phase_constr = poly_string_of_pr pr_phase_constr
(* End of Printing Utilities *)

(* To find a LexVar formula *)
exception LexVar_Not_found;;
exception Invalid_Phase_Num;;


(* let rec has_variance_struc struc_f = *)
(*   List.exists (fun ef -> has_variance_ext ef) struc_f *)
  
(* and has_variance_ext ext_f =  *)
(*   match ext_f with *)
(*     | ECase { formula_case_branches = cl } -> *)
(*         List.exists (fun (_, sf) -> has_variance_struc sf) cl *)
(*     | EBase { formula_ext_continuation = cont } -> *)
(*         has_variance_struc cont *)
(*     | EAssume _ -> false *)
(*     | EVariance _ -> true *)
(*     | EInfer {formula_inf_continuation = cont} -> has_variance_ext cont *)
(*
let lexvar_of_evariance (v: ext_variance_formula) : CP.formula option =
  if (v.formula_var_measures = []) then None 
  else
	  let vm = fst (List.split v.formula_var_measures) in
	  let vi = v.formula_var_infer in
    let pos = v.formula_var_pos in
    Some (CP.mkPure (CP.mkLexVar Term vm vi pos))

let measures_of_evariance (v: ext_variance_formula) : (term_ann * CP.exp list * CP.exp list) =
  let vm = fst (List.split v.formula_var_measures) in
	let vi = v.formula_var_infer in
  (Term, vm, vi)
*)
let find_lexvar_b_formula (bf: CP.b_formula) : (term_ann * CP.exp list * CP.exp list * loc) =
  let (pf, _) = bf in
  match pf with
  | CP.LexVar t_info -> (t_info.CP.lex_ann, t_info.CP.lex_exp, t_info.CP.lex_tmp, t_info.CP.lex_loc)
  | _ -> raise LexVar_Not_found

let rec find_lexvar_formula (f: CP.formula) : (term_ann * CP.exp list * CP.exp list * loc) =
  match f with
  | CP.BForm (bf, _) -> find_lexvar_b_formula bf
  | CP.And (f1, f2, _) ->
      (try find_lexvar_formula f1
      with _ -> find_lexvar_formula f2)
  | _ -> raise LexVar_Not_found

(* To syntactically simplify LexVar formula *) 
(* (false,[]) means not decreasing *)
let rec syn_simplify_lexvar bnd_measures =
  match bnd_measures with
  (* 2 measures are identical, 
   * so that they are not decreasing *)
  | [] -> (false, [])   
  | (s,d)::rest -> 
      if (CP.eqExp s d) then syn_simplify_lexvar rest
      else if (CP.is_gt CP.eq_spec_var s d) then (true, [])
      else if (CP.is_lt CP.eq_spec_var s d) then (false, [])
      else (true, bnd_measures) 

let find_lexvar_es (es: entail_state) : 
  (term_ann * CP.exp list * CP.exp list) =
  match es.es_var_measures with
  | None -> raise LexVar_Not_found
  | Some (t_ann, el, il) -> (t_ann, el, il)

let zero_exp = [CP.mkIConst 0 no_pos]
 
let one_exp = [CP.mkIConst 1 no_pos] 

(* Normalize the longer LexVar prior to the shorter one *)
let norm_term_measures_by_length src dst =
  let sl = List.length src in
  let dl = List.length dst in
  (* if dl==0 && sl>0 then None *)
  (* else *)
  if (sl = dl) then Some (src, dst)
  else if (sl > dl) then
    if dl=0 then None
    else Some ((Gen.BList.take dl src)@one_exp, dst@zero_exp)
  else Some (src, Gen.BList.take sl dst)

let strip_lexvar_mix_formula (mf: MCP.mix_formula) =
  let mf_p = MCP.pure_of_mix mf in
  let mf_ls = CP.split_conjunctions mf_p in
  let (lexvar, other_p) = List.partition (CP.is_lexvar) mf_ls in
  (lexvar, CP.join_conjunctions other_p)

(* Termination: The boundedness checking for HIP has been done before *)  
let check_term_measures estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p src_lv dst_lv t_ann_trans pos =
  let ans  = norm_term_measures_by_length src_lv dst_lv in
  let l_pos = post_pos # get in
  let l_pos = if l_pos == no_pos then pos else l_pos in (* Update pos for SLEEK output *)
  let term_pos = (l_pos, proving_loc # get) in
  match ans with
      (* From primitive calls - 
       * Do not need to add messages to stack *)
    | None -> (estate, lhs_p, rhs_p, None)     
    | Some (src_lv, dst_lv) ->
        (* TODO : Let us assume Term[] is for base-case
           and primitives. In the case of non-primitive,
           it will be converted to Term[call] using
           the call hierarchy. No need for Term[-1]
           and some code dealing with primitives below *)
        let orig_ante = estate.es_formula in
        (* [s1,s2] |- [d1,d2] -> [(s1,d1), (s2,d2)] *)
        let bnd_measures = List.map2 (fun s d -> (s, d)) src_lv dst_lv in
        (* [(0,0), (s2,d2)] -> [(s2,d2)] *)
        let res, bnd_measures = syn_simplify_lexvar bnd_measures in
        if bnd_measures = [] then 
          let t_ann, ml, il = find_lexvar_es estate in
          (* Residue of the termination,
           * The termination checking result - 
           * For HIP: stored in term_res_stk
           * For SLEEK: stored in the stack of error msg (es_var_stack) 
           * and update es_term_err *)
          let term_measures, term_res, term_err_msg =
            if res then (* The measures are decreasing *)
              Some (t_ann, ml, il), (* Residue of termination *)
              (term_pos, t_ann_trans, Some orig_ante, Term_S (Decreasing_Measure t_ann_trans)),
              None
            else 
              Some (Fail TermErr_May, ml, il),
              (term_pos, t_ann_trans, Some orig_ante, MayTerm_S (Not_Decreasing_Measure t_ann_trans)),
              Some (string_of_term_res (term_pos, t_ann_trans, None, MayTerm_S (Not_Decreasing_Measure t_ann_trans))) 
          in
          let term_stack = match term_err_msg with
            | None -> estate.es_var_stack
            | Some msg -> msg::estate.es_var_stack 
          in
          let n_estate = { estate with
            es_var_measures = term_measures;
            es_var_stack = term_stack;
            es_term_err = term_err_msg;
          } in
          add_term_res_stk term_res;
          (n_estate, lhs_p, rhs_p, None)
        else
          (* [(s1,d1), (s2,d2)] -> [[(s1,d1)], [(s1,d1),(s2,d2)]]*)
          let lst_measures = List.fold_right (fun bm res ->
            [bm]::(List.map (fun e -> bm::e) res)) bnd_measures [] in
          (* [(s1,d1),(s2,d2)] -> s1=d1 & s2>d2 *)
          let lex_formula measure = snd (List.fold_right (fun (s,d) (flag,res) ->
            let f = 
              if flag then CP.BForm ((CP.mkGt s d pos, None), None) (* s>d *)
              else CP.BForm ((CP.mkEq s d pos, None), None) in (* s=d *)
              (false, CP.mkAnd f res pos)) measure (true, CP.mkTrue pos)) in
          let rank_formula = List.fold_left (fun acc m ->
            CP.mkOr acc (lex_formula m) None pos) (CP.mkFalse pos) lst_measures in
          let lhs = MCP.pure_of_mix (MCP.merge_mems lhs_p xpure_lhs_h1 true) in
          DD.devel_zprint (lazy ("Rank formula: " ^ (Cprinter.string_of_pure_formula rank_formula))) pos;
          (* TODO: rhs_p & rhs_p_br & heap_entail_build_mix_formula_check pos & rank_formula(I,O) *)
          (*let (estate,_,rank_formula,_) = Inf.infer_collect_rel TP.is_sat_raw estate xpure_lhs_h1 
            lhs_p (MCP.mix_of_pure rank_formula) [] (fun i_es_vars i_lhs i_rhs i_pos -> i_lhs, i_rhs) pos in
          let rank_formula = MCP.pure_of_mix rank_formula in*)
          let entail_res, _, _ = TP.imply lhs rank_formula "" false None in 
          begin
            (* print_endline ">>>>>> trans_lexvar_rhs <<<<<<" ; *)
            (* print_endline ("Transformed RHS: " ^ (Cprinter.string_of_mix_formula rhs_p)) ; *)
            DD.devel_zprint (lazy (">>>>>> [term.ml][trans_lexvar_rhs] <<<<<<")) pos;
            DD.devel_zprint (lazy ("Transformed RHS: " ^ (Cprinter.string_of_mix_formula rhs_p))) pos;
            DD.devel_zprint (lazy ("LHS (lhs_p): " ^ (Cprinter.string_of_mix_formula lhs_p))) pos;
            DD.devel_zprint (lazy ("LHS (xpure 0): " ^ (Cprinter.string_of_mix_formula xpure_lhs_h0))) pos;
            DD.devel_zprint (lazy ("LHS (xpure 1): " ^ (Cprinter.string_of_mix_formula xpure_lhs_h1))) pos;
            DD.devel_zprint (lazy ("Wellfoundedness checking: " ^ (string_of_bool entail_res))) pos;
          end;
          let t_ann, ml, il = find_lexvar_es estate in
          let term_measures, term_res, term_err_msg, rank_formula =
            if entail_res then (* Decreasing *) 
              Some (t_ann, ml, il), 
              (term_pos, t_ann_trans, Some orig_ante, Term_S (Decreasing_Measure t_ann_trans)),
              None, 
              None
            else
              if Inf.no_infer_all estate then (* No inference at all*)
                Some (Fail TermErr_May, ml, il),
                (term_pos, t_ann_trans, Some orig_ante, MayTerm_S (Not_Decreasing_Measure t_ann_trans)),
                Some (string_of_term_res (term_pos, t_ann_trans, None, MayTerm_S (Not_Decreasing_Measure t_ann_trans))),
                None
              else
                (* Inference: the es_var_measures will be
                 * changed based on the result of inference 
                 * The term_res_stk and es_var_stack 
                 * should be updated based on this result: 
                 * MayTerm_S -> Term_S *)
		(* Assumming Inference will be successed *)
                Some (t_ann, ml, il),
                (term_pos, t_ann_trans, Some orig_ante, Term_S (Decreasing_Measure t_ann_trans)),
                None, 
                Some rank_formula  
          in 
          let term_stack = match term_err_msg with
            | None -> estate.es_var_stack
            | Some msg -> msg::estate.es_var_stack
          in
          let n_estate = { estate with
            es_var_measures = term_measures;
            es_var_stack = term_stack; 
            es_term_err = term_err_msg
          } in
          add_term_res_stk term_res;
          (n_estate, lhs_p, rhs_p, rank_formula)

let check_term_measures estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p src_lv dst_lv t_ann_trans pos =
  let pr = !print_mix_formula in
  let pr1 = !CP.print_formula in
  let pr2 = !print_entail_state in
  let pr3 = pr_list !CP.print_exp in
  Debug.no_5 "check_term_measures" pr2 
      (add_str "lhs_p" pr) 
      (add_str "rhs_p" pr) 
      (add_str "src_lv" pr3) 
      (add_str "src_rv" pr3)
    (fun (es, lhs, rhs, rank_fml) -> 
        pr_quad pr2 (add_str "lhs" pr) 
            (add_str "rhs" pr) 
            (add_str "rank_fml" (pr_option pr1)) 
            (es, lhs, rhs, rank_fml))  
      (fun _ _ _ _ _ -> check_term_measures estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p src_lv dst_lv t_ann_trans pos) 
        estate lhs_p rhs_p src_lv dst_lv

(* To handle LexVar formula *)
(* Remember to remove LexVar in RHS *)
let check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos =
  try
    begin
      let _ = DD.trace_hprint (add_str "es" !print_entail_state) estate pos in
      let conseq = MCP.pure_of_mix rhs_p in
      let t_ann_d, dst_lv, _, l_pos = find_lexvar_formula conseq in (* [d1,d2] *)
      let t_ann_s, src_lv, src_il = find_lexvar_es estate in
      let t_ann_trans = ((t_ann_s, src_lv), (t_ann_d, dst_lv)) in
      let t_ann_trans_opt = Some t_ann_trans in
      let _, rhs_p = strip_lexvar_mix_formula rhs_p in
      let rhs_p = MCP.mix_of_pure rhs_p in
      let p_pos = post_pos # get in
      let p_pos = if p_pos == no_pos then l_pos else p_pos in (* Update pos for SLEEK output *)
      let term_pos = (p_pos, proving_loc # get) in
      match (t_ann_s, t_ann_d) with
      | (Term, Term)
      | (Fail TermErr_May, Term) ->
          (* Check wellfoundedness of the transition *)
          check_term_measures estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p
            src_lv dst_lv t_ann_trans_opt l_pos
      | (Term, _)
      | (Fail TermErr_May, _) -> 
          let term_res = (term_pos, t_ann_trans_opt, Some estate.es_formula,
            TermErr (Invalid_Status_Trans t_ann_trans)) in
          add_term_res_stk term_res;
          let term_measures = match t_ann_d with
            | Loop 
            | Fail TermErr_Must -> Some (Fail TermErr_Must, src_lv, src_il)
            | MayLoop 
            | Fail TermErr_May -> Some (Fail TermErr_May, src_lv, src_il)      
            | Term -> failwith "unexpected Term in check_term_rhs"
          in 
          let n_estate = {estate with 
            es_var_measures = term_measures;
            es_var_stack = (string_of_term_res term_res)::estate.es_var_stack;
            es_term_err = Some (string_of_term_res term_res);
          } in
          (n_estate, lhs_p, rhs_p, None)
      | (Loop, _) ->
          let term_measures = Some (Loop, [], []) in 
          let n_estate = {estate with es_var_measures = term_measures} in
          (n_estate, lhs_p, rhs_p, None)
      | (MayLoop, _) ->
          let term_measures = Some (MayLoop, [], []) in 
          let n_estate = {estate with es_var_measures = term_measures} in
          (n_estate, lhs_p, rhs_p, None)
      | (Fail TermErr_Must, _) ->
          let n_estate = {estate with 
            es_var_measures = Some (Fail TermErr_Must, src_lv, src_il);
          } in
          (n_estate, lhs_p, rhs_p, None)
    end
  with _ -> (estate, lhs_p, rhs_p, None)

let check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos =
  if (not !Globals.dis_term_chk) or (estate.es_term_err == None) then
    check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos
  else
    (* Remove LexVar in RHS *)
    let _, rhs_p = strip_lexvar_mix_formula rhs_p in
    let rhs_p = MCP.mix_of_pure rhs_p in
    (estate, lhs_p, rhs_p, None)

let check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos =
  let pr = !print_mix_formula in
  let pr2 = !print_entail_state in
   Debug.no_3 "trans_lexvar_rhs" pr2 pr pr
    (fun (es, lhs, rhs, _) -> pr_triple pr2 pr pr (es, lhs, rhs))  
      (fun _ _ _ -> check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos) estate lhs_p rhs_p

let strip_lexvar_lhs (ctx: context) : context =
  let es_strip_lexvar_lhs (es: entail_state) : context =
    let _, pure_f, _, _, _ = split_components es.es_formula in
    let (lexvar, other_p) = strip_lexvar_mix_formula pure_f in
    (* Using transform_formula to update the pure part of es_f *)
    let f_e_f _ = None in
    let f_f _ = None in
    let f_h_f e = Some e in
    let f_m mp = Some (MCP.memoise_add_pure_N_m (MCP.mkMTrue_no_mix no_pos) other_p) in
    let f_a _ = None in
    let f_p_f pf = Some other_p in
    let f_b _ = None in
    let f_e _ = None in
    match lexvar with
    | [] -> Ctx es
    | lv::[] -> 
        let t_ann, ml, il, _ = find_lexvar_formula lv in 
        Ctx { es with 
          es_formula = transform_formula (f_e_f, f_f, f_h_f, (f_m, f_a, f_p_f, f_b, f_e)) es.es_formula;
          es_var_measures = Some (t_ann, ml, il); 
        }
    | _ -> report_error no_pos "[term.ml][strip_lexvar_lhs]: More than one LexVar to be stripped." 
  in transform_context es_strip_lexvar_lhs ctx

let strip_lexvar_lhs (ctx: context) : context =
  let pr = Cprinter.string_of_context in
  Debug.no_1 "strip_lexvar_lhs" pr pr strip_lexvar_lhs ctx

(* End of LexVar handling *) 


(* HIP: Collecting information for termination proof *)
let report_term_error (ctx: formula) (reason: term_reason) pos : term_res =
  let err = (pos, None, Some ctx, TermErr reason) in
  add_term_res_stk err;
  err

let add_unreachable_res (ctx: list_failesc_context) pos : term_res =
  let _ = 
    begin
      DD.devel_zprint (lazy (">>>>>> [term.ml][add_unreachable_res] <<<<<<")) pos;
      DD.devel_hprint (add_str "Context" Cprinter.string_of_list_failesc_context) ctx pos
    end
  in
  let term_pos = (post_pos # get, proving_loc # get) in
  let succ_ctx = succ_context_of_list_failesc_context ctx in
  let orig_ante_l = List.concat (List.map collect_orig_ante succ_ctx) in
  let orig_ante = formula_of_disjuncts orig_ante_l in
  let term_res = (term_pos, None, Some orig_ante, Unreachable) in
  add_term_res_stk term_res;
  term_res

(*
(* let get_phase_num (measure: ext_variance_formula) : int = *)
(*   let phase_num = fst (List.nth measure.formula_var_measures 1) in *)
(*   if (CP.is_num phase_num) then CP.to_int_const phase_num CP.Floor  *)
(*   else raise Invalid_Phase_Num  *)
*)

(*  
(* let check_reachable_term_measure f (ctx: context) (measure: ext_variance_formula) pos : term_res = *)
(*   let orig_ante = formula_of_context ctx in *)
(*   try *)
(*     let phase_num = get_phase_num measure in *)
(*     let term_res = *)
(*       if (phase_num < 0) then *)
(*         (pos, orig_ante, NonTerm Non_Term_Reached) *)
(*       else if (phase_num = 0) then *)
(*         (pos, orig_ante, Term Base_Case_Reached) *)
(*       else *)
(*         let lv = lexvar_of_evariance measure in  *)
(*         match lv with *)
(*         | None -> report_term_error orig_ante Variance_Not_Given pos *)
(*         | Some m ->  *)
(*             let lv = formula_of_pure_formula m pos in *)
(*             let res = f ctx lv pos in (\* check decreasing *\) *)
(*             if (isFailCtx res) then (pos, orig_ante, MayTerm Not_Decrease_Measure) *)
(*             else *)
(*               (\* The default lower bound is zero *\) *)
(*               let zero = List.map (fun _ -> CP.mkIConst 0 pos) measure.formula_var_measures in        *)
(*               let bnd = formula_of_pure_formula (CP.mkPure (CP.mkLexVar zero [] pos)) pos in *)
(*               let res = f ctx bnd pos in (\* check boundedness *\) *)
(*               if (isFailCtx res) then (pos, orig_ante, MayTerm Not_Bounded_Measure) *)
(*               else (pos, orig_ante, Term Valid_Measure) *)
(*     in term_res_stk # push term_res; term_res *)
(*   with  *)
(*   | Invalid_Phase_Num *)
(*   | Failure "nth" -> report_term_error orig_ante Invalid_Phase_Trans pos *)
*)
(*
(* let check_reachable_term_measure f (ctx: context) (measure: ext_variance_formula) pos : term_res = *)
(*   let orig_ante = formula_of_context ctx in *)
(*   let lv = lexvar_of_evariance measure in *)
(*   match lv with *)
(*   | None -> report_term_error orig_ante Variance_Not_Given pos *)
(*   | Some m ->  *)
(*       let lv = formula_of_pure_formula m pos in *)
(*       let res = f ctx lv pos in (\* check decreasing *\) *)
(*       let term_res = *)
(*         if (isFailCtx res) then  *)
(*           (pos, Some orig_ante, MayTerm_S Not_Decreasing_Measure) *)
(*         else *)
(*           (\* The default lower bound is zero *\) *)
(*           let zero = List.map (fun _ -> CP.mkIConst 0 pos) measure.formula_var_measures in        *)
(*           let bnd = formula_of_pure_formula (CP.mkPure (CP.mkLexVar Term zero [] pos)) pos in *)
(*           let res = f ctx bnd pos in (\* check boundedness *\) *)
(*           if (isFailCtx res) then (pos, Some orig_ante, MayTerm_S Not_Bounded_Measure) *)
(*           else (pos, Some orig_ante, Term_S Valid_Measure) *)
(*       in term_res_stk # push term_res;  *)
(*       term_res  *)

(* let check_term_measure f (ctx: context) (measure: ext_variance_formula) pos : term_res = *)
(*   if (isAnyFalseCtx ctx) then *)
(*     let orig_ante = formula_of_disjuncts (collect_orig_ante ctx) in *)
(*     let term_res = (pos, Some orig_ante, Unreachable) in *)
(*     term_res_stk # push term_res; *)
(*     term_res *)
(*   else *)
(*     check_reachable_term_measure f ctx measure pos *)
*)

(*****************************************)
(* Phase Transition Inference            *)
(*****************************************)
(* Store the inferred phase constraints *)
(* TODO: These constraints should be normalized
 * and filtered to keep only constraints 
 * related to LexVar before adding them to stack *)
let add_phase_constr (lp: CP.formula list) =
  phase_constr_stk # push_list lp

(* Build the graph for phase numbering based on
 * inferred phase constraints
 * p2>p1 -> p2 --> p1
 * p2>=p1 -> {p2,p1} 
 * [x>y, y>=z] --> [[x], [y,z]] *)
let rec phase_constr_of_formula_list (fl: CP.formula list) : phase_constr list =
  let fl = List.concat (List.map CP.split_conjunctions fl) in
  List.fold_left (fun a f -> 
    let c = phase_constr_of_formula f in 
    match c with
    | Some c -> c::a
    | None -> a) [] fl
  
and phase_constr_of_formula (f: CP.formula) : phase_constr option =
  match f with
  | CP.BForm (bf, _) -> phase_constr_of_b_formula bf
  | _ -> None 

and phase_constr_of_b_formula (bf: CP.b_formula) : phase_constr option =
  let (pf, _) = bf in
  match pf with
    | CP.Eq (e1, e2, _) ->
        let v1 = var_of_exp e1 in
        let v2 = var_of_exp e2 in
        (match (v1, v2) with
         | Some v1, Some v2 -> Some (P_Gte (v1, v2))
         | _ -> None)
    | CP.Gt (e1, e2, _) ->
        let v1 = var_of_exp e1 in
        let v2 = var_of_exp e2 in
        (match (v1, v2) with
         | Some v1, Some v2 -> Some (P_Gt (v1, v2))
         | _ -> None)
    | CP.Gte (e1, e2, _) ->
        let v1 = var_of_exp e1 in
        let v2 = var_of_exp e2 in
        (match (v1, v2) with
         | Some v1, Some v2 -> Some (P_Gte (v1, v2))
         | _ -> None)
    | CP.Lt (e1, e2, _) ->
        let v1 = var_of_exp e1 in
        let v2 = var_of_exp e2 in
        (match (v1, v2) with
         | Some v1, Some v2 -> Some (P_Gt (v2, v1))
         | _ -> None)
    | CP.Lte (e1, e2, _) ->
        let v1 = var_of_exp e1 in
        let v2 = var_of_exp e2 in
        (match (v1, v2) with
         | Some v1, Some v2 -> Some (P_Gte (v2, v1))
         | _ -> None)
    | _ -> None

and var_of_exp (exp: CP.exp) : CP.spec_var option =
  match exp with
  | CP.Var (sv, _) -> Some sv
  | _ -> None

let fv_of_phase_constr (c: phase_constr) =
  match c with
  | P_Gte (v1, v2) -> [v1; v2]
  | P_Gt (v1, v2) -> [v1; v2]

(* Old phase inference mechanism - To be removed *)
(*
module PComp = 
struct
  type t = CP.spec_var list
  let compare = 
    fun l1 l2 -> 
      if (Gen.BList.list_setequal_eq CP.eq_spec_var l1 l2) then 0 
      else 
        let pr = pr_list !CP.print_sv in
        String.compare (pr l1) (pr l2)
  let hash = Hashtbl.hash
  let equal = Gen.BList.list_setequal_eq CP.eq_spec_var
end

module PG = Graph.Persistent.Digraph.Concrete(PComp)
module PGO = Graph.Oper.P(PG)
module PGN = Graph.Oper.Neighbourhood(PG)
module PGC = Graph.Components.Make(PG)
module PGP = Graph.Path.Check(PG)
module PGT = Graph.Traverse.Dfs(PG)

(* Group spec_vars of related 
 * P_Gte constraints together *)
let rec group_related_vars (cl: phase_constr list) : CP.spec_var list list =
  let gte_l = List.fold_left (fun a c ->
    match c with 
    | P_Gt _ -> a
    | P_Gte (v1, v2) -> [v1; v2]::a 
  ) [] cl in
  let rec partition_gte_l l =
    match l with
    | [] -> []
    | h::t ->
        let n_t = partition_gte_l t in
        let r, ur = List.partition (fun sl -> 
          Gen.BList.overlap_eq CP.eq_spec_var h sl
        ) n_t in
        let n_h = Gen.BList.remove_dups_eq CP.eq_spec_var (h @ (List.concat r)) in
        n_h::ur
  in partition_gte_l gte_l

let build_phase_constr_graph (gt_l: (CP.spec_var list * CP.spec_var list) list) =
  let g = PG.empty in
  let g = List.fold_left (fun g (l1, l2) ->
    let ng1 = PG.add_vertex g l1 in
	  let ng2 = PG.add_vertex ng1 l2 in
	  let ng3 = PG.add_edge ng2 l1 l2 in
	ng3) g gt_l in
  g

let rank_gt_phase_constr (cl: phase_constr list) =
  let eq_l = group_related_vars cl in
  (*
  let pr_v = !CP.print_sv in
  let pr_vl = pr_list pr_v in
  let _ = print_endline ("\neq_l: " ^ (pr_list pr_vl eq_l)) in
  *)
  let gt_l = List.fold_left (fun a c ->
    match c with
    | P_Gt (v1, v2) -> (v1, v2)::a
    | P_Gte _ -> a
  ) [] cl in

  (* let _ = print_endline ("\ngt_l: " ^ (pr_list (pr_pair pr_v pr_v) gt_l)) in *)
  
  let find_group v l =
    try List.find (fun e -> Gen.BList.mem_eq CP.eq_spec_var v e) l
    with _ -> [v]
  in 
  (*
  let gt_l = List.map (fun (v1, v2) -> 
    let g_v1 = find_group v1 eq_l in
    let g_v2 = find_group v2 eq_l in
    (* p2>p1 and p2>=p1 are not allowed *)
    if (Gen.BList.overlap_eq CP.eq_spec_var g_v1 g_v2) then
      raise Invalid_Phase_Constr
    else (g_v1, g_v2)
  ) gt_l in
  *)

  let gt_l = List.fold_left (fun acc (v1, v2) ->
    let g_v1 = find_group v1 eq_l in
    let g_v2 = find_group v2 eq_l in
    (* Get rid of p2>p1 and p2>=p1 *)
    if (Gen.BList.overlap_eq CP.eq_spec_var g_v1 g_v2) then acc
    else (g_v1, g_v2)::acc
  ) [] gt_l in

  (*let _ = print_endline ("\n1. gt_l: " ^ (pr_list (pr_pair pr_vl pr_vl) gt_l)) in*)

  let g = build_phase_constr_graph gt_l in

  if (PGT.has_cycle g) then (* Contradiction: p2>p1 & p1>p2 *)
    raise Invalid_Phase_Constr
  else
    let n, f_scc = PGC.scc g in
    PG.fold_vertex (fun l a -> (f_scc l, l)::a) g []

let value_of_vars (v: CP.spec_var) l : int =
  try
    let (i, _) = List.find (fun (i, vl) -> 
      Gen.BList.mem_eq CP.eq_spec_var v vl
    ) l in i
  with _ -> raise Invalid_Phase_Constr
*)

module PComp = 
struct
  type t = CP.spec_var
  let compare = fun v1 v2 -> 
    if (CP.eq_spec_var v1 v2) then 0
    else 
      let pr = !CP.print_sv in
      String.compare (pr v1) (pr v2)
  let hash = Hashtbl.hash
  let equal = CP.eq_spec_var
end

module PG = Graph.Persistent.Digraph.Concrete(PComp)
module PGO = Graph.Oper.P(PG)
module PGN = Graph.Oper.Neighbourhood(PG)
module PGC = Graph.Components.Make(PG)
module PGP = Graph.Path.Check(PG)
module PGT = Graph.Traverse.Dfs(PG)

(* Build phase constraint graph based on the 
 * list of inferred phase constraints 
 * P_Gt/P_Gte (v1, v2) -> v1 --> v2 *)
let build_phase_constr_graph (cl: phase_constr list) = 
  let g = PG.empty in
  let g = List.fold_left (fun g c ->
    let s, d = match c with
      | P_Gt (v1, v2) -> v1, v2
      | P_Gte (v1, v2) -> v1, v2
    in 
    let ng1 = PG.add_vertex g s in
    let ng2 = PG.add_vertex ng1 d in
    let ng3 = PG.add_edge ng2 s d in
    ng3
  ) g cl in
  g

(* Assign a unique integer for each scc group 
 * of phase variables *)  
let rank_phase_constr (cl: phase_constr list) =
  let g = build_phase_constr_graph cl in
  let n, f_scc = PGC.scc g in
  PG.fold_vertex (fun v a -> (v, f_scc v)::a) g []

let rank_phase_constr (cl: phase_constr list) =
  let pr = pr_list string_of_phase_constr in
  let pr2 = pr_list (pr_pair !CP.print_sv  string_of_int) in
  Debug.no_1 "rank_phase_constr" pr pr2 rank_phase_constr cl

let value_of_var (v: CP.spec_var) l : int =
  try List.assoc v l
  with _ -> raise Invalid_Phase_Constr

(* let phase_num_infer () = *)
(*   (\* Phase Numbering *\)  *)
(*   let pr_v = !CP.print_sv in *)
(*   let pr_vl = pr_list pr_v in *)
(*   let cl = phase_constr_of_formula_list (phase_constr_stk # get_stk) in *)
(*   let _ = Debug.trace_hprint (add_str "Phase Constrs" (pr_list string_of_phase_constr)) cl no_pos in *)
(*   let l =  *)
(*     try rank_gt_phase_constr cl  *)
(*     with _ ->  *)
(*       fmt_string ("Termination: Contradiction in Phase Constraints."); []  *)
(*   in *)
(*   begin *)
(*     Debug.trace_hprint (add_str "Inferred phase constraints" *)
(*       (pr_list !CP.print_formula)) (phase_constr_stk # get_stk) no_pos; *)
(*     Debug.trace_hprint (add_str "Phase Numbering" *)
(*       (pr_list (pr_pair string_of_int (pr_list !CP.print_sv))) *)
(*     ) l no_pos; *)
(*   end *)

(* let phase_num_infer () = *)
(*   let pr = fun _ -> "" in *)
(*   Debug.no_1 "phase_num_infer" pr pr phase_num_infer () *)

(* Do infer phase number per scc group *)
(* Triggered when phase constraints of 
 * all function in a scc group has been 
 * collected - The result may be empty 
 * if the graph has only one vertex 
 * + None -> exception
 * + Some [] -> all_zero
 * + Some _ *)
let phase_num_infer_one_scc (pl : CP.formula list) =
  (* Phase Numbering *) 
  (* let pr_v = !CP.print_sv in *)
  (* let pr_vl = pr_list pr_v in *)
  let cl = phase_constr_of_formula_list pl in
  let s_msg = (add_str "Phase Constrs" (pr_list string_of_phase_constr)) cl in 
  (* let _ = Debug.trace_hprint (add_str "Phase Constrs" (pr_list string_of_phase_constr)) cl no_pos in *)
  let _ = Debug.trace_pprint s_msg no_pos in
  let l = 
    try 
      (* let r = rank_gt_phase_constr cl in *)
      let r = rank_phase_constr cl in
      let _ = 
        begin
          Debug.trace_hprint (add_str "Inferred phase constraints"
            (pr_list !CP.print_formula)) (phase_constr_stk # get_stk) no_pos;
          Debug.trace_hprint (add_str "Phase Numbering"
            (* (pr_list (pr_pair string_of_int (pr_list !CP.print_sv)))) r no_pos; *)
            (pr_list (pr_pair !CP.print_sv string_of_int))) r no_pos;
        end
      in 

      if Gen.is_empty r then
        let fv = List.concat (List.map fv_of_phase_constr cl) in
        Some (r, fv)
      else Some (r, [])
    with _ -> 
      fmt_string ("\nTermination: Error in Phase Inference." ^ "\n" ^ s_msg); None 
  in
  l

let phase_num_infer_one_scc (pl: CP.formula list)  =
  let pr = fun _ -> "" in
  let pr2 = (add_str "Phase Ctr" (pr_list !CP.print_formula)) in
  Debug.no_1 "phase_num_infer_one_scc" pr2 pr phase_num_infer_one_scc pl

(* Infer the phase numbers at the end of check_prog *) 
(* Currently, this method is redundant because we do
 * aggressive phase inference per scc group *)  
let phase_num_infer_by_scc () = 
  Hashtbl.iter (fun i pl -> 
    let cl = List.concat (List.map (fun (_, l) -> l) pl) in
    Debug.trace_hprint (add_str ("scc " ^ (string_of_int i))
      (pr_list !CP.print_formula)) cl no_pos;
    let _ = phase_num_infer_one_scc cl in ()
  ) phase_constr_tbl

let phase_num_infer_by_scc () =
  let pr = fun _ -> "" in
  Debug.no_1 "phase_num_infer_by_scc" pr pr phase_num_infer_by_scc ()

(* this method adds phase constraint into a table indexed by call number *)
(* it seems to be done on a per-call basis *)
let add_phase_constr_by_scc (proc: Cast.proc_decl) (lp: CP.formula list) =
  let index = proc.Cast.proc_call_order in
  let pname = proc.Cast.proc_name in
  let con = (pname, lp) in
  try
    let cons = Hashtbl.find phase_constr_tbl index in
    Hashtbl.replace phase_constr_tbl index (con::cons)
  with Not_found -> Hashtbl.add phase_constr_tbl index [con]

let add_phase_constr_by_scc (proc: Cast.proc_decl) (lp: CP.formula list) =
  let pr = fun _ -> "" in
  let pr1 = add_str "phase ctr added" (pr_list !CP.print_formula) in
  Debug.no_1 "add_phase_constr_by_scc" pr1 pr (add_phase_constr_by_scc proc) lp

let subst_phase_num_exp subst exp = 
  match exp with
  | CP.Var (v, pos) ->
      (try
        let i = List.assoc v subst in
        CP.mkIConst i pos
      with _ -> exp)
  | _ -> exp 

(* Substitute the value of phase variables into specification *)
(* If all values are zero then the phase fields will be removed *)  
let subst_phase_num_struc rem_phase subst (struc: struc_formula) : struc_formula =
  let f_e _ = None in
  let f_f _ = None in
  let f_h _ = None in
  let f_m _ = None in
  let f_a _ = None in
  let f_pf _ = None in
  let f_bf bf =
    let (pf, sl) = bf in
    match pf with
    (* restoring ml from the 3rd argument *)
    | CP.LexVar t_info ->
		    let t_ann = t_info.CP.lex_ann in
		    let ml = t_info.CP.lex_tmp in
			  let pos = t_info.CP.lex_loc in
        Debug.dinfo_hprint (add_str "lex_tmp" (pr_list !CP.print_exp)) ml no_pos;
        let subs_extra = match ml with
          | _::e::_ -> begin
            match CP.get_var_opt e with
            | None -> []
            | Some v -> 
                if (List.exists (fun (v2,_) -> CP.eq_spec_var v v2) subst) then [] 
                else 
                  begin
                    Debug.info_hprint (add_str "var -> 0" !CP.print_sv) v no_pos;
                    [(v,0)]
                  end
                end
          | _ -> [] 
        in
        let n_ml =
          if rem_phase == [] then
            (* replace the phase var with integer *)
            List.map (fun m -> subst_phase_num_exp (subs_extra@subst) m) ml 
          else 
            (* to remove phase vars in rem_phase *)
            List.filter (fun e -> match CP.get_var_opt e with
              | None -> true
              | Some v -> not(CP.mem_svl v rem_phase)) ml
        in Some (CP.mkLexVar t_ann n_ml ml pos, sl)
      | _ -> None
  in
  let f_pe _ = None in
  let e_f = f_e, f_f, f_h, (f_m, f_a, f_pf, f_bf, f_pe) in

  (* Remove inferred variables from EInfer *)
  let f_ext ext = match ext with
    | EInfer ({ formula_inf_vars = iv; formula_inf_continuation = cont } as e) ->
          let lv = fst (List.split subst) in
          let n_iv = Gen.BList.difference_eq CP.eq_spec_var iv lv in
          let n_cont = transform_struc_formula e_f cont in
          if Gen.is_empty n_iv then Some n_cont
          else Some (EInfer { e with 
              formula_inf_vars = n_iv;
              formula_inf_continuation = n_cont })
    | _ -> None
  in
  
  let s_f = f_ext, f_f, f_h, (f_m, f_a, f_pf, f_bf, f_pe) in
  let n_struc = transform_struc_formula s_f struc in
  let _ = 
    begin
      (* Debug.trace_hprint (add_str ("proc name") (pr_id)) pname no_pos; *)
      Debug.trace_hprint (add_str ("subst") (pr_list (pr_pair !CP.print_sv string_of_int))) subst no_pos;
      Debug.trace_hprint (add_str ("OLD_SPECS") (!print_struc_formula)) struc no_pos;
      Debug.trace_hprint (add_str ("NEW_SPECS") (!print_struc_formula)) n_struc no_pos;
    end 
  in
  n_struc

let subst_phase_num_struc rp subst (struc: struc_formula) : struc_formula =
  let pr = !print_struc_formula in
  let pr0 = !CP.print_svl in
  let pr1 = pr_list (pr_pair !CP.print_sv string_of_int) in
  Debug.no_3 (* (fun _ -> not (Gen.is_empty struc)) *) 
  "subst_phase_num_struc" pr0 pr1 pr pr 
  (subst_phase_num_struc) rp subst struc

(* let subst_phase_num_struc subst (struc: struc_formula) : struc_formula = *)
(*   if struc==[] then struc *)
(*   else subst_phase_num_struc subst struc *)

let subst_phase_num_proc rp subst (proc: Cast.proc_decl) : Cast.proc_decl =
  let s_specs = subst_phase_num_struc rp subst proc.Cast.proc_static_specs in
  let d_specs = subst_phase_num_struc rp subst proc.Cast.proc_dynamic_specs in
  let _ = proc.Cast.proc_stk_of_static_specs # push s_specs in 
  { proc with
      Cast.proc_static_specs = s_specs;
      Cast.proc_dynamic_specs = d_specs; }

let phase_num_infer_whole_scc (prog: Cast.prog_decl) (proc_lst: Cast.proc_decl list) : Cast.prog_decl =
  let mutual_grp = List.map (fun p -> p.Cast.proc_name) proc_lst in
  match proc_lst with
    | [] -> print_endline "ERROR : empty SCC prog_lst!"; prog
    | proc::_ ->
          begin
            let index = proc.Cast.proc_call_order in
            try
              let cons = Hashtbl.find phase_constr_tbl index in
              (* let grp = fst (List.split cons) in *)
              (* let is_full_grp = Gen.BList.list_setequal_eq (=) grp mutual_grp in *)
              let is_full_grp = true in
              Debug.trace_hprint (add_str ("proc") (pr_id)) proc.Cast.proc_name no_pos;
              Debug.trace_hprint (add_str "full_grp?" string_of_bool) is_full_grp no_pos;
              (* Trigger phase number inference when 
               * all needed information is collected *)
              if is_full_grp then
                let cl = List.concat (snd (List.split cons)) in
                let inf_num = phase_num_infer_one_scc cl in
                Debug.trace_hprint (add_str "list of ctr" 
                    (pr_list !CP.print_formula)) cl no_pos;
                let subst =
                  match inf_num with
                    | None -> []
                    | Some (inf_num, fv) ->
                          begin
                            if not (Gen.is_empty inf_num) then
                              (* List.concat (List.map (fun (i, l) -> List.map (fun v -> (v, i)) l) inf_num) *)
                              inf_num
                            else
                              (* The inferred graph has only one vertex *)
                              (* All of phase variables will be assigned by 0 *)
                              (* let fv = List.concat (List.map (fun f -> CP.fv f) cl) in*)
                              let fv = Gen.BList.remove_dups_eq CP.eq_spec_var fv in
                              List.map (fun v -> (v, 0)) fv
                          end
                in
                (* Termination: Add the inferred phase numbers 
                 * into specifications of functions in mutual group *)
                (* if subst==[] then  *)
                (*   begin *)
                (*     Debug.info_hprint (add_str "Mutual Rec Group" (pr_list pr_id)) mutual_grp no_pos;  *)
                (*     Debug.info_pprint "Phase Subst is EMPTY" no_pos; *)
                (*     prog *)
                (*   end *)
                (* else  *)
                  (* all_zero is set if subs is only of form [v1->0,..,vn->0]
                     in this scenario, there is no need for phase vars at all *)
                  begin
                    Debug.devel_zprint (lazy (" >>>>>> [term.ml][Adding Phase Numbering] <<<<<<")) no_pos;
                    let all_zero = List.for_all (fun (_,i) -> i==0) subst in
                    let rp = if all_zero then List.map (fun (v,_) -> v) subst else [] in
                    if all_zero then
                      Debug.trace_hprint (add_str ("Phase to remove") !CP.print_svl) rp no_pos
                    else begin
                      Debug.info_hprint (add_str "Mutual Rec Group" (pr_list pr_id)) mutual_grp no_pos; 
                      Debug.info_hprint (add_str "Phase Numbering"
                          (pr_list (pr_pair !CP.print_sv string_of_int))) subst no_pos
                    end;
                    let n_tbl = Cast.proc_decls_map (fun proc ->
                        if (List.mem proc.Cast.proc_name mutual_grp) 
                        then subst_phase_num_proc rp subst proc
                        else proc
                    ) prog.Cast.new_proc_decls in  
                    { prog with Cast.new_proc_decls = n_tbl }
                  end
              else prog
            with Not_found -> prog
          end

let phase_num_infer_whole_scc (prog: Cast.prog_decl) (proc_lst: Cast.proc_decl list) : Cast.prog_decl =
  let mutual_grp = List.map (fun p -> p.Cast.proc_name) proc_lst in
  let pr _ = pr_list pr_id mutual_grp in
  Debug.no_1 "phase_num_infer_whole_scc" pr pr_no (phase_num_infer_whole_scc prog) proc_lst 

(* Main function of the termination checker *)
let term_check_output () =
  (* if not !Globals.dis_term_msg then *)
    (fmt_string "\nTermination checking result:\n";
    (if (!Globals.term_verbosity == 0) then pr_term_res_stk (term_res_stk # get_stk)
    else pr_term_err_stk (term_err_stk # get_stk));
    fmt_print_newline ())

let rec get_loop_ctx c =
  match c with
    | Ctx es -> (match es.es_var_measures with
        | None -> []
        | Some (a,_,_) -> if a==Loop then [es] else []
      )
    | OCtx (c1,c2) -> (get_loop_ctx c1) @ (get_loop_ctx c2)

let get_loop_only sl =
  let ls = List.map (fun (_,c) -> get_loop_ctx c) sl in
  List.concat ls

let add_unsound_ctx (es: entail_state) pos = 
  let term_pos = (post_pos # get, no_pos) in
  let term_res = (term_pos, None, Some es.es_formula, UnsoundLoop) in
  add_term_res_stk term_res;
  add_term_err_stk (string_of_term_res term_res)

(* if Loop, check that ctx is false *)
let check_loop_safety (prog : Cast.prog_decl) (proc : Cast.proc_decl) (ctx : list_partial_context) post pos (pid:formula_label) : bool  =
  Debug.trace_hprint (add_str "proc name" pr_id) proc.Cast.proc_name pos;
  let good_ls = List.filter (fun (fl,sl) -> fl==[]) ctx in (* Not a fail context *)
  let loop_es = List.concat (List.map (fun (fl,sl) -> get_loop_only sl) good_ls) in
  if loop_es==[] then true
  else 
    begin
      Debug.devel_zprint (lazy (" >>>>>> [term.ml][check loop safety] <<<<<<")) no_pos;
      Debug.trace_hprint (add_str "res ctx" Cprinter.string_of_list_partial_context_short) ctx pos;
      Debug.devel_hprint (add_str "loop es" (pr_list Cprinter.string_of_entail_state_short)) loop_es pos;
      (* TODO: must check that each entail_state from loop_es implies false *)
      let unsound_ctx = List.find_all (fun es -> not (isAnyConstFalse es.es_formula)) loop_es in
      if unsound_ctx == [] then true
      else
        begin
        Debug.devel_hprint (add_str "unsound Loop" (pr_list Cprinter.string_of_entail_state_short)) unsound_ctx pos;
        List.iter (fun es -> add_unsound_ctx es pos) unsound_ctx;
        false
        end;
    end

let check_loop_safety (prog : Cast.prog_decl) (proc : Cast.proc_decl) (ctx : list_partial_context) post pos (pid:formula_label) : bool  =
  Debug.no_1 "check_loop_safety" 
      pr_id string_of_bool (fun _ -> check_loop_safety prog proc ctx post pos pid) proc.Cast.proc_name
