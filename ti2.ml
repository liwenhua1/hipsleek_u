module CP = Cpure
module CF = Cformula
module MCP = Mcpure

open Cprinter
open Globals
open Gen
open Tlutils
open Ti3

(* Auxiliary methods *)
let diff = Gen.BList.difference_eq CP.eq_spec_var
let subset = Gen.BList.subset_eq CP.eq_spec_var

let om_simplify = Omega.simplify

let eq_str s1 s2 = String.compare s1 s2 == 0

let simplify f args = 
  let bnd_vars = diff (CP.fv f) args in
  if bnd_vars == [] then f else
    CP.mkExists_with_simpl om_simplify (* Tpdispatcher.simplify_raw *)
      (diff (CP.fv f) args) f None (CP.pos_of_formula f)
  
let is_sat f = Tpdispatcher.is_sat_raw (MCP.mix_of_pure f)

let imply a c = Tpdispatcher.imply_raw a c

(* To be improved *)
let fp_imply f p =
  let _, pf, _, _, _ = CF.split_components f in
  let (res, _, _) = Tpdispatcher.mix_imply pf (MCP.mix_of_pure p) "999" in
  res
  
let f_is_sat f =
  let _, pf, _, _, _ = CF.split_components f in
  Tpdispatcher.is_sat_raw pf

let mkAnd f1 f2 = CP.mkAnd f1 f2 no_pos
let mkNot f = CP.mkNot f None no_pos
let mkGt e1 e2 = CP.mkPure (CP.mkGt e1 e2 no_pos)
let mkGte e1 e2 = CP.mkPure (CP.mkGte e1 e2 no_pos)

(* Partition a list of conditions into disjoint conditions *)
let rec partition_cond_list cond_list = 
  match cond_list with
  | [] -> []
  | c::cs ->
    let dcs = partition_cond_list cs in
    let rec helper c dcs =
      match dcs with
      | [] -> [c]
      | d::ds -> 
        if not (is_sat (mkAnd c d)) then d::(helper c ds)
        else if (imply c d) then dcs
        else (mkAnd c d)::(mkAnd (mkNot c) d)::(helper (mkAnd c (mkNot d)) ds)
    in helper c dcs
    
let get_full_disjoint_cond_list cond_list = 
  let disj_cond_lst = partition_cond_list cond_list in
  let full_disj_cond_lst =
    let rem_cond = mkNot (CP.join_disjunctions disj_cond_lst) in
    if is_sat rem_cond then disj_cond_lst @ [rem_cond]
    else disj_cond_lst
  in List.map om_simplify full_disj_cond_lst
    
let seq_num = ref 0    
    
let tnt_fresh_int () = 
  seq_num := !seq_num + 1;
  !seq_num
  
let reset_seq_num _ =
  seq_num := 0
  
let scc_num = ref 0    
    
let scc_fresh_int () = 
  scc_num := !scc_num + 1;
  !scc_num
  
let reset_scc_num _ =
  scc_num := 0
    
(* This method returns a unique number for (a, b) *)
(* It is used to generate num for new instantiated TermU *)    
let cantor_pair a b = (a + b) * (a + b + 1) / 2 + b

let assign_id_to_list ls = 
  snd (List.fold_left (fun (i, a) e -> 
    (i + 1, a @ [(i + 1, e)])) (0, []) ls)

(******************************************************************************)

(* Result for Return Relation Assumptions *)
type trrel_sol = 
  | Base of CP.formula
  | Rec of CP.formula (* Recursive case *)
  | MayTerm of CP.formula (* Both base and rec cases may be reachable from this case *)
  
let print_trrel_sol s = 
  let pr = !CP.print_formula in
  match s with
  | Base c -> (pr c) ^ "@B"
  | Rec c -> (pr c) ^ "@R"
  | MayTerm c -> (pr c) ^ "@ML"

let trans_trrel_sol f = function
  | Base c -> Base (f c)
  | Rec c -> Rec (f c)
  | MayTerm c -> MayTerm (f c)

let fold_trrel_sol f = function
  | Base c -> let cs = f c in List.map (fun c -> Base c) cs 
  | Rec c -> let cs = f c in List.map (fun c -> Rec c) cs 
  | MayTerm c -> let cs = f c in List.map (fun c -> MayTerm c) cs 

let simplify_trrel_sol = trans_trrel_sol om_simplify

let split_disj_trrel_sol s =
  fold_trrel_sol CP.split_disjunctions s
     
let is_base = function
  | Base _ -> true
  | _ -> false

let is_rec = function
  | Rec _ -> true
  | _ -> false

let is_mayterm = function
  | MayTerm _ -> true
  | _ -> false

let get_cond = function
  | Base c -> c
  | Rec c -> c
  | MayTerm c -> c

let get_rec_conds conds = 
  List.map get_cond (List.filter is_rec conds)  
  
let params_of_term_ann prog ann =
  match ann with
  | CP.TermU uid
  | CP.TermR uid ->
    let sid = uid.CP.tu_sid in
    begin try
      let ut_decl = List.find (fun utd -> 
        String.compare utd.Cast.ut_name sid == 0) prog.Cast.prog_ut_decls in
      ut_decl.Cast.ut_params
    with Not_found -> report_error no_pos 
        ("[TNT Inference]: Definition of " ^ sid ^ " cannot be found.")
    end
  | _ -> []
  
