open Globals
open Gen
open Exc.GTable
open Perm
open Cformula

module Err = Error
module CP = Cpure
module MCP = Mcpure

let no_infer estate = (estate.es_infer_vars == [])

let rec infer_heap_aux heap vars = match heap with
  | ViewNode ({ h_formula_view_node = p;
  h_formula_view_arguments = args})
  | DataNode ({h_formula_data_node = p;
  h_formula_data_arguments = args}) -> List.mem p vars
  | Star ({h_formula_star_h1 = h1;
    h_formula_star_h2 = h2;
    h_formula_star_pos = pos})
  | Conj ({h_formula_conj_h1 = h1;
    h_formula_conj_h2 = h2;
    h_formula_conj_pos = pos}) ->
    infer_heap_aux h1 vars || infer_heap_aux h2 vars
  | _ -> false

let infer_heap_main iheap ivars old_vars = 
  let rec infer_heap heap vars = 
    match heap with
    | ViewNode ({ h_formula_view_node = p;
    h_formula_view_arguments = args})
    | DataNode ({h_formula_data_node = p;
    h_formula_data_arguments = args}) -> 
      if List.mem p vars then 
        (Gen.Basic.remove_dups (List.filter (fun x -> CP.name_of_spec_var x!= CP.name_of_spec_var p) 
          vars @ args), heap) 
      else (ivars, HTrue)
    | Star ({h_formula_star_h1 = h1;
      h_formula_star_h2 = h2;
      h_formula_star_pos = pos}) ->
      let res1 = infer_heap_aux h1 vars in
      let res2 = infer_heap_aux h2 vars in
      if res1 then 
        let (vars1, heap1) = infer_heap h1 vars in
        let (vars2, heap2) = infer_heap h2 vars1 in
        (vars2, Star ({h_formula_star_h1 = heap1;
                       h_formula_star_h2 = heap2;
                       h_formula_star_pos = pos}))
      else
      if res2 then 
        let (vars2, heap2) = infer_heap h2 vars in
        let (vars1, heap1) = infer_heap h1 vars2 in
        (vars1, Star ({h_formula_star_h1 = heap1;
                       h_formula_star_h2 = heap2;
                       h_formula_star_pos = pos}))
      else (ivars, HTrue)
    | Conj ({h_formula_conj_h1 = h1;
      h_formula_conj_h2 = h2;
      h_formula_conj_pos = pos}) ->
      let res1 = infer_heap_aux h1 vars in
      let res2 = infer_heap_aux h2 vars in
      if res1 then 
        let (vars1, heap1) = infer_heap h1 vars in
        let (vars2, heap2) = infer_heap h2 vars1 in
        (vars2, Conj ({h_formula_conj_h1 = heap1;
                       h_formula_conj_h2 = heap2;
                       h_formula_conj_pos = pos}))
      else
      if res2 then 
        let (vars2, heap2) = infer_heap h2 vars in
        let (vars1, heap1) = infer_heap h1 vars2 in
        (vars1, Conj ({h_formula_conj_h1 = heap1;
                       h_formula_conj_h2 = heap2;
                       h_formula_conj_pos = pos}))
      else (ivars, HTrue)
    | _ -> (ivars, HTrue)
  in infer_heap iheap ivars
(*
type: h_formula ->
  CP.spec_var list -> CP.spec_var list -> CP.spec_var list * h_formula
*)
let infer_heap_main iheap ivars old_vars = 
  let pr1 = !print_h_formula in
  let prv = !print_svl in
  let pr2 = pr_pair prv pr1 in
  Gen.Debug.ho_3 "infer_heap_main" pr1 prv prv pr2 infer_heap_main iheap ivars old_vars

let conv_infer_heap hs =
  let rec helper hs h = match hs with
    | [] -> h
    | x::xs -> 
          let acc = 
	        Star({h_formula_star_h1 = x;
	        h_formula_star_h2 = h;
	        h_formula_star_pos = no_pos})
          in helper xs acc in
  match hs with
    | [] -> HTrue 
    | x::xs -> helper xs x

let extract_pre_list_context x = 
  (* TODO : this has to be implemented by extracting from es_infer_* *)
  (* print_endline (!print_list_context x); *)
  None

(* get exactly one root of h_formula *)
let get_args_h_formula (h:h_formula) =
  match h with
    | DataNode h -> 
          let arg = h.h_formula_data_arguments in
          let new_arg = CP.fresh_spec_vars_prefix "inf" arg in
         Some (h.h_formula_data_node, arg,new_arg, 
         DataNode {h with h_formula_data_arguments=new_arg;})
    | ViewNode h -> 
          let arg = h.h_formula_view_arguments in
          let new_arg = CP.fresh_spec_vars_prefix "inf" arg in
          Some (h.h_formula_view_node, arg,new_arg,
          ViewNode {h with h_formula_view_arguments=new_arg;} )
    | _ -> None

let get_alias_formula (f:formula) =
	let (h, p, fl, b, t) = split_components f in
    let eqns = (MCP.ptr_equations_without_null p) in
    eqns

let build_var_aset lst = CP.EMapSV.build_eset lst

(*
 let iv = es_infer_vars in
 check if h_formula root isin iv
 if not present then 
  begin
    (i) look for le = lhs_pure based on iv e.g n=0
        e.g. infer [n] n=0 |- x::node<..>
   (ii) if le=true then None
        else add not(le) to infer_pure
  end
 else 
  begin
   check if rhs causes a contradiction with estate
      e.g. infer [x] x=null |- x::node<..>
      if so then
           ?
      else
         add h_formula to infer_heap
  end
*)

let infer_heap_nodes (es:entail_state) (rhs:h_formula) conseq = 
  let iv = es.es_infer_vars in
  let rt = get_args_h_formula rhs in
  let lhs_als = get_alias_formula es.es_formula in
  let lhs_aset = build_var_aset lhs_als in
  let rhs_als = get_alias_formula conseq in
  let rhs_aset = build_var_aset rhs_als in
  let (b,args,inf_vars,new_h,new_iv) = match rt with (* is rt captured by iv *)
    | None -> false,[],[],HTrue,iv
    | Some (r,args,arg2,h) -> 
          let rt_al = CP.EMapSV.find_equiv_all r lhs_aset in (* set of alias with root of rhs *)
          let b = not((CP.intersect iv rt_al) == []) in (* does it intersect with iv *)
          let new_iv = arg2@(CP.diff_svl iv rt_al) in
          (List.exists (CP.eq_spec_var_aset lhs_aset r) iv,args,arg2,h,new_iv) in
  let args_al = List.map (fun v -> CP.EMapSV.find_equiv_all v rhs_aset) args in
  let _ = print_endline ("infer_heap_nodes") in
  let _ = print_endline ("infer var: "^(!print_svl iv)) in
  let _ = print_endline ("new infer var: "^(!print_svl new_iv)) in
  (* let _ = print_endline ("LHS aliases: "^(pr_list (pr_pair !print_sv !print_sv) lhs_als)) in *)
  (* let _ = print_endline ("RHS aliases: "^(pr_list (pr_pair !print_sv !print_sv) rhs_als)) in *)
  let _ = print_endline ("root: "^(pr_option (fun (r,_,_,_) -> !print_sv r) rt)) in
  let _ = print_endline ("rhs node: "^(!print_h_formula rhs)) in
  let _ = print_endline ("renamed rhs node: "^(!print_h_formula new_h)) in
  (* let _ = print_endline ("heap args: "^(!print_svl args)) in *)
  (* let _ = print_endline ("heap inf args: "^(!print_svl inf_vars)) in *)
  (* let _ = print_endline ("heap arg aliases: "^(pr_list !print_svl args_al)) in *)
  let _ = print_endline ("root in iv: "^(string_of_bool b)) in
  (* let _ = print_endline ("RHS exist vars: "^(!print_svl es.es_evars)) in *)
  (* let _ = print_endline ("RHS impl vars: "^(!print_svl es.es_gen_impl_vars)) in *)
  (* let _ = print_endline ("RHS expl vars: "^(!print_svl es.es_gen_expl_vars)) in *)
  (* let _ = print_endline ("imm pure stack: "^(pr_list !print_mix_formula es.es_imm_pure_stk)) in *)
  None