(* Solution substitution *)
let subst_sol_term_ann sol ann =
  match ann with
  | CP.TermU uid -> CP.TermU { uid with 
      tu_sol = match uid.tu_sol with
      | None -> Some sol 
      | _ -> uid.CP.tu_sol }
  | CP.Term -> 
    begin match (fst sol) with
    | CP.Loop 
    | CP.MayLoop -> report_error no_pos 
        "[TNT Inference]: A non-terminating program state is specified with Term."
    | _ -> ann
    end
  | _ -> ann

(******************************************************************************)

(* Specification *)

(* Stack for TNT case specs of all methods *)
let proc_case_specs: (ident, tnt_case_spec) Hashtbl.t = 
  Hashtbl.create 20

let case_spec_of_trrel_sol call_num sol =
  match sol with
  | Base c -> (c, Sol (CP.Term, 
    [CP.mkIConst call_num no_pos; CP.mkIConst (scc_fresh_int ()) no_pos]))
  | Rec c -> (c, Unknown)
  | MayTerm c -> (c, Sol (CP.MayLoop, [])) 

let add_case_spec_of_trrel_sol_proc prog (fn, sols) =
  let call_num = 
    try
      let proc = Cast.look_up_proc_def_no_mingling no_pos prog.Cast.new_proc_decls fn in
      proc.Cast.proc_call_order
    with _ -> 0
  in
  let cases = List.map (case_spec_of_trrel_sol call_num) sols in
  Hashtbl.add proc_case_specs fn (Cases cases)
  
let rec update_case_spec spec cond f = 
  match spec with
  | Sol _ -> spec
  | Unknown -> f spec
  | Cases cases -> 
    let rec helper cases =
      match cases with
      | [] -> cases
      | (c, case)::rem ->
        if imply cond c then (c, (update_case_spec case cond f))::rem
        else (c, case)::(helper rem)
    in Cases (helper cases)
    
let update_case_spec_proc fn cond f = 
  try
    let spec = Hashtbl.find proc_case_specs fn in
    let nspec = update_case_spec spec cond f in
    Hashtbl.replace proc_case_specs fn nspec
  with _ -> () 
  
let add_sol_case_spec_proc fn cond sol = 
  update_case_spec_proc fn cond (fun _ -> Sol sol)
  
let update_case_spec_with_icond_proc fn cond icond = 
  update_case_spec_proc fn cond (fun _ -> 
    Cases [(icond, Unknown); (mkNot icond, Unknown)])
    
let update_case_spec_with_icond_list_proc fn cond icond_lst =
  if is_empty icond_lst then ()
  else update_case_spec_proc fn cond (fun _ -> 
    Cases (List.map (fun c -> (c, Unknown)) icond_lst))
    
(* From TNT spec to struc formula *)
(* For SLEEK *)
let struc_formula_of_ann (ann, rnk) =
  let pos = no_pos in
  let p_pre = MCP.mix_of_pure (CP.mkLexVar_pure ann rnk []) in
  let p_post = match ann with
    | Loop -> MCP.mkMFalse pos 
    | _ -> MCP.mkMTrue pos
  in
  let f_pre = CF.mkBase_simp CF.HEmp p_pre in
  let f_post = CF.mkBase_simp CF.HEmp p_post in
  let lbl = fresh_formula_label "" in
  let post = CF.mkEAssume [] f_post (CF.mkEBase f_post None pos) lbl None in
  let spec = CF.mkEBase f_pre (Some post) pos  in
  spec

(* For HIP with given specifications *)  
let struc_formula_of_ann_w_assume assume (ann, rnk) =
  let pos = no_pos in
  let p_pre = MCP.mix_of_pure (CP.mkLexVar_pure ann rnk []) in
  let f_pre = CF.mkBase_simp CF.HEmp p_pre in
  
  let post = match ann with
    | Loop ->
      let f_post = CF.mkBase_simp CF.HEmp (MCP.mkMFalse pos) in
      CF.EAssume { assume with
        CF.formula_assume_simpl = f_post;
        CF.formula_assume_struc = CF.mkEBase f_post None pos; }
    | _ -> TermUtils.strip_lexvar_post (CF.EAssume assume)
  in
  let spec = CF.mkEBase f_pre (Some post) pos in
  spec
  
let struc_formula_of_dead_path _ =
  let pos = no_pos in
  let pp = CF.mkBase_simp CF.HEmp (MCP.mkMFalse pos) in
  let lbl = fresh_formula_label "" in
  let post = CF.mkEAssume [] pp (CF.mkEBase pp None pos) lbl None in
  let spec = CF.mkEBase pp (Some post) pos  in
  spec
  
let rec struc_formula_of_tnt_case_spec spec =
  match spec with
  | Sol s -> struc_formula_of_ann s
  | Unknown -> struc_formula_of_ann (MayLoop, [])
  | Cases cases -> CF.ECase {
      CF.formula_case_branches = List.map (fun (c, s) -> 
        (c, struc_formula_of_tnt_case_spec s)) cases;
      CF.formula_case_pos = no_pos; }
      