let infer_lhs_conjunct estate lhs_xpure rhs_xpure h2 p2 pos =
  if no_infer estate then estate
  else
    let pure_part_aux = Omega.is_sat (CP.mkAnd (MCP.pure_of_mix lhs_xpure) (MCP.pure_of_mix rhs_xpure) pos) "0" in
    let rec filter_var_aux f vars = match f with
      | CP.Or (f1,f2,l,p) -> CP.Or (filter_var_aux f1 vars, filter_var_aux f2 vars, l, p)
      | _ -> CP.filter_var f vars
    in
    let filter_var f vars = 
      if CP.isConstTrue (Omega.simplify f) then CP.mkTrue pos 
      else
        let res = filter_var_aux f vars in
        if CP.isConstTrue (Omega.simplify res) then CP.mkFalse pos
        else res
    in
    let invs = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) estate.es_infer_invs in
    let pure_part = 
      if pure_part_aux = false then
        let mkNot purefml = 
          let conjs = CP.split_conjunctions purefml in
          let conjs = List.map (fun c -> CP.mkNot_s c) conjs in
          List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) conjs
        in
        let lhs_pure = CP.mkAnd (mkNot (Omega.simplify 
            (filter_var (MCP.pure_of_mix lhs_xpure) estate.es_infer_vars))) invs pos in
        (*print_endline ("PURE1: " ^ Cprinter.string_of_pure_formula lhs_pure);*)
        CP.mkAnd lhs_pure (MCP.pure_of_mix rhs_xpure) pos
      else
        Omega.simplify (CP.mkAnd (CP.mkAnd (MCP.pure_of_mix lhs_xpure) (MCP.pure_of_mix p2) pos) invs pos)
    in
    (*print_endline ("PURE: " ^ Cprinter.string_of_mix_formula p2);*)
    (*print_endline ("HEAP: " ^ Cprinter.string_of_h_formula h2);*)
    let pure_part2 = filter_var (Omega.simplify pure_part) estate.es_infer_vars in
    let infer_pure = Omega.simplify pure_part2 in
    (*print_endline ("PURE1: " ^ Cprinter.string_of_pure_formula infer_pure);*)
    (*print_endline ("VARS: " ^ Cprinter.poly_string_of_pr Cprinter.pr_list_of_spec_var estate.es_infer_vars);*)
    let new_vars = Cpure.fv infer_pure in
    let new_vars = Gen.Basic.remove_dups (new_vars @ estate.es_infer_vars)
      (*let tmp = Gen.Basic.remove_dups new_vars in
        List.fold_left (fun lvars var -> 
        List.filter (fun x -> CP.name_of_spec_var x!= CP.name_of_spec_var var) 
        lvars) tmp estate.es_infer_vars*)
    in
    let (infer_vars, infer_heap) = if h2 = HTrue then (estate.es_infer_vars, HTrue) else
      infer_heap_main h2 new_vars estate.es_infer_vars
    in
    let infer_pure = Omega.simplify (filter_var (Omega.simplify pure_part) infer_vars) in
    (*print_endline ("VARS: " ^ Cprinter.poly_string_of_pr Cprinter.pr_list_of_spec_var new_vars);*)
    (*print_endline ("VARS: " ^ Cprinter.poly_string_of_pr Cprinter.pr_list_of_spec_var estate.es_infer_vars);*)
    let infer_pure2 = Omega.simplify (CP.mkAnd infer_pure 
        (List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) 
            (estate.es_infer_pures @ [MCP.pure_of_mix p2])) pos) in
    let infer_pure = Omega.simplify (CP.mkAnd infer_pure (filter_var infer_pure2 infer_vars) pos) in
    let infer_pure = 
      if CP.isConstTrue infer_pure & pure_part_aux = false
      then [CP.mkFalse pos] else [infer_pure] in
    {estate with es_infer_vars = infer_vars; es_infer_heap = [infer_heap];
        es_infer_pure = infer_pure; es_infer_pures = estate.es_infer_pures @ [(MCP.pure_of_mix p2)]}