let print_tnt_case_spec spec =
  let struc = struc_formula_of_tnt_case_spec spec in
  string_of_struc_formula_for_spec struc 
  
let rec merge_tnt_case_spec_into_struc_formula ctx spec sf = 
  match sf with
  | CF.ECase ec -> CF.ECase { ec with 
      CF.formula_case_branches = List.map (fun (c, ef) ->
        let ctx, _ = CF.combine_and ctx (MCP.mix_of_pure c) in
        c, merge_tnt_case_spec_into_struc_formula ctx spec ef) ec.CF.formula_case_branches }
  | CF.EBase eb -> 
    let pos = eb.CF.formula_struc_pos in 
    let base = eb.CF.formula_struc_base in
    let cont = eb.CF.formula_struc_continuation in
    
    let update_ebase b = 
      if CF.isConstTrueFormula b then
        match cont with
        | None -> CF.EBase { eb with CF.formula_struc_base = b; }
        | Some c -> merge_tnt_case_spec_into_struc_formula ctx spec c
      else
        let nctx = CF.normalize 16 ctx b pos in
        CF.EBase { eb with
          CF.formula_struc_base = b;
          CF.formula_struc_continuation = map_opt 
            (merge_tnt_case_spec_into_struc_formula nctx spec) cont }
    in
   
    let has_lexvar, has_unknown_lexvar = CF.has_unknown_lexvar_formula base in
    if has_unknown_lexvar then
      let nbase = snd (TermUtils.strip_lexvar_formula base) in
      update_ebase nbase
    else if has_lexvar then
      CF.EBase { eb with
        CF.formula_struc_continuation = map_opt 
          TermUtils.strip_lexvar_post cont }
    else update_ebase base
  | CF.EAssume af -> merge_tnt_case_spec_into_assume ctx spec af
  | CF.EInfer ei -> 
    let cont = merge_tnt_case_spec_into_struc_formula ctx spec ei.CF.formula_inf_continuation in
    if ei.CF.formula_inf_tnt then cont
    else CF.EInfer { ei with CF.formula_inf_continuation = cont }
  | CF.EList el -> 
    CF.mkEList_no_flatten (map_l_snd (merge_tnt_case_spec_into_struc_formula ctx spec) el)
    
and merge_tnt_case_spec_into_assume ctx spec af =
  match spec with
  | Sol s -> struc_formula_of_ann_w_assume af s
  | Unknown -> struc_formula_of_ann_w_assume af (MayLoop, [])
  | Cases cases -> 
    try (* Sub-case of current context; all other cases are excluded *)
      let sub_case = List.find (fun (c, _) -> fp_imply ctx c) cases in
      merge_tnt_case_spec_into_assume ctx (snd sub_case) af
    with _ -> 
      CF.ECase {
        CF.formula_case_branches = List.map (fun (c, s) -> 
          let nctx, _ = CF.combine_and ctx (MCP.mix_of_pure c) in
          if f_is_sat nctx then (c, merge_tnt_case_spec_into_assume ctx s af)
          else (c, struc_formula_of_dead_path ())) cases;
        CF.formula_case_pos = no_pos; }
        
let rec flatten_one_case_struc c f = 
  match f with
  | CF.ECase fec ->
    let cfv = CP.fv c in
    let should_flatten = List.for_all (fun (fc, _) ->
      subset (CP.fv fc) cfv) fec.CF.formula_case_branches in
    if not should_flatten then [(c, f)]
    else
      List.fold_left (fun fac (fc, ff) ->
        let mc = mkAnd c fc in
        if is_sat mc then fac @ [(mc, ff)]
        else fac) [] fec.CF.formula_case_branches
  | CF.EList el -> begin match el with
    | (_, sf)::[] ->  begin match sf with
      | CF.ECase _ -> flatten_one_case_struc c sf
      | _ -> [(c, f)]
      end
    | _ -> [(c, f)]
    end
  | _ -> [(c, f)]
          
let rec flatten_case_struc struc_f =
  match struc_f with
  | CF.ECase ec -> 
    let nbranches = List.fold_left (fun ac (c, f) -> 
      let nf = flatten_case_struc f in
      let mf = flatten_one_case_struc c nf in 
      ac @ mf) [] ec.CF.formula_case_branches 
    in CF.ECase { ec with CF.formula_case_branches = nbranches }
  | CF.EBase eb -> CF.EBase { eb with CF.formula_struc_continuation = 
      map_opt flatten_case_struc eb.CF.formula_struc_continuation }
  | CF.EAssume _ -> struc_f
  | CF.EInfer ei -> CF.EInfer { ei with CF.formula_inf_continuation = 
      flatten_case_struc ei.CF.formula_inf_continuation }
  | CF.EList el -> CF.mkEList_no_flatten (map_l_snd flatten_case_struc el)

let flatten_case_struc struc_f = 
  let pr = string_of_struc_formula_for_spec in
  Debug.no_1 "flatten_case_struc" pr pr flatten_case_struc struc_f

let tnt_spec_of_proc proc ispec =
  let spec = proc.Cast.proc_static_specs in
  let spec = merge_tnt_case_spec_into_struc_formula 
    (CF.mkTrue (CF.mkTrueFlow ()) no_pos) ispec spec in
  let spec = flatten_case_struc spec in
  spec
    