let infer_empty_rhs estate lhs_p rhs_p pos =
  if no_infer estate then estate
  else
    let rec filter_var f vars = match f with
      | CP.Or (f1,f2,l,p) -> CP.Or (filter_var f1 vars, filter_var f2 vars, l, p)
      | _ -> CP.filter_var f vars
    in
    let infer_pure = MCP.pure_of_mix rhs_p in
    let infer_pure = if CP.isConstTrue infer_pure then infer_pure
    else CP.mkAnd (MCP.pure_of_mix rhs_p) (MCP.pure_of_mix lhs_p) pos
    in 
    (*        print_endline ("PURE: " ^ Cprinter.string_of_pure_formula infer_pure);*)
    let infer_pure = Omega.simplify (filter_var infer_pure estate.es_infer_vars) in
    let pure_part2 = Omega.simplify (List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) 
        (estate.es_infer_pures @ [MCP.pure_of_mix rhs_p])) in
    (*        print_endline ("PURE2: " ^ Cprinter.string_of_pure_formula infer_pure);*)
    let infer_pure = if Omega.is_sat pure_part2 "0" = false then [CP.mkFalse pos] else [infer_pure] in
      {estate with es_infer_heap = []; es_infer_pure = infer_pure;
          es_infer_pures = estate.es_infer_pures @ [(MCP.pure_of_mix rhs_p)]}

let infer_empty_rhs2 estate lhs_xpure rhs_p pos =
  if no_infer estate then estate
  else
    (* let lhs_xpure,_,_,_ = xpure prog estate.es_formula in *)
    let pure_part_aux = Omega.is_sat (CP.mkAnd (MCP.pure_of_mix lhs_xpure) (MCP.pure_of_mix rhs_p) pos) "0" in
    let rec filter_var_aux f vars = match f with
      | CP.Or (f1,f2,l,p) -> CP.Or (filter_var_aux f1 vars, filter_var_aux f2 vars, l, p)
      | _ -> CP.filter_var f vars
    in
    let filter_var f vars = 
      if CP.isConstTrue (Omega.simplify f) then CP.mkTrue pos 
      else
        let res = filter_var_aux f vars in
        if CP.isConstTrue (Omega.simplify res) then CP.mkFalse pos
        else res
    in
    let invs = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) estate.es_infer_invs in
    let pure_part = 
      if pure_part_aux = false then
        let mkNot purefml = 
          let conjs = CP.split_conjunctions purefml in
          let conjs = List.map (fun c -> CP.mkNot_s c) conjs in
          List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) conjs
        in
        let lhs_pure = CP.mkAnd (mkNot(Omega.simplify 
            (filter_var (MCP.pure_of_mix lhs_xpure) estate.es_infer_vars))) invs pos in
        (*print_endline ("PURE2: " ^ Cprinter.string_of_pure_formula lhs_pure);*)
        CP.mkAnd lhs_pure (MCP.pure_of_mix rhs_p) pos
      else Omega.simplify (CP.mkAnd (CP.mkAnd (MCP.pure_of_mix lhs_xpure) (MCP.pure_of_mix rhs_p) pos) invs pos)
    in
    let pure_part = filter_var (Omega.simplify pure_part) estate.es_infer_vars in
    (*        print_endline ("PURE: " ^ Cprinter.string_of_mix_formula rhs_p);*)
    let pure_part = Omega.simplify pure_part in
    let pure_part2 = Omega.simplify (CP.mkAnd pure_part 
        (List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) 
            (estate.es_infer_pures @ [MCP.pure_of_mix rhs_p])) pos) in
    (*        print_endline ("PURE1: " ^ Cprinter.string_of_pure_formula pure_part);*)
    (*        print_endline ("PURE2: " ^ Cprinter.string_of_pure_formula pure_part2);*)
    let pure_part = if (CP.isConstTrue pure_part & pure_part_aux = false) 
      || Omega.is_sat pure_part2 "0" = false then [CP.mkFalse pos] else [pure_part] in
    {estate with es_infer_heap = []; es_infer_pure = pure_part;
        es_infer_pures = estate.es_infer_pures @ [(MCP.pure_of_mix rhs_p)]}

(* what does this method do? *)
let infer_for_unfold prog estate lhs_node pos =
  if no_infer estate then estate
  else
    let inv = match lhs_node with
      | ViewNode ({h_formula_view_name = c}) ->
            let vdef = Cast.look_up_view_def pos prog.Cast.prog_view_decls c in
            let i = MCP.pure_of_mix (fst vdef.Cast.view_user_inv) in
            if List.mem i estate.es_infer_invs then estate.es_infer_invs
            else estate.es_infer_invs @ [i]
      | _ -> estate.es_infer_invs
    in {estate with es_infer_invs = inv} 