let pr_proc_case_specs prog = 
  Hashtbl.iter (fun mn ispec ->
    try
      let proc = Cast.look_up_proc_def_no_mingling no_pos prog.Cast.new_proc_decls mn in
      let nspec = tnt_spec_of_proc proc ispec in
      print_endline (mn ^ ": " ^ (string_of_struc_formula_for_spec nspec))
    with _ -> (* Proc Decl is not found - SLEEK *)
      print_endline (mn ^ ": " ^ (print_tnt_case_spec ispec))) proc_case_specs
    
let update_spec_proc proc =
  let mn = Cast.unmingle_name (proc.Cast.proc_name) in
  try
    let ispec = Hashtbl.find proc_case_specs mn in
    let nspec = tnt_spec_of_proc proc ispec in
    let _ = proc.Cast.proc_stk_of_static_specs # push nspec in 
    let nproc = { proc with Cast.proc_static_specs = nspec; }  in
    (* let _ = Cprinter.string_of_proc_decl_no_body nproc in *)
    nproc
  with _ -> proc
    
let update_specs_prog prog = 
  let n_tbl = Cast.proc_decls_map (fun proc ->
    update_spec_proc proc) prog.Cast.new_proc_decls in
  { prog with Cast.new_proc_decls = n_tbl }
  
(* TNT Graph *)
module TNTElem = struct
  type t = int
  let compare = compare
  let hash = Hashtbl.hash
  let equal = (=)
end

module TNTEdge = struct
  type t = call_trel
  let compare = compare_trel
  let hash = Hashtbl.hash
  let equal = eq_trel
  let default = dummy_trel
end

module TG = Graph.Persistent.Digraph.ConcreteLabeled(TNTElem)(TNTEdge)    
module TGC = Graph.Components.Make(TG)

(* Exceptions to guide the main algorithm *)
exception Restart_with_Cond of TG.t
exception Should_Finalize

let graph_of_trels trels =
  let tg = TG.empty in
  let tg = List.fold_left (fun g rel ->
    let src = CP.id_of_term_ann rel.termu_lhs in
    let dst = CP.id_of_term_ann rel.termu_rhs in
    let lbl = rel in
    TG.add_edge_e g (TG.E.create src lbl dst)) tg trels
  in tg
  
let print_graph_by_num g = 
  TG.fold_edges (fun s d a -> 
    (string_of_int s) ^ " -> " ^
    (string_of_int d) ^ "\n" ^ a)  g ""
    
let print_edge e = 
  let _, rel, _ = e in
  print_call_trel_debug rel
    
let print_graph_by_rel g = 
  TG.fold_edges (fun s d a -> 
    (print_edge (TG.find_edge g s d)) ^ "\n" ^ a)  g ""
  
let print_scc_num = pr_list string_of_int

let print_scc_list_num scc_list = 
  "scc size = " ^ (string_of_int (List.length scc_list)) ^ "\n" ^ 
  (pr_list (fun scc -> (print_scc_num scc) ^ "\n") scc_list)

let print_scc_array_num scc_array =
  print_scc_list_num (Array.to_list scc_array) 
 
(* A scc is acyclic iff it has only one node and *)
(* this node is not a successor of itself *) 
let is_acyclic_scc g scc =
  match scc with
  | v::[] -> 
    let succ = TG.succ g v in
    not (Gen.BList.mem_eq (==) v succ)
  | _ -> false

(* Returns a set of successors of a node *)
let succ_vertex g v =
  let succ = TG.succ g v in
  List.map (fun sc ->
    let _, rel, _ = TG.find_edge g v sc in
    rel.termu_rhs) succ 

(* Returns a set of successors of a scc *)  
let succ_scc g scc =
  List.concat (List.map (succ_vertex g) scc)

let succ_scc_num g scc =
  List.concat (List.map (TG.succ g) scc)

let outside_scc_succ_vertex g scc v =
  let succ = TG.succ g v in
  let outside_scc_succ = Gen.BList.difference_eq (==) succ scc in
  List.map (fun sc ->
    let _, rel, _ = TG.find_edge g v sc in
    rel.termu_rhs) outside_scc_succ
  (* List.concat (List.map (fun sc ->                                       *)
  (*   let edges = TG.find_all_edges g v sc in                              *)
  (*   List.map (fun (_, rel, _) -> rel.termu_rhs) edges) outside_scc_succ) *)
    
let outside_succ_scc g scc =
  List.concat (List.map (outside_scc_succ_vertex g scc) scc)
      
let outside_succ_scc_num g scc =
  let succ_scc_num = succ_scc_num g scc in
  Gen.BList.difference_eq (==) succ_scc_num scc
  
let no_outgoing_edge_scc g scc =
  (outside_succ_scc_num g scc) = []   

(* Methods to update rels in graph *)
let update_trel f_ann rel =
  update_call_trel rel (f_ann rel.termu_lhs) (f_ann rel.termu_rhs)

let edges_of_scc g scc =   
  let outgoing_scc_edges =
    List.concat (List.map (fun s ->
      let succ = TG.succ g s in
      List.concat (List.map (fun d ->
        TG.find_all_edges g s d) succ)) scc)
  in
  let incoming_scc_edges = 
    List.concat (List.map (fun d ->
      let pred = TG.pred g d in
      List.fold_left (fun a s ->
        if Gen.BList.mem_eq (==) s scc (* Excluding duplicate edges *)
        then a else a @ (TG.find_all_edges g s d)
      ) [] pred) scc)
  in (outgoing_scc_edges @ incoming_scc_edges)
  
let map_scc g scc f_edge = 
  let scc_edges = edges_of_scc g scc in
  List.fold_left (fun g e -> f_edge g e) g scc_edges

let update_edge g f_rel e =
  let s, rel, d = e in
  let nrel = f_rel rel in
  TG.add_edge_e (TG.remove_edge_e g e) (s, nrel, d)  
      
let map_ann_scc g scc f_ann = 
  let f_edge g e = update_edge g (update_trel f_ann) e in 
  map_scc g scc f_edge

(* This method returns all edges within a scc *)    
let find_scc_edges g scc = 
  let find_edges_vertex s =
    let succ = TG.succ g s in
    let scc_succ = Gen.BList.intersect_eq (==) succ scc in
    List.concat (List.map (fun d -> TG.find_all_edges g s d) scc_succ)
  in
  List.concat (List.map (fun v -> find_edges_vertex v) scc)
  
(* End of TNT Graph *)

(* Template Utilies *)
let templ_of_term_ann ann =
  match ann with
  | CP.TermR uid 
  | CP.TermU uid ->
    let args = List.filter (fun e -> not (CP.exp_is_boolean_var e)) uid.CP.tu_args in
    let templ_id = "t_" ^ uid.CP.tu_fname ^ "_" ^ (string_of_int uid.CP.tu_id) in 
    let templ_exp = CP.mkTemplate templ_id args no_pos in
    CP.Template templ_exp, [templ_exp.CP.templ_id], [Tlutils.templ_decl_of_templ_exp templ_exp]
  | _ -> CP.mkIConst (-1) no_pos, [], []

let add_templ_assume ctx constr inf_templs =
  let es = CF.empty_es (CF.mkTrueFlow ()) Label_only.Lab2_List.unlabelled no_pos in
  let es = { es with CF.es_infer_vars_templ = inf_templs } in
  Template.collect_templ_assume_init es ctx constr no_pos

let solve_templ_assume prog templ_decls inf_templs =
  let prog = { prog with Cast.prog_templ_decls = 
    Gen.BList.remove_dups_eq Cast.eq_templ_decl 
      (prog.Cast.prog_templ_decls @ templ_decls) } in
  let res, _, _ = Template.collect_and_solve_templ_assumes_common true prog 
    (List.map CP.name_of_spec_var inf_templs) in
  res

(* Ranking function synthesis *)
let templ_rank_constr_of_rel rel =
  let src_rank, src_templ_id, src_templ_decl = templ_of_term_ann rel.termu_lhs in
  let dst_rank, dst_templ_id, dst_templ_decl = templ_of_term_ann rel.termu_rhs in
  let inf_templs = src_templ_id @ dst_templ_id in
  let ctx = mkAnd rel.call_ctx (CP.cond_of_term_ann rel.termu_lhs) in
  let dec = mkGt src_rank dst_rank in
  let bnd = mkGte src_rank (CP.mkIConst 0 no_pos) in
  let constr = mkAnd dec bnd in
  let _ = add_templ_assume (MCP.mix_of_pure ctx) constr inf_templs in
  inf_templs, src_templ_decl @ dst_templ_decl
  
let infer_ranking_function_scc prog g scc =
  let scc_edges = find_scc_edges g scc in
  (* let _ = print_endline (pr_list print_edge scc_edges) in *)
  let inf_templs, templ_decls = List.fold_left (fun (id_a, decl_a) (_, rel, _) -> 
    let id, decl = templ_rank_constr_of_rel rel in
    (id_a @ id, decl_a @ decl)) ([], []) scc_edges in
  let inf_templs = Gen.BList.remove_dups_eq CP.eq_spec_var inf_templs in
  let res = solve_templ_assume prog templ_decls inf_templs in
  match res with
  | Sat model ->
    let sst = List.map (fun (v, i) -> (CP.SpecVar (Int, v, Unprimed), i)) model in
    let rank_of_ann = fun ann ->
      let rank_templ, _, _ = templ_of_term_ann ann in
      let rank_exp = Tlutils.subst_model_to_exp sst 
        (CP.exp_of_template_exp rank_templ) in
      [rank_exp]
    in Some rank_of_ann
  | _ -> None

(* Abductive Inference *)
let infer_abductive_cond prog ann ante conseq =
  if imply ante conseq then Some (CP.mkTrue no_pos)
  else
    (* Handle boolean formulas in consequent *)
    let bool_conseq, conseq = List.partition CP.is_bool_formula 
      (CP.split_conjunctions conseq) in
    if not (imply ante (CP.join_conjunctions bool_conseq)) then None
    else
      let abd_ante = CP.join_conjunctions (List.filter (fun f -> 
         not (CP.is_bool_formula f)) (CP.split_conjunctions ante)) in
      let abd_conseq = CP.join_conjunctions conseq in
      let abd_templ, abd_templ_id, abd_templ_decl = templ_of_term_ann ann in
      let abd_cond = mkGte abd_templ (CP.mkIConst 0 no_pos) in
      let abd_ctx = mkAnd abd_ante abd_cond in
      
      (* let _ = print_endline ("ABD LHS: " ^ (!CP.print_formula abd_ctx)) in    *)
      (* let _ = print_endline ("ABD RHS: " ^ (!CP.print_formula abd_conseq)) in *)
      
      let _ = add_templ_assume (MCP.mix_of_pure abd_ctx) abd_conseq abd_templ_id in
      let oc = !Tlutils.oc_solver in (* Using oc to get optimal solution *)
      let _ = Tlutils.oc_solver := true in 
      let res = solve_templ_assume prog abd_templ_decl abd_templ_id in
      let _ = Tlutils.oc_solver := oc in
        
      match res with
      | Sat model ->
        let sst = List.map (fun (v, i) -> (CP.SpecVar (Int, v, Unprimed), i)) model in
        let abd_exp = Tlutils.subst_model_to_exp sst (CP.exp_of_template_exp abd_templ) in
        let icond = mkGte abd_exp (CP.mkIConst 0 no_pos) in
        if is_sat (mkAnd ante icond) 
        then Some icond
        else None
      | _ -> None

let infer_abductive_cond prog ann ante conseq =
  let pr = !CP.print_formula in
  Debug.no_2 "infer_abductive_cond" pr pr (pr_option pr) 
  (fun _ _ -> infer_abductive_cond prog ann ante conseq) ante conseq

let infer_abductive_icond_edge prog g e =
  let _, rel, _ = e in
  match rel.termu_lhs with
  | TermU uid ->
    let tuc = uid.CP.tu_cond in
    let eh_ctx = mkAnd rel.call_ctx tuc in
    
    let tuic = uid.CP.tu_icond in
    (* let params = List.concat (List.map CP.afv uid.CP.tu_args) in *)
    let params = params_of_term_ann prog rel.termu_rhs in
    let args = CP.args_of_term_ann rel.termu_rhs in
    let abd_conseq = CP.subst_term_avoid_capture (List.combine params args) tuic in
    let ires = infer_abductive_cond prog rel.termu_lhs eh_ctx abd_conseq in
    begin match ires with
    | None -> None
    | Some ic -> Some (uid, ic) 
    end
    
    (* let bool_abd_conseq, abd_conseq = List.partition CP.is_bool_formula                      *)
    (*   (CP.split_conjunctions abd_conseq) in                                                  *)
    
    (* if not (imply eh_ctx (CP.join_conjunctions bool_abd_conseq)) then None                   *)
    (* else                                                                                     *)
    (*   let abd_conseq = CP.join_conjunctions abd_conseq in                                    *)
    (*   let abd_templ, abd_templ_id, abd_templ_decl = templ_of_term_ann rel.termu_lhs in       *)
    (*   let abd_cond = mkGte abd_templ (CP.mkIConst 0 no_pos) in                               *)
    (*   let abd_ctx = mkAnd eh_ctx abd_cond in                                                 *)
      
    (*   (* let _ = print_endline ("ABD LHS: " ^ (!CP.print_formula abd_ctx)) in    *)          *)
    (*   (* let _ = print_endline ("ABD RHS: " ^ (!CP.print_formula abd_conseq)) in *)          *)
      
    (*   if imply eh_ctx abd_conseq then                                                        *)
    (*     let icond = CP.mkTrue no_pos in (* The node has an edge looping on itself *)         *)
    (*     Some (uid, icond)                                                                    *)
    (*   else                                                                                   *)
    (*     let _ = add_templ_assume (MCP.mix_of_pure abd_ctx) abd_conseq abd_templ_id in        *)
    (*     let oc = !Tlutils.oc_solver in (* Using oc to get optimal solution *)                *)
    (*     let _ = Tlutils.oc_solver := true in                                                 *)
    (*     let res = solve_templ_assume prog abd_templ_decl abd_templ_id in                     *)
    (*     let _ = Tlutils.oc_solver := oc in                                                   *)
        
    (*     begin match res with                                                                 *)
    (*     | Sat model ->                                                                       *)
    (*       let sst = List.map (fun (v, i) -> (CP.SpecVar (Int, v, Unprimed), i)) model in     *)
    (*       let abd_exp = Tlutils.subst_model_to_exp sst (CP.exp_of_template_exp abd_templ) in *)
    (*       let icond = mkGte abd_exp (CP.mkIConst 0 no_pos) in                                *)
          
    (*       (* let _ = print_endline ("ABD: " ^ (!CP.print_formula icond)) in *)               *)
          
    (*       (* Update TNT case spec with new abductive case *)                                 *)
    (*       (* if the abductive condition is feasible       *)                                 *)
    (*       if is_sat (mkAnd abd_ctx icond) then                                               *)
    (*         (* let _ = update_case_spec_with_icond_proc uid.CP.tu_fname tuc icond in *)      *)
    (*         Some (uid, icond)                                                                *)
    (*       else None                                                                          *)
    (*     | _ -> None end                                                                      *)
  | _ -> None 
      
let infer_abductive_icond_vertex prog g v = 
  let self_loop_edges = TG.find_all_edges g v v in
  let abd_conds = List.fold_left (fun a e -> a @ 
    opt_to_list (infer_abductive_icond_edge prog g e)) [] self_loop_edges in
  match abd_conds with
  | [] -> []
  | (uid, _)::_ -> 
    let icond_lst = List.map snd abd_conds in
    let full_disj_icond_lst = get_full_disjoint_cond_list icond_lst in
    (* let _ = print_endline ("full_disj_icond_lst: " ^      *)
    (*   (pr_list !CP.print_formula full_disj_icond_lst)) in *)
    let _ = update_case_spec_with_icond_list_proc 
      uid.CP.tu_fname uid.CP.tu_cond full_disj_icond_lst
    in [(uid.CP.tu_id, full_disj_icond_lst)]
  
let infer_abductive_icond prog g scc =
  List.concat (List.map (fun v -> infer_abductive_icond_vertex prog g v) scc)
  
(* Update rels in graph with abductive conditions *)
let inst_lhs_trel_abd rel abd_conds =  
  let lhs_ann = rel.termu_lhs in
  let inst_lhs = match lhs_ann with
    | CP.TermU uid -> 
      begin try
        let tid = uid.CP.tu_id in
        let iconds = List.assoc tid abd_conds in
        let iconds_w_id = assign_id_to_list iconds in  
        
        let tuc = uid.CP.tu_cond in
        let eh_ctx = mkAnd rel.call_ctx tuc in
        List.concat (List.map (fun (i, c) -> 
          if (is_sat (mkAnd eh_ctx c)) then
            [ CP.TermU { uid with
                CP.tu_id = cantor_pair tid i;
                CP.tu_cond = mkAnd tuc c;
                CP.tu_icond = c; }]
          else []) iconds_w_id)
      with Not_found -> [lhs_ann] end
    | _ -> [lhs_ann]
  in inst_lhs
  
let inst_rhs_trel_abd inst_lhs rel abd_conds = 
  let rhs_ann = rel.termu_rhs in
  let cond_lhs = CP.cond_of_term_ann inst_lhs in
  let ctx = mkAnd rel.call_ctx cond_lhs in
  let inst_rhs = match rhs_ann with
    | CP.TermU uid ->
      let tid = uid.CP.tu_id in
      let tuc = uid.CP.tu_cond in
      let eh_ctx = mkAnd ctx tuc in
      if not (is_sat eh_ctx) then []
      else
        begin try
          let iconds = List.assoc tid abd_conds in
          let params = rel.termu_rhs_params in
          let args = uid.CP.tu_args in
          let sst = List.combine params args in
          let iconds = List.map (CP.subst_term_avoid_capture sst) iconds in
          let iconds_w_id = assign_id_to_list iconds in 
          List.concat (List.map (fun (i, c) -> 
            if (is_sat (mkAnd eh_ctx c)) then
              [ CP.TermU { uid with
                CP.tu_id = cantor_pair tid i;
                CP.tu_cond = mkAnd tuc c;
                CP.tu_icond = c; }]
            else []) iconds_w_id)
        with Not_found -> [rhs_ann] end
    | _ -> [rhs_ann]
  in List.map (fun irhs -> update_call_trel rel inst_lhs irhs) inst_rhs
  
let inst_call_trel_abd rel abd_conds =
  let inst_lhs = inst_lhs_trel_abd rel abd_conds in
  let inst_rels = List.concat (List.map (fun ilhs -> 
    inst_rhs_trel_abd ilhs rel abd_conds) inst_lhs) in
  inst_rels

let update_graph_with_icond g scc abd_conds =
  let f_e g e =
    let _, rel, _ = e in
    let inst_rels = inst_call_trel_abd rel abd_conds in
    List.fold_left (fun g rel -> 
      let s = CP.id_of_term_ann rel.termu_lhs in
      let d = CP.id_of_term_ann rel.termu_rhs in
      TG.add_edge_e g (s, rel, d)) g inst_rels
  in  
  let scc_edges = edges_of_scc g scc in
  let g = List.fold_left (fun g v -> TG.remove_vertex g v) g scc in
  List.fold_left (fun g e -> f_e g e) g scc_edges

(* Only update nodes in scc *)  
let update_ann scc f ann = 
  let ann_id = CP.id_of_term_ann ann in
  if Gen.BList.mem_eq (==) ann_id scc 
  then f ann
  else ann
  
let subst sol ann =
  let fn = CP.fn_of_term_ann ann in
  let cond = CP.cond_of_term_ann ann in
  (* Add call number into the result *)
  let call_num = CP.call_num_of_term_ann ann in
  let sol = match (fst sol) with
    | CP.Term -> (fst sol, (CP.mkIConst call_num no_pos)::(snd sol))
    | _ -> sol 
  in
  (* Update TNT case spec with solution *)
  let _ = add_sol_case_spec_proc fn cond sol in
  (* let _ = print_endline ("Case spec @ scc " ^ (print_scc_num scc)) in *)
  (* let _ = pr_proc_case_specs () in                                    *)  
  subst_sol_term_ann sol ann
  
(* Proving non-termination or infering abductive condition           *)
(* for case analysis from an interesting condition                   *)
(* For each return assumption, we will obtain three kinds of result: *)
(* - YES (A /\ true |- B)                                            *)
(* - Definite NO (A |- !B)                                           *)
(* - Possible NO with Abductive Condition (Otherwise: A /\ C |- B)   *)
type nt_res = 
  | NT_Yes
  | NT_No of (CP.formula option)

let print_nt_res = function
  | NT_Yes -> "NT_Yes"
  | NT_No ic -> "NT_No[" ^ (pr_option !CP.print_formula ic) ^ "]" 

let is_nt_yes = function
  | NT_Yes -> true
  | _ -> false

let cond_of_nt_res = function
  | NT_Yes -> None
  | NT_No ic -> ic

let rec infer_abductive_cond_list prog ann ante conds =
  match conds with
  | [] -> None
  | c::cs -> 
    if imply ante (mkNot c) 
    then infer_abductive_cond_list prog ann ante cs
    else
      let ic = infer_abductive_cond prog ann ante c in
      match ic with
      | None -> infer_abductive_cond_list prog ann ante cs
      | Some _ -> ic

let proving_non_termination_one_trrel prog cond icond trrel = 
  let ctx = trrel.ret_ctx in
  let eh_ctx = mkAnd ctx cond in
  if not (is_sat eh_ctx) then None (* No result for infeasible context *)
  else
    let rhs_conds = List.map (fun ann -> 
      subst_cond_with_ann trrel.termr_rhs_params ann cond) trrel.termr_lhs in
    (* nt_res with candidates for abductive inference *)
    let ntres =
      if List.exists (fun c -> imply eh_ctx c) rhs_conds then Some NT_Yes
      else 
        let rhs_iconds = List.map (fun ann -> 
          subst_cond_with_ann trrel.termr_rhs_params ann icond) trrel.termr_lhs in
        let ir = infer_abductive_cond_list prog trrel.termr_rhs eh_ctx rhs_iconds in
        Some (NT_No ir)
    in ntres
    
let proving_non_termination_one_trrel prog cond icond trrel = 
  let pr1 = !CP.print_formula in
  let pr2 = print_ret_trel in
  Debug.no_3 "proving_non_termination_one_trrel" pr1 pr1 pr2 (pr_option print_nt_res)
    (fun _ _ _ -> proving_non_termination_one_trrel prog cond icond trrel)
    cond icond trrel

let proving_non_termination_trrels prog cond icond trrels =  
  let ntres = List.map (proving_non_termination_one_trrel prog cond icond) trrels in
  let ntres = List.concat (List.map opt_to_list ntres) in
  if ntres = [] then None, []
  else if List.for_all is_nt_yes ntres then Some CP.Loop, []
  else 
    let ic_list = List.concat (List.map (fun r -> 
      opt_to_list (cond_of_nt_res r)) ntres) in
    let full_disj_ic_list = get_full_disjoint_cond_list ic_list in
    None, full_disj_ic_list

(* Note that each vertex is a unique condition *)        
let proving_non_termination_vertex prog trrels tg v =
  try 
    let _, rel, _ = TG.find_edge tg v v in
    match rel.termu_lhs with
    | TermU uid -> 
      let ntres, abd_conds = proving_non_termination_trrels prog 
        uid.CP.tu_cond uid.CP.tu_icond trrels in
      let _ = match ntres with
      | Some _ -> () (* Non-termination *)
      | None -> 
        update_case_spec_with_icond_list_proc uid.CP.tu_fname uid.CP.tu_cond abd_conds
        (* ; pr_proc_case_specs prog *)
      in ntres, abd_conds
    | _ -> None, []
  with _ -> None, [] 

let rec proving_non_termination_scc acc_abd_conds prog trrels tg scc =
  match scc with
  | [] -> 
    let orig_scc = List.map fst acc_abd_conds in
    let tg = update_graph_with_icond tg orig_scc acc_abd_conds in
    raise (Restart_with_Cond tg)
  | v::vs -> 
    let ntres, abd_conds = proving_non_termination_vertex prog trrels tg v in
    
    (* let _ = print_endline ("Vertex " ^ (string_of_int v)) in       *)
    (* let _ = print_endline (pr_list !CP.print_formula abd_conds) in *)
    
    match ntres with
    | Some ann -> update_ann scc (subst (ann, []))
    | _ -> 
      let acc_abd_conds = acc_abd_conds @ [(v, abd_conds)] in
      proving_non_termination_scc acc_abd_conds prog trrels tg vs
  
(* Auxiliary methods for main algorithms *)
let aux_solve_turel_one_scc prog trrels tg scc =
  (* let _ = print_endline ("Analyzing scc: " ^ (pr_list string_of_int scc)) in *)
  (* Term with a ranking function for each scc's node *)
  let res = infer_ranking_function_scc prog tg scc in
  match res with
  | Some rank_of_ann ->
    let scc_num = CP.mkIConst (scc_fresh_int ()) no_pos in
    update_ann scc (fun ann ->
      let res = (CP.Term, scc_num::(rank_of_ann ann)) in 
      subst res ann)
  | None -> proving_non_termination_scc [] prog trrels tg scc
  