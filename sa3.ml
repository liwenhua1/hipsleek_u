open Globals
open Others
open Gen

module DD = Debug
module Err = Error
module CA = Cast
module CP = Cpure
module CF = Cformula
module MCP = Mcpure
module CEQ = Checkeq
module TP = Tpdispatcher
module SAC = Sacore
module SAU = Sautility
module IC = Icontext
let step_change = new Gen.change_flag

(* outcome from shape_infer *)
let rel_def_stk : CF.hprel_def Gen.stack_pr = new Gen.stack_pr
  Cprinter.string_of_hprel_def_short (==)


(***************************************************************)
             (*      APPLY TRANS IMPL     *)
(****************************************************************)
let collect_ho_ass cprog is_pre def_hps (acc_constrs, post_no_def) cs=
  let lhs_hps = CF.get_hp_rel_name_formula cs.CF.hprel_lhs in
  let rhs_hps = CF.get_hp_rel_name_formula cs.CF.hprel_rhs in
  let linfer_hps = CP.remove_dups_svl (CP.diff_svl (lhs_hps) def_hps) in
  let rinfer_hps =  (CP.diff_svl (rhs_hps) def_hps) in
  let infer_hps = CP.remove_dups_svl (linfer_hps@rinfer_hps) in
  (* if infer_hps = [] then (acc_constrs, post_no_def) else *)
    let log_str = if is_pre then PK_Pre_Oblg else PK_Post_Oblg in
    let  _ = DD.info_pprint ((string_of_proving_kind log_str) ^ ":\n" ^ (Cprinter.string_of_hprel_short cs)) no_pos in
    let tmp = !Globals.do_classic_frame_rule in
    let _ = Globals.do_classic_frame_rule := true in
    let f = wrap_proving_kind log_str (SAC.do_entail_check infer_hps cprog) in
    let new_constrs = f cs in
    let _ = Globals.do_classic_frame_rule := tmp in
    (acc_constrs@new_constrs, post_no_def@linfer_hps)

(*input in fb
 output: true,susbs: can subst
*)

(*
dn is current node, it is one node of ldns
ss: subst from ldns -> ldns
*)
(*
equal_hps: are preds that are going to be generalized. DO NOT subst them
*)
let rec find_imply_subst_x prog unk_hps link_hps frozen_hps complex_hps constrs new_cs=
  let rec check_constr_duplicate (lhs,rhs) constrs=
    match constrs with
      | [] -> false
      | cs::ss -> if SAU.checkeq_pair_formula (lhs,rhs)
            (cs.CF.hprel_lhs,cs.CF.hprel_rhs) then
            true
          else check_constr_duplicate (lhs,rhs) ss
  in
  let find_imply_one cs1 cs2=
    let _ = Debug.ninfo_pprint ("    rhs: " ^ (Cprinter.string_of_hprel_short cs2)) no_pos in
    (*if this assumption is going to be equal generalized. do not subst*)
    let lhps = CF.get_hp_rel_name_formula cs2.CF.hprel_lhs in
    if List.length lhps<2 && CP.diff_svl lhps frozen_hps = [] then ([],[]) else
      let qvars1, f1 = CF.split_quantifiers cs1.CF.hprel_lhs in
      let qvars2, f2 = CF.split_quantifiers cs2.CF.hprel_rhs in
      match f1,f2 with
        | CF.Base lhs1, CF.Base rhs2 ->
              let r = SAU.find_imply prog (List.map fst cs1.CF.unk_hps) (List.map fst cs2.CF.unk_hps)
                lhs1 cs1.CF.hprel_rhs cs2.CF.hprel_lhs rhs2 cs1.CF.hprel_guard frozen_hps complex_hps in
            begin
              match r with
                | Some (l,r,lhs_ss, rhs_ss) ->
                      (*check duplicate*)
                      if check_constr_duplicate (l,r) (constrs@new_cs) then ([],[])
                      else
                        begin
                          let n_cs_hprel_guard =
                            match cs2.CF.hprel_guard with
                              | None -> None
                              | Some hf -> Some (CF.h_subst lhs_ss hf)
                          in
                          let new_cs = {cs2 with
                              CF.predef_svl = CP.remove_dups_svl
                                  ((CP.subst_var_list lhs_ss cs1.CF.predef_svl)@
                                      (CP.subst_var_list rhs_ss cs2.CF.predef_svl));
                              CF.unk_svl = CP.remove_dups_svl
                                  ((CP.subst_var_list lhs_ss cs1.CF.unk_svl)@
                                      (CP.subst_var_list rhs_ss cs2.CF.unk_svl));
                              CF.unk_hps = Gen.BList.remove_dups_eq SAU.check_hp_arg_eq
                                  ((List.map (fun (hp,args) -> (hp,CP.subst_var_list lhs_ss args)) cs1.CF.unk_hps)@
                                      (List.map (fun (hp,args) -> (hp,CP.subst_var_list rhs_ss args)) cs2.CF.unk_hps));
                              CF.hprel_lhs = l;
                              CF.hprel_guard = n_cs_hprel_guard;
                              CF.hprel_rhs = r;
                          }
                          in
                          let _ = Debug.ninfo_pprint ("    new rhs: " ^ (Cprinter.string_of_hprel_short new_cs)) no_pos in
                          (*moved after pre-preds synthesized*)
                          (* let l_hds, l_hvs,lhrels =CF.get_hp_rel_formula new_cs.CF.hprel_lhs in *)
                          (* let r_hds, r_hvs,rhrels =CF.get_hp_rel_formula new_cs.CF.hprel_rhs in *)
                          (* if (List.length l_hds > 0 || List.length l_hvs > 0) && List.length lhrels > 0 && *)
                          (*    (\* (List.length r_hds > 0 || List.length r_hvs > 0) && *\) List.length rhrels > 0 *)
                          (* then *)
                          (*   let ho_constrs, _ = collect_ho_ass prog true [] ([], []) new_cs in *)
                          (*   let ho_constrs1 = SAU.remove_dups_constr ho_constrs in *)
                          (*   if ho_constrs1==[] || *)
                          (*     check_constr_duplicate (new_cs.CF.hprel_lhs,new_cs.CF.hprel_rhs) ho_constrs1 then *)
                          (*       let new_cs1 = SAU.simp_match_hp_w_unknown prog unk_hps link_hps new_cs in *)
                          (*       ([new_cs1],[]) *)
                          (*   else *)
                          (*     (\***************  PRINTING*********************\) *)
                          (*     let _ = *)
                          (*       begin *)
                          (*         let pr = pr_list_ln Cprinter.string_of_hprel_short in *)
                          (*         print_endline ""; *)
                          (*         print_endline "\n*************************************************"; *)
                          (*         print_endline "*******relational assumptions (obligation)********"; *)
                          (*         print_endline "****************************************************"; *)
                          (*         print_endline (pr ho_constrs1); *)
                          (*         print_endline "*************************************" *)
                          (*       end *)
                          (*     in *)
                          (*     (ho_constrs1, List.map fst3 lhrels) *)
                          (*   (\***************  END PRINTING*********************\) *)
                          (* else *)
                            let new_cs1 = SAU.simp_match_hp_w_unknown prog unk_hps link_hps new_cs in
                            ([new_cs1],[])
                        end
                | None -> ([],[])
            end
      | _ -> report_error no_pos "sa2.find_imply_one"
  in
  (*new_cs: one x one*)
  (* let rec helper_new_only don rest res= *)
  (*   match rest with *)
  (*     | [] -> res *)
  (*     | cs1::rest -> *)
  (*         let _ = Debug.ninfo_pprint ("    lhs: " ^ (Cprinter.string_of_hprel cs1)) no_pos in *)
  (*         let r = List.concat (List.map (find_imply_one cs1) (don@rest@res)) in *)
  (*         (helper_new_only (don@[cs1]) rest (res@r)) *)
  (* in *)
  let rec helper_new_only don rest is_changed unfrozen_hps=
    match rest with
      | [] -> is_changed,don,unfrozen_hps
      | cs1::rest ->
          let _ = Debug.ninfo_pprint ("    lhs: " ^ (Cprinter.string_of_hprel_short cs1)) no_pos in
          if SAC.cs_rhs_is_only_neqNull cs1 then
            (helper_new_only (don@[cs1]) rest is_changed unfrozen_hps)
          else
            let is_changed1, new_rest, n_unfrozen_hps1 = List.fold_left ( fun (b,res, r_unfroz_hps) cs2->
                let new_constrs, unfroz_hps = find_imply_one cs1 cs2 in
                if List.length new_constrs > 0 then
                  (true,res@new_constrs, r_unfroz_hps@unfroz_hps)
                  else (b,res@[cs2], r_unfroz_hps)
            ) (is_changed, [], []) (rest)
            in
            let is_changed2,new_don, n_unfrozen_hps2 = List.fold_left ( fun (b,res, r_unfroz_hps) cs2->
                let new_constrs, unfroz_hps = find_imply_one cs1 cs2 in
                if List.length new_constrs > 0 then
                 (true,res@new_constrs,  r_unfroz_hps@unfroz_hps)
                else
                  (b,res@[cs2], r_unfroz_hps)
            ) (is_changed1,[], []) (don)
            in
            (helper_new_only (new_don@[cs1]) new_rest is_changed2 (unfrozen_hps@n_unfrozen_hps1@n_unfrozen_hps2))
  in
  (*new_cs x constr*)
  (* let rec helper_old_new rest res= *)
  (*   match rest with *)
  (*     | [] -> res *)
  (*     | cs1::ss -> *)
  (*         let r = List.fold_left ( fun ls cs2 -> ls@(find_imply_one cs1 cs2)) res constrs in *)
  (*         helper_old_new ss r *)
  (* in *)
  let is_changed,new_cs1,unfrozen_hps =
    if List.length new_cs < 1 then (false, new_cs, []) else
    helper_new_only [] new_cs false []
  in
  (* let new_cs2 = helper_old_new new_cs [] in *)
  (is_changed,new_cs1(* @new_cs2 *),unfrozen_hps)

and find_imply_subst prog unk_hps link_hps equal_hps complex_hps constrs new_cs=
  let pr1 = pr_list_ln Cprinter.string_of_hprel_short in
  Debug.no_2 "find_imply_subst" pr1 pr1 (pr_triple string_of_bool pr1 !CP.print_svl)
      (fun _ _ -> find_imply_subst_x prog unk_hps link_hps equal_hps complex_hps constrs new_cs) constrs new_cs

and is_trivial cs= (SAU.is_empty_f cs.CF.hprel_rhs) ||
  (SAU.is_empty_f cs.CF.hprel_lhs || SAU.is_empty_f cs.CF.hprel_rhs)

and is_non_recursive_non_post_cs post_hps dang_hps constr=
  let lhrel_svl = CF.get_hp_rel_name_formula constr.CF.hprel_lhs in
  let rhrel_svl = CF.get_hp_rel_name_formula constr.CF.hprel_rhs in
  (CP.intersect_svl rhrel_svl post_hps = []) && ((CP.intersect lhrel_svl rhrel_svl) = [])

and subst_cs_w_other_cs_x prog post_hps dang_hps link_hps equal_hps complex_hps constrs new_cs=
  (*remove recursive cs and post-preds based to preserve soundness*)
  let constrs1 = List.filter (fun cs -> (is_non_recursive_non_post_cs post_hps dang_hps cs) && not (is_trivial cs)) constrs in
  let new_cs1,rem = List.partition (fun cs -> (is_non_recursive_non_post_cs post_hps dang_hps cs) && not (is_trivial cs)) new_cs in
  let b,new_cs2, unfrozen_hps = find_imply_subst prog dang_hps link_hps equal_hps complex_hps constrs1 new_cs1 in
  (b, new_cs2@rem,unfrozen_hps)
(*=========END============*)

let rec subst_cs_w_other_cs prog post_hps dang_hps link_hps equal_hps complex_hps constrs new_cs=
  let pr1 = pr_list_ln Cprinter.string_of_hprel in
   Debug.no_1 "subst_cs_w_other_cs" pr1 (pr_triple string_of_bool pr1 !CP.print_svl)
       (fun _ -> subst_cs_w_other_cs_x prog post_hps dang_hps link_hps equal_hps complex_hps constrs  new_cs) constrs

(* let subst_cs_x prog dang_hps constrs new_cs = *)
(*   (\*subst by constrs*\) *)
(*   DD.ninfo_pprint "\n subst with other assumptions" no_pos; *)
(*   let new_cs1 = subst_cs_w_other_cs prog dang_hps constrs new_cs in *)
(*   (constrs@new_cs, new_cs1,[]) *)

(* let subst_cs prog dang_hps hp_constrs new_cs= *)
(*   let pr1 = pr_list_ln Cprinter.string_of_hprel in *)
(*   Debug.no_1 "subst_cs" pr1 (pr_triple pr1 pr1 !CP.print_svl) *)
(*       (fun _ -> subst_cs_x prog dang_hps hp_constrs new_cs) new_cs *)

let subst_cs_x prog post_hps dang_hps link_hps equal_hps complex_hps constrs new_cs =
  (*subst by constrs*)
  DD.ninfo_pprint "\n subst with other assumptions" no_pos;
  let is_changed, new_cs1,unfrozen_hps = subst_cs_w_other_cs prog post_hps dang_hps link_hps equal_hps complex_hps constrs new_cs in
  (is_changed, new_cs1,[], unfrozen_hps)

let subst_cs prog post_hps dang_hps link_hps equal_hps complex_hps hp_constrs new_cs=
  let pr1 = pr_list_ln Cprinter.string_of_hprel_short in
  Debug.no_1 "subst_cs" pr1 (pr_quad string_of_bool  pr1 pr1 !CP.print_svl)
      (fun _ -> subst_cs_x prog post_hps dang_hps link_hps equal_hps complex_hps hp_constrs new_cs) new_cs

(*===========fix point==============*)
let apply_transitive_impl_fix prog post_hps callee_hps (* hp_rel_unkmap *) dang_hps link_hps (constrs: CF.hprel list) =
  (* let dang_hps = (fst (List.split hp_rel_unkmap)) in *)
  (*find equal pre-preds: has one assumption.
    in the new algo, those will be generalized as equiv. do not need to substed
  *)
  (*frozen_hps: it is synthesized already*)
  let rec helper_x (constrs: CF.hprel list) new_cs frozen_hps =
    DD.binfo_pprint ">>>>>> step 3a: simplification <<<<<<" no_pos;
    let new_cs1 = (* SAU.simplify_constrs prog unk_hps *) new_cs in
    (*  Debug.ninfo_hprint (add_str "apply_transitive_imp LOOP: " (pr_list_ln Cprinter.string_of_hprel)) constrs no_pos; *)
    begin
      let equal_cands, complex_hps = SAC.search_pred_4_equal new_cs1 post_hps frozen_hps in
      let equal_hps = List.map fst equal_cands in
      let _ = if equal_hps <> [] then
        DD.binfo_pprint (" freeze: " ^ (!CP.print_svl equal_hps) )no_pos
      else ()
      in
      let frozen_hps0 = frozen_hps@equal_hps in
      DD.binfo_pprint ">>>>>> step 3b: do apply_transitive_imp <<<<<<" no_pos;
      (* let constrs2, new_cs2, new_non_unk_hps = subst_cs prog dang_hps constrs new_cs1 in *)
      if equal_hps = [] then
        (*stop*)
        let _ =  if complex_hps <> [] then DD.binfo_pprint (" freeze: " ^ (!CP.print_svl complex_hps) ) no_pos
        else ()
        in
        (constrs@new_cs1,[])
      else
        let is_changed, constrs2,new_cs2,unfrozen_hps  = subst_cs prog post_hps dang_hps link_hps (frozen_hps@equal_hps)
          complex_hps constrs new_cs1 in
        let unfrozen_hps1 = CP.remove_dups_svl (CP.intersect_svl unfrozen_hps frozen_hps0) in
        let frozen_hps1 = CP.diff_svl  frozen_hps0 unfrozen_hps1 in
        let _ = if unfrozen_hps1 <> [] then
          DD.binfo_pprint (" unfreeze: " ^ (!CP.print_svl unfrozen_hps) )no_pos
        else ()
        in
        (*for debugging*)
        let _ = DD.ninfo_pprint ("   new constrs:" ^ (let pr = pr_list_ln Cprinter.string_of_hprel_short in pr constrs2)) no_pos in
        let helper (constrs: CF.hprel list) new_cs=
          let pr = pr_list_ln Cprinter.string_of_hprel_short in
          Debug.no_1 "apply_transitive_imp_fix" pr (fun (cs,_) -> pr cs)
              (fun _ -> helper_x constrs new_cs) new_cs
        in
        (*END for debugging*)
        let norm_constrs, non_unk_hps1 =
          let constrs, new_constrs = if is_changed then (new_cs2, constrs2) else (constrs, new_cs1) in
          (* helper new_cs2 constrs2 (frozen_hps@equal_hps) in *)
          helper constrs new_constrs frozen_hps1
      in
      (norm_constrs, [])
    end
  in
  let _ = DD.ninfo_pprint ("   constrs:" ^ (let pr = pr_list_ln Cprinter.string_of_hprel_short in pr constrs)) no_pos in
  helper_x [] constrs []


(*split constrs like H(x) & x = null --> G(x): separate into 2 constraints*)
let split_base_constr prog cond_path constrs post_hps prog_vars unk_map unk_hps link_hps=
  (*internal method*)
  let split_one cs total_unk_map=
    let _ = Debug.ninfo_pprint ("  cs: " ^ (Cprinter.string_of_hprel_short cs)) no_pos in
    let (_ ,mix_lf,_,_,_) = CF.split_components cs.CF.hprel_lhs in
    let l_qvars, lhs = CF.split_quantifiers cs.CF.hprel_lhs in
    let r_qvars, rhs = CF.split_quantifiers cs.CF.hprel_rhs in
    let l_hpargs = CF.get_HRels_f lhs in
    let r_hpargs = CF.get_HRels_f rhs in
    if (List.exists (fun (hp,_) -> CP.mem_svl hp post_hps) r_hpargs) &&
      (List.length l_hpargs > 0) then
        let leqs = (MCP.ptr_equations_without_null mix_lf) in
        let lhs_b = match lhs with
          | CF.Base fb -> fb
          | _ -> report_error no_pos "sa2.split_constr: lhs should be a Base Formula"
        in
        let rhs_b = match rhs with
          | CF.Base fb -> fb
          | _ -> report_error no_pos "sa2.split_constr: lhs should be a Base Formula"
        in
        (**smart subst**)
        let lhs_b1, rhs_b1, subst_prog_vars = SAU.smart_subst lhs_b rhs_b (l_hpargs@r_hpargs)
          leqs [] [] prog_vars
        in
        (* let lfb = match lhs_b1 with *)
        (*   | CF.Base fb -> fb *)
        (*   | _ -> report_error no_pos "sa2.split_constr: lhs should be a Base Formula" *)
        (* in *)
        let lfb = lhs_b1 in
        let lhds, lhvs, lhrs = CF.get_hp_rel_bformula lfb in
        let (_ ,mix_lf,_,_,_) = CF.split_components (CF.Base lfb) in
        let leqNulls = MCP.get_null_ptrs mix_lf in
        let leqs = (MCP.ptr_equations_without_null mix_lf) in
        let ls_rhp_args = CF.get_HRels_f (CF.Base rhs_b1) in
        let r_hps = List.map fst ls_rhp_args in
        let l_def_vs = leqNulls @ (List.map (fun hd -> hd.CF.h_formula_data_node) lhds)
          @ (List.map (fun hv -> hv.CF.h_formula_view_node) lhvs) in
        let l_def_vs = CP.remove_dups_svl (CF.find_close l_def_vs (leqs)) in
        let helper (hp,eargs,_)=(hp,List.concat (List.map CP.afv eargs)) in
        let ls_lhp_args = (List.map helper lhrs) in
        (*generate linking*)
        let unk_svl, lfb1, unk_map1 = ([], lfb, total_unk_map)
          (* let unk_svl, unk_xpure, unk_map1 = SAC.generate_map ls_lhp_args ls_rhp_args total_unk_map no_pos in *)
          (* let lfb1 = CF.mkAnd_base_pure lfb (MCP.mix_of_pure unk_xpure) no_pos in *)
          (* ([], lfb1, unk_map1) *)
        in
        let unk_svl1 = CP.remove_dups_svl (cs.CF.unk_svl@unk_svl) in
        (*do not split unk_hps and link_hps, all non-ptrs args*)
        let non_split_hps = unk_hps @ link_hps in
        let ls_lhp_args1, ls_lhs_non_node_hpargs = List.fold_left (fun (r1,r2) (hp,args) ->
            let arg_i,_ = SAU.partition_hp_args prog hp args in
            if ((List.filter (fun (sv,_) -> CP.is_node_typ sv) arg_i) = []) then
              (r1, r2@[(hp,args)])
            else if not (CP.mem_svl hp non_split_hps) then
              (r1@[(hp,args)],r2)
            else (r1,r2)
        ) ([],[]) ls_lhp_args in
        (* let _ = Debug.info_pprint ("  ls_lhp_args1: " ^ *)
        (* (let pr1 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in pr1 ls_lhp_args1)) no_pos in *)
        (* let _ = Debug.info_pprint ("  ls_lhs_non_node_hpargs: " ^ *)
        (* (let pr1 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in pr1 ls_lhs_non_node_hpargs)) no_pos in *)
        let lfb2, defined_preds,rems_hpargs,link_hps =
          List.fold_left (fun (lfb, r_defined_preds, r_rems, r_link_hps) hpargs ->
              let n_lfb,def_hps, rem_hps, ls_link_hps=
                SAU.find_well_defined_hp (* split_base *) prog lhds lhvs r_hps
                    prog_vars post_hps hpargs (l_def_vs@unk_svl1) lfb true no_pos
              in
              (n_lfb, r_defined_preds@def_hps, r_rems@rem_hps, r_link_hps@(snd (List.split ls_link_hps)))
          ) (lfb1, [], [], []) ls_lhp_args1
        in
        (* let defined_preds = List.concat ls_defined_hps in *)
        (* let _ = if defined_preds!=[] then step_change # i else () in *)
        let rf = CF.mkTrue (CF.mkTrueFlow()) no_pos in
        let defined_preds0 = List.fold_left (fun (defined_preds) hpargs ->
            let def_hps, _ = (SAU.find_well_eq_defined_hp prog lhds lhvs lfb2 leqs hpargs) in
            (defined_preds@(List.map (fun (a,b,c) -> (a,b,c,rf)) def_hps))
        ) (defined_preds) (rems_hpargs@ls_lhs_non_node_hpargs) in
        let new_cs = {cs with CF.hprel_lhs = CF.add_quantifiers l_qvars (CF.Base lfb2);
            CF.unk_svl = unk_svl1;
            CF.hprel_rhs = (CF.add_quantifiers r_qvars (CF.Base rhs_b1));
        } in
        let new_constrs = match defined_preds0 with
          | [] -> [new_cs]
          | _ ->
                let _ = Debug.ninfo_pprint (Cprinter.string_of_hprel_short cs) no_pos in
                let _ = Debug.ninfo_pprint ("  unused ptrs: " ^ (!CP.print_svl unk_svl)) no_pos in
                (*prune defined hps in lhs*)
                let new_lhs, _ = CF.drop_hrel_f new_cs.CF.hprel_lhs (List.map (fun (a, _, _,_) -> a) defined_preds0) in
                let new_lhs1 = CF.add_quantifiers l_qvars new_lhs in
                let new_lhs2 = CF.elim_unused_pure new_lhs1 new_cs.CF.hprel_rhs in
                let new_cs = {new_cs with CF.hprel_lhs = new_lhs2;} in
                let _ = Debug.ninfo_pprint ("  refined cs: " ^ (Cprinter.string_of_hprel_short new_cs)) no_pos in
                (* let rf = CF.mkTrue (CF.mkTrueFlow()) no_pos in *)
                let _ = Debug.ninfo_pprint ("  generate pre-preds-based constraints: " ) no_pos in
                let defined_hprels = List.map (SAU.generate_hp_ass 2 unk_svl1 cond_path) defined_preds0 in
                new_cs::defined_hprels
        in
        (new_constrs, unk_map1, link_hps)
    else
      (*do subst: sa/demo/mcf-3a1.slk*)
      let leqs = (MCP.ptr_equations_without_null mix_lf) in
      let lhs_b = match lhs with
        | CF.Base fb -> fb
        | _ -> report_error no_pos "sa2.split_constr: lhs should be a Base Formula"
      in
      let rhs_b = match rhs with
        | CF.Base fb -> fb
        | _ -> report_error no_pos "sa2.split_constr: lhs should be a Base Formula"
      in
      (*smart subst*)
      let lhs_b1, rhs_b1, _ = SAU.smart_subst lhs_b rhs_b (l_hpargs@r_hpargs)
        leqs [] [] prog_vars
      in
      let n_cs = {cs with CF.hprel_lhs = (CF.Base lhs_b1);
          CF.hprel_rhs = (CF.Base rhs_b1);
      } in
      ([n_cs],total_unk_map,[])
  in
  let split_one cs total_unk_map =
    (* let pr1 = Cprinter.string_of_hprel_short in *)
    (* let pr2 = (pr_list (pr_pair (pr_pair !CP.print_sv (pr_list string_of_int)) CP.string_of_xpure_view)) in *)
    let res = split_one cs total_unk_map in
    let (new_cs,new_umap,link_hpargs) = res in
    if (List.length new_cs > 1) then
      begin
        step_change # inc;
        (* Debug.binfo_start "split_base"; *)
        (* Debug.binfo_hprint (add_str "BEFORE" pr1) cs no_pos; *)
        (* Debug.binfo_pprint "=============>>>>" no_pos; *)
        (* Debug.binfo_hprint (add_str "AFTER" (pr_list_ln pr1)) new_cs no_pos; *)
        (* Debug.binfo_end "split_base"; *)
        res
      end
    else res
  in
  let split_one cs total_unk_map =
    let pr1 = Cprinter.string_of_hprel in
    let pr2 = (pr_list (pr_pair (pr_pair !CP.print_sv (pr_list string_of_int)) CP.string_of_xpure_view)) in
    let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in
    Debug.no_2 "split_one" pr1 pr2 (pr_triple (pr_list_ln pr1) pr2 pr3) split_one cs total_unk_map 
    in
  let new_constrs, new_map, link_hpargs = List.fold_left (fun (r_constrs,unk_map, r_link_hpargs) cs ->
      let new_constrs, new_map, new_link_hpargs = split_one cs unk_map in
      (r_constrs@new_constrs, new_map, r_link_hpargs@new_link_hpargs)
  ) ([], unk_map, []) constrs
  in
  (new_constrs, new_map, link_hpargs)

let split_base_constr prog cond_path constrs post_hps prog_vars unk_map unk_hps link_hps=
      let _ = step_change # reset in
      let s1 = (pr_list_num Cprinter.string_of_hprel_short) constrs in
      let (constrs2, unk_map2, link_hpargs2) as res = split_base_constr prog cond_path constrs post_hps prog_vars unk_map unk_hps link_hps in
      let s2 = (pr_list_num Cprinter.string_of_hprel_short) constrs2 in
      if step_change # no_change then 
        DD.binfo_pprint "*** NO SPLITTING DONE ***" no_pos
      else 
        begin
          let _ = DD.binfo_start "split_base" in
          let _ = DD.binfo_hprint (add_str "post_hps" Cprinter.string_of_spec_var_list) post_hps no_pos in
          let _ = DD.binfo_hprint (add_str "prog_vars" Cprinter.string_of_spec_var_list) prog_vars no_pos in
          let _ = DD.binfo_hprint (add_str "BEFORE" pr_id) s1 no_pos in
          let _ = DD.binfo_pprint "=============>>>>" no_pos in
          let _ = DD.binfo_hprint (add_str "AFTER" pr_id) s2 no_pos in
          let _ = DD.binfo_hprint (add_str "UNKNOWN added" (pr_list (fun (x,_) -> Cprinter.string_of_spec_var x)))  link_hpargs2 no_pos in
          let _ = DD.binfo_end "split_base" in
          ()
        end;
      res


let split_base_constr prog cond_path constrs post_hps prog_vars unk_map unk_hps link_hps=
  let pr1 = pr_list_ln Cprinter.string_of_hprel_short in
  (* let pr2 = (pr_list (pr_pair (pr_list (pr_pair !CP.print_sv string_of_int)) CP.string_of_xpure_view)) in *)
  let pr2 = (pr_list (pr_pair (pr_pair !CP.print_sv (pr_list string_of_int)) CP.string_of_xpure_view)) in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in
  Debug.no_4 "split_base_constr" pr1 pr2 !CP.print_svl !CP.print_svl (pr_triple pr1 pr2 pr3)
      (fun _ _ _ _ -> split_base_constr prog cond_path constrs post_hps prog_vars unk_map
          unk_hps link_hps) constrs unk_map unk_hps post_hps

(***************************************************************
                      PARTIAL DEFS
****************************************************************)
let mk_pdef hp_sv args unk_svl imp_cond olhs og orhs=
  (hp_sv, args,  unk_svl, imp_cond, olhs , og, orhs)

let cmp_formula_opt args of1 of2=
  match of1,of2 with
    | Some f1, Some f2 ->
          SAU.check_relaxeq_formula args f1 f2
    | None, None -> true
    | _ -> false

(*assume hp1 = hp2*)
let cmp_pdef_grp (hp1,args1,unk_svl1, cond1, olhs1,og1, orhs1) (hp2,args2,unk_svl2, cond2, olhs2, og2, orhs2)=
  (CP.equalFormula cond1 cond2) && (cmp_formula_opt args1 orhs1 orhs2)

let get_par_defs_post constrs0 =
  let mk_par_def cs=
    let hp, args = CF.extract_HRel_f cs.CF.hprel_rhs in
    mk_pdef hp args cs.CF.unk_svl (CP.mkTrue no_pos) (Some cs.CF.hprel_lhs) None None
  in
  List.map mk_par_def constrs0

let get_par_defs_pre constrs0 =
  let mk_par_def cs=
    (* let _ = print_endline ("cs.CF.hprel_lhs: " ^ ( !CF.print_formula cs.CF.hprel_lhs)) in *)
    let op_res = CF.extract_hprel_pure cs.CF.hprel_lhs in
    match op_res with
      | Some (hp, args,p) ->
          (* let _ = print_endline ("p: " ^ ( !CP.print_formula p)) in *)
          ([(mk_pdef hp args cs.CF.unk_svl (CP.remove_redundant p) None cs.CF.hprel_guard (Some cs.CF.hprel_rhs), cs)], [])
      | None -> ([], [cs])
  in
  List.fold_left (fun (pdefs,rem_cs) cs ->
      let ls1, ls2 = mk_par_def cs in
      (pdefs@ls1, rem_cs@ls2)
  )
      ([], []) constrs0
      (*remove_dups*)

let combine_pdefs_pre_x prog unk_hps link_hps pr_pdefs=
  (*Now unk_hps (dangling) is similar to link_hps (unknown).
    in future, it may different. Thus, we keep both, now.
  *)
  let link_hps = unk_hps@link_hps in
  let rec partition_pdefs_by_hp_name pdefs parts=
    match pdefs with
      | [] -> parts
      | ((a1,a2,a3,a4,a5,a5g,a6),cs)::xs ->
          let part,remains= List.partition (fun ((hp_name,_,_,_,_,_,_),_) ->
              CP.eq_spec_var a1 hp_name) xs in
          partition_pdefs_by_hp_name remains (parts@[[((a1,a2,a3,a4,a5,a5g,a6),cs)]@part])
  in
  let do_combine (hp,args,unk_svl, cond, lhs,og, orhs)=
    match orhs with
      | Some rhs ->
            let n_cond = CP.remove_redundant cond in
            let nf = (CF.mkAnd_pure rhs (MCP.mix_of_pure n_cond) (CF.pos_of_formula rhs)) in
            if SAU.is_unsat nf then [] else
            [(hp,args,unk_svl, n_cond, lhs, og, Some (CF.simplify_pure_f nf))]
      | None -> report_error no_pos "sa2.combine_pdefs_pre: should not None 1"
  in
  let mkAnd_w_opt args (* ss *) of1 of2=
    match of1,of2 with
      | Some f1, Some f2 ->
            let pos = CF.pos_of_formula f1 in
            let new_f2 = (*CF.subst ss*) f2 in
            let f = SAU.mkConjH_and_norm prog args unk_hps [] f1 new_f2 pos in
            (* let f = (CF.mkConj_combine f1 new_f2 CF.Flow_combine no_pos) in *)
        if CF.isAnyConstFalse f || SAU.is_unsat f then
          false, Some f
        else true, Some f
      | None, None -> true, None
      | None, Some f2 -> true, (Some ( (*CF.subst ss*) f2))
      | Some f1, None -> true, of1
  in
  (*nav code. to improve*)
  let combine_helper2_x (hp1,args1,unk_svl1, cond1, olhs1,og1, orhs1) (hp2,args2,unk_svl2, cond2, olhs2,og2, orhs2)=
    let cond_disj1 = CP.mkAnd cond1 (CP.mkNot (CP.remove_redundant cond2) None no_pos) no_pos in
    let pdef1 = if (TP.is_sat_raw (MCP.mix_of_pure cond_disj1)) then
      (* let _ = DD.info_pprint ("      cond_disj1: " ^ (!CP.print_formula  cond_disj1) ) no_pos in *)
      let cond21 = CF.remove_neqNull_redundant_andNOT_opt orhs1 cond2 in
      let n_cond = CP.mkAnd cond1 (CP.mkNot cond21 None no_pos) no_pos in
      let npdef1 = do_combine (hp1,args1,unk_svl1, CP.remove_redundant n_cond , olhs1,og1, orhs1) in
      npdef1
    else []
    in
    let cond_disj2 = CP.mkAnd cond2 (CP.mkNot cond1 None no_pos) no_pos in
    let pdef2 = if (TP.is_sat_raw (MCP.mix_of_pure cond_disj2)) then
      (* let _ = DD.info_pprint ("      cond_disj2: " ^ (!CP.print_formula  cond_disj2) ) no_pos in *)
      let cond11 = CF.remove_neqNull_redundant_andNOT_opt orhs2 cond1 in
      let n_cond = (CP.mkAnd cond2 (CP.mkNot cond11 None no_pos) no_pos) in
      let npdef2 = do_combine (hp2,args2,unk_svl2, CP.remove_redundant n_cond, olhs2,og2, orhs2) in
      npdef2
    else []
    in
    let cond_disj3 = CP.mkAnd cond2 cond1 no_pos in
    (* let _ = DD.info_pprint ("      cond_disj3: " ^ (!CP.print_formula  cond_disj3) ) no_pos in *)
    let pdef3 = if (TP.is_sat_raw (MCP.mix_of_pure cond_disj3)) then
      let n_cond = CP.remove_redundant (CP.mkAnd cond1 cond2 no_pos) in
      let is_sat1, n_orhs = mkAnd_w_opt args1 orhs1 orhs2 in
      let is_sat2, n_olhs = mkAnd_w_opt args1 olhs1 olhs2 in
      let npdef3 = if is_sat1 && is_sat2 then
        do_combine (hp1,args1,unk_svl1, n_cond, n_olhs,og1, n_orhs)
      else [(hp1,args1,unk_svl1,  n_cond, olhs1, og1, Some (CF.mkFalse_nf no_pos))]
      in
      npdef3
    else []
    in
    pdef1@pdef2@pdef3
  in
  let combine_helper2 pdef1 pdef2=
    let pr1 = !CP.print_svl in
    let pr2 = !CP.print_formula in
    let pr3 oform= match oform with
      | None -> "None"
      | Some f -> Cprinter.prtt_string_of_formula f
    in
    let pr3a oform= match oform with
      | None -> "None"
      | Some hf -> Cprinter.prtt_string_of_h_formula hf
    in
    let pr4 = pr_hepta !CP.print_sv pr1 pr1 pr2 pr3 pr3a pr3 in
    Debug.no_2 " combine_helper2" pr4 pr4 (pr_list_ln pr4)
        (fun _ _ -> combine_helper2_x pdef1 pdef2)
        pdef1 pdef2
  in
  (* let rec combine_helper_list rem res= *)
  (*   match rem with *)
  (*     | [] -> res *)
  (*     | pdef::rest -> *)
  (*           let n = List.fold_left (fun res_pdefs pdef1 -> *)
  (*               res_pdefs@(combine_helper2 pdef pdef1) *)
  (*           ) [] rest in *)
  (*            combine_helper_list rest (res@n) *)
  (* in *)
  let filter_trivial_pardef (res_pr, res_depen_cs) ((hp,args,unk_svl, cond, olhs,og, orhs), cs) =
     match orhs with
       | Some rhs -> let b = CP.isConstTrue cond && SAU.is_empty_f rhs in
                     if not b then
                       (res_pr@[((hp,args,unk_svl, cond, olhs, og, orhs), cs)], res_depen_cs)
                     else (res_pr, res_depen_cs@[cs])
       | None -> report_error no_pos "sa2.combine_pdefs_pre: should not None 2"
  in
  let obtain_and_norm_def_x args0 ((hp,args,unk_svl, cond, olhs, og, orhs), cs)=
    (*normalize args*)
    let subst = List.combine args args0 in
    let cond1 = (CP.subst subst cond) in
    let norhs, cond1 = match orhs with
      | Some f -> let nf = (CF.subst subst f) in
        let cond2 =
          (* if SAU.is_empty_heap_f nf then *)
          (*   CP.mkAnd cond1 (CF.get_pure nf) (CP.pos_of_formula cond1) *)
          (* else cond1 *)
          cond1
        in
        (Some (CF.mkAnd_pure nf (MCP.mix_of_pure cond2) (CF.pos_of_formula nf)), cond2)
      | None -> None, cond1
    in
    let nolhs = match olhs with
      | None -> None
      | Some f -> Some (CF.subst subst f)
    in
    let nog = match og with
      | None -> None
      | Some f -> Some (CF.h_subst subst f)
    in
    ((hp,args0,CP.subst_var_list subst unk_svl, cond1, nolhs,nog, norhs), (*TODO: subst*)cs)
  in
  let obtain_and_norm_def args0 ((hp,args,unk_svl, cond, olhs, og, orhs), cs)=
    let pr1 = !CP.print_svl in
    let pr2 = !CP.print_formula in
    let pr3 oform= match oform with
      | None -> "None"
      | Some f -> Cprinter.prtt_string_of_formula f
    in
    let pr3a oform= match oform with
      | None -> "None"
      | Some f -> Cprinter.prtt_string_of_h_formula f
    in
    let pr4 = pr_hepta !CP.print_sv pr1 pr1 pr2 pr3 pr3a pr3 in
    let pr5 (a,_) = pr4 a in
    Debug.no_2 "obtain_and_norm_def" pr1 pr4 pr5
        (fun _ _ -> obtain_and_norm_def_x args0 ((hp,args,unk_svl, cond, olhs,og, orhs), cs))
        args0 (hp,args,unk_svl, cond, olhs,og, orhs)
  in
  let combine_grp pr_pdefs equivs=
    match pr_pdefs with
      | [] -> ([],[], equivs)
      | [(hp,args,unk_svl, cond, lhs, og, orhs), _] ->
          let new_pdef = do_combine (hp,args,unk_svl, cond, lhs,og, orhs) in
          (new_pdef,[], equivs)
      | _ -> begin
          (*each group, filter depended constraints*)
          let rem_pr_defs, depend_cs = List.fold_left filter_trivial_pardef ([],[]) pr_pdefs in
          (* let rem_pr_defs = pr_pdefs in *)
          (* let depend_cs = [] in *)
          (*do norm args first, apply for cond only, other parts will be done later*)
          let cs,rem_pr_defs1 , n_equivs=
            match rem_pr_defs with
              | [] -> [],[],equivs
              | [x] -> [x],[],equivs
              | ((hp,args0,unk_svl0, cond0, olhs0, og0, orhs0),cs0)::rest ->
                    (* let pr_pdef0 = obtain_and_norm_def args0 ((hp,args0,unk_svl0, cond0, olhs0, orhs0),cs0) in *)
                    let pdefs = List.map (obtain_and_norm_def args0) rem_pr_defs in
                    (* let pdefs = pr_pdef0::new_rest in *)
                    let pdefs1 = Gen.BList.remove_dups_eq (fun (pdef1,_) (pdef2,_) -> cmp_pdef_grp pdef1 pdef2) pdefs in
                    let pdefs2,n_equivs = SAC.unify_consj_pre prog unk_hps link_hps equivs pdefs1 in
                    ([], pdefs2,n_equivs)
          in
          let pdefs,rem_constrs0 = begin
            match cs,rem_pr_defs1 with
              | [],[] -> [],[]
              | [((hp,args,unk_svl, cond, lhs,og, orhs), _)],[] -> (do_combine (hp, args, unk_svl, cond, lhs,og, orhs)),[]
              | [],[(pr1,_);(pr2,_)] -> let npdefs = combine_helper2 pr1 pr2 in
                npdefs,[]
              | _ ->
                    (* let pdefs, rem_constrs = *)
                    (*   combine_helper rem_pr_defs1 [] [] [] in *)
                    (* (pdefs,rem_constrs) *)
                    let fst_ls = List.map fst rem_pr_defs1 in
                    let pdefs = (* combine_helper_list fst_ls [] *)
                      List.fold_left (fun res_pdefs pdef ->
                          let pdefs = res_pdefs@(List.fold_left (fun res pdef1 ->
                            let pdefs = res@(combine_helper2 pdef pdef1) in
                            pdefs
                          ) [] res_pdefs) in
                          let pdefs2 = Gen.BList.remove_dups_eq cmp_pdef_grp pdefs in
                          pdefs2
                      ) [List.hd fst_ls] (List.tl fst_ls)
                    in
                    (pdefs,[])
          end
          in
          (pdefs, depend_cs@rem_constrs0, n_equivs)
      end
  in
  let subst_equiv equivs ((hp,args1,unk_svl1, cond1, olhs1,og1, orhs1) as pdef)=
    match orhs1 with
      | None -> pdef
      | Some f ->
            let rele_equivs = List.fold_left (fun ls (hp1,hp2) ->
                if CP.eq_spec_var hp1 hp then (ls@[hp2]) else ls)
              [] equivs
            in
            let from_hps = CP.remove_dups_svl rele_equivs in
            let nf = CF.subst_hprel f from_hps hp in
            (hp,args1,unk_svl1, cond1, olhs1,og1, Some nf)
  in
  (*group*)
  let ls_pr_pdefs = partition_pdefs_by_hp_name pr_pdefs [] in
  (*combine rhs with condition for each group*)
  let pdefs, rem_constr,equivs = List.fold_left (fun (r_pdefs, r_constrs, equivs) grp ->
      let pdefs, cs, new_equivs = combine_grp grp equivs in
      (r_pdefs@pdefs, r_constrs@cs, new_equivs)
  ) ([],[],[]) ls_pr_pdefs
  in
  let pdefs1 = (* List.map (fun (a,b,c,d,e,f,g) -> (a,b,c,d,f,g)) *) pdefs in
  (*subst equivs*)
  let pdefs2 = List.map (subst_equiv equivs) pdefs1 in
  (pdefs2,rem_constr,equivs)
(*retain depended constraints*)

let combine_pdefs_pre prog unk_hps link_hps pr_pdefs=
  let pr1= pr_list_ln Cprinter.string_of_hprel_short in
  let pr2 = SAU.string_of_par_def_w_name in
  let pr3 (pdef, _) = pr2 pdef in
  let pr4 = pr_list (pr_pair !CP.print_sv !CP.print_sv) in
  Debug.no_3 "combine_pdefs_pre" (pr_list_ln pr3) !CP.print_svl !CP.print_svl
      (pr_triple (pr_list_ln pr2) pr1 pr4)
      (fun _ _ _ -> combine_pdefs_pre_x prog unk_hps link_hps pr_pdefs)
      pr_pdefs unk_hps link_hps
(***************************************************************
                      END PARTIAL DEFS
****************************************************************)

(***************************************************************
                      GENERALIZATION
****************************************************************)
(*remove neqNUll redundant*)
let remove_neqNull_helper (hp,args,f,unk_svl)=
  let f1 = CF.remove_neqNulls_f f in
  if SAU.is_empty_f f1 then [] else [(hp,args,f1,unk_svl)]

let remove_neqNull_grp_helper grp=
    List.fold_left (fun r pdef-> let new_pdef = remove_neqNull_helper pdef in
                                 r@new_pdef) [] grp

let get_null_quans f=
  let qvars, base_f = CF.split_quantifiers f in
   let (_ ,mix_lf,_,_,_) = CF.split_components base_f in
   let eqNulls = MCP.get_null_ptrs mix_lf in
   (CP.intersect_svl eqNulls qvars, base_f)

(*for par_defs*)
let generalize_one_hp_x prog is_pre (hpdefs: (CP.spec_var *CF.hp_rel_def) list) non_ptr_unk_hps unk_hps link_hps par_defs=
  let skip_hps = unk_hps@link_hps in
  (*collect definition for each partial definition*)
  let obtain_and_norm_def hp args0 quan_null_svl0 (a1,args,og,f,unk_args)=
    (*normalize args*)
    let subst = List.combine args args0 in
    let f1 = (CF.subst subst f) in
    (* let f2 = *)
    (*   if !Globals.sa_dangling then *)
    (*     CF.annotate_dl f1 (List.filter (fun hp1 -> not (CP.eq_spec_var hp hp1)) unk_hps) *)
    (*     (\* fst (CF.drop_hrel_f f1 unk_hps) *\) *)
    (*   else f1 *)
    (* in *)
    let f2 = (* CF.split_quantifiers *) f1 in
    let quan_null_svl, base_f2 = get_null_quans f2 in
    let f3=
      if List.length quan_null_svl = List.length quan_null_svl0 then
        let ss = List.combine quan_null_svl quan_null_svl0 in
        CF.add_quantifiers quan_null_svl0 (CF.subst ss base_f2)
      else f2
    in
    let unk_args1 = List.map (CP.subs_one subst) unk_args in
    (* (\*root = p && p:: node<_,_> ==> root = p& root::node<_,_> & *\) *)
    (f3,SAU.h_subst_opt subst og, unk_args1)
  in
  DD.tinfo_pprint ">>>>>> generalize_one_hp: <<<<<<" no_pos;
  if par_defs = [] then ([],[]) else
    begin
        let hp, args, _, f0,_ = (List.hd par_defs) in
        let _ = Debug.info_pprint ("    synthesize: " ^ (!CP.print_sv hp) ) no_pos in
        let hpdefs,subst_useless=
          if CP.mem_svl hp skip_hps then
            let fs = List.map (fun (a1,args,og,f,unk_args) -> fst (CF.drop_hrel_f f [hp]) ) par_defs in
            let fs1 = Gen.BList.remove_dups_eq (fun f1 f2 -> SAU.check_relaxeq_formula args f1 f2) fs in
            (SAU.mk_unk_hprel_def hp args fs1 no_pos,[])
          else
            (*find the root: ins2,ins3: root is the second, not the first*)
            let args0 = List.map (CP.fresh_spec_var) args in
            (* DD.ninfo_pprint ((!CP.print_sv hp)^"(" ^(!CP.print_svl args) ^ ")") no_pos; *)
            let quan_null_svl,_ = get_null_quans f0 in
            let quan_null_svl0 = List.map (CP.fresh_spec_var) quan_null_svl in
            let defs,ogs, ls_unk_args = split3 (List.map (obtain_and_norm_def hp args0 quan_null_svl0) par_defs) in
            let r,non_r_args = SAU.find_root prog skip_hps args0 defs in
            (*make explicit root*)
            let defs0 = List.map (SAU.mk_expl_root r) defs in
            let unk_svl = CP.remove_dups_svl (List.concat (ls_unk_args)) in
            (*normalize linked ptrs*)
            let defs1 = SAU.norm_hnodes args0 defs0 in
            (*remove unkhp of non-node*)
            let defs2 = if is_pre then (* List.map remove_non_ptr_unk_hp *) defs1
            else SAU.elim_useless_rec_preds prog hp args0 defs1
            in
            (*remove duplicate*)
            let defs3 = SAU.equiv_unify args0 defs2 in
            let defs4 = SAU.remove_equiv_wo_unkhps hp skip_hps defs3 in
            let defs5a = SAU.find_closure_eq hp args0 defs4 in
            (*Perform Conjunctive Unification (without loss) for post-preds. pre-preds are performed separately*)
            let defs5 =  if is_pre then defs5a else
              SAU.perform_conj_unify_post prog args0 (unk_hps@link_hps) unk_svl defs5a no_pos
            in
            let pr1 = pr_list_ln Cprinter.prtt_string_of_formula in
            let _ = DD.ninfo_pprint ("defs1: " ^ (pr1 defs1)) no_pos in
            (*remove duplicate with self-recursive*)
            (* let base_case_exist,defs4 = SAU.remove_dups_recursive hp args0 unk_hps defs3 in *)
            (*find longest hnodes common for more than 2 formulas*)
            (*each hds of hdss is def of a next_root*)
            (* let defs5 = List.filter (fun f -> have_roots args0 f) defs4 in *)
            let old_disj = !Globals.pred_disj_unify in
            let disj_opt = !Globals.pred_elim_useless || !Globals.pred_disj_unify in
            let defs,elim_ss = if disj_opt then
              SAU.get_longest_common_hnodes_list prog is_pre hpdefs (skip_hps) unk_svl hp r non_r_args args0 defs5 ogs
            else
              let defs = SAU.mk_hprel_def prog is_pre hpdefs skip_hps unk_svl hp (args0,r,non_r_args) defs5 ogs no_pos in
              (defs,[])
            in
            let _ = Globals.pred_disj_unify := old_disj in
            if defs <> [] then
              (defs,elim_ss)
            else
              (* report_error no_pos "shape analysis: FAIL" *)
              let body = if is_pre then
                CF.mkHTrue_nf no_pos
              else
                  CF.mkFalse_nf no_pos
              in
              let def = (CP.HPRelDefn (hp, r, non_r_args), (CF.HRel (hp, List.map (fun x -> CP.mkVar x no_pos) args0, no_pos)), None, body) in
              ([(hp, def)],[])
        in
        (********PRINTING***********)
        let _ = List.iter (fun (_, def) ->
            Debug.info_pprint ((Cprinter.string_of_hp_rel_def_short def)) no_pos)
          hpdefs
        in
        (********END PRINTING***********)
        (hpdefs, subst_useless)
    end

let generalize_one_hp prog is_pre (defs:(CP.spec_var *CF.hp_rel_def) list) non_ptr_unk_hps unk_hps link_hps par_defs=
  let pr1 = pr_list_ln SAU.string_of_par_def_w_name_short in
  let pr2 = pr_list_ln (pr_pair !CP.print_sv Cprinter.string_of_hp_rel_def) in
  let pr3 = pr_list (pr_pair Cprinter.prtt_string_of_h_formula Cprinter.prtt_string_of_h_formula) in
  Debug.no_2 "generalize_one_hp" pr1 !CP.print_svl (pr_pair pr2 pr3)
      (fun _ _ -> generalize_one_hp_x prog is_pre defs non_ptr_unk_hps
          unk_hps link_hps par_defs) par_defs unk_hps

let get_pdef_body_x unk_hps post_hps (a1,args,unk_args,a3,olf,og, orf)=
  let exchane_unk_post hp1 args f unk_args=
    let hpargs2 = CF.get_HRels_f f in
    match hpargs2 with
      | [(hp2,args2)] ->
          if CP.mem_svl hp2 unk_hps && (CP.mem_svl hp2 post_hps) &&
            SAU.eq_spec_var_order_list args args2 then
            let new_f = SAU.mkHRel_f hp1 args (CF.pos_of_formula f) in
            [(hp2,args,og,new_f,unk_args)]
          else [(hp1,args,og,f,unk_args)]
      | _ -> [(hp1,args,og,f,unk_args)]
  in
  match olf,orf with
    | Some f, None -> [(a1,args,og,f,unk_args)]
    | None, Some f -> if CP.mem_svl a1 unk_hps && not (CP.mem_svl a1 post_hps) then
          exchane_unk_post a1 args f unk_args
        else
          [(a1,args,og,f,unk_args)]
    | Some f1, Some f2 ->
        let f_body=
          let hps1 = CF.get_hp_rel_name_formula f1 in
          let hps2 = CF.get_hp_rel_name_formula f2 in
          if CP.intersect_svl hps1 hps2 <> [] then
            (*recurive case*)
            if CF.is_HRel_f f1 then f2 else f1
          else SAU.compose_subs f2 f1 (CF.pos_of_formula f2)
        in
        if SAU.is_trivial f_body (a1,args) then [] else
          [(a1,args,og,f_body,unk_args)]
    | None, None -> report_error no_pos "sa.obtain_def: can't happen 2"

let get_pdef_body unk_hps post_hps (a1,args,unk_args,a3,olf,og,orf)=
  let pr1 = SAU.string_of_par_def_w_name in
  let pr1a og = match og with
    | None -> ""
    | Some hf -> Cprinter.prtt_string_of_h_formula hf
  in
  let pr2 = pr_list (pr_penta !CP.print_sv !CP.print_svl pr1a Cprinter.prtt_string_of_formula !CP.print_svl) in
  Debug.no_1 "get_pdef_body" pr1 pr2
      (fun _ -> get_pdef_body_x unk_hps post_hps (a1,args,unk_args,a3,olf,og,orf) )(a1,args,unk_args,a3,olf,og,orf)

(*=========SUBST DEF and PARDEF FIX==========*)
(*
  divide hp into three groups:
  - independent - ready for genalizing
  - dependent:
      - depend on non-recursive groups: susbst
      - depend on recusive groups: wait
*)
let pardef_subst_fix_x prog unk_hps groups=
  (* let get_hp_from_grp grp= *)
  (*   match grp with *)
  (*     | (hp,_,_,_)::_ -> hp *)
  (*     | [] -> report_error no_pos "sa.pardef_subst_fix_x: 1" *)
  (* in *)
  let is_rec_pardef (hp,_,_,f,_)=
    let hps = CF.get_hp_rel_name_formula f in
    (CP.mem_svl hp hps)
  in
  let is_independ_pardef (hp,_,_,f,_) =
    let hps = CF.get_hp_rel_name_formula f in
    let hps = CP.remove_dups_svl hps in
    (* DD.ninfo_pprint ("       rec hp: " ^ (!CP.print_sv hp)) no_pos; *)
    let dep_hps = List.filter (fun hp1 -> not ((CP.eq_spec_var hp hp1) (* || *)
    (* (CP.mem_svl hp1 unk_hps) *))) hps in
    (* DD.ninfo_pprint ("       rec rems: " ^ (!CP.print_svl rems)) no_pos; *)
    (dep_hps = [])
  in
  let is_rec_group grp=
    List.exists is_rec_pardef grp
  in
  let is_independ_group grp =
    List.for_all is_independ_pardef grp
  in
  (* let get_succ_hps_pardef (_,_,f,_)= *)
  (*   (CF.get_HRels_f f) *)
  (* in *)
  let process_dep_group grp rec_hps nrec_grps=
    (*not depends on any recursive hps, susbt it*)
    let ters,fss = List.split (List.map (SAU.succ_subst prog nrec_grps unk_hps false) grp) in
    (*check all is false*)
    (* let pr = pr_list string_of_bool in *)
    (* DD.ninfo_pprint ("       bool: " ^ (pr ters)) no_pos; *)
    let new_grp_ls = List.concat fss in
    let ter = List.for_all (fun b -> not b) ters in
    (not ter, new_grp_ls)
  in
  let subst_dep_groups_x deps rec_hps nrec_grps=
    (*local_helper deps []*)
    let bs, new_deps = List.split (List.map (fun grp -> process_dep_group grp rec_hps nrec_grps) deps) in
    let new_deps1 = List.filter (fun l -> List.length l > 0) new_deps in
    (List.fold_left (fun b1 b2 -> b1 || b2) false bs, new_deps1)
  in
  (*for debugging*)
  let subst_dep_groups deps rec_hps nrec_grps=
    let pr0 = (pr_list_ln SAU.string_of_par_def_w_name_short) in
    let pr1 =  pr_list_ln pr0 in
    let pr2 = pr_pair string_of_bool pr1 in
    Debug.no_2 "subst_dep_groups" pr1 pr1 pr2
        (fun _ _ -> subst_dep_groups_x deps rec_hps nrec_grps) deps nrec_grps
  in
  (*END for debugging*)
  (*sort order of nrec_grps to subst*)
  let topo_sort_x dep_grps nrec_grps=
    (*get name of n_rec_hps, intial its number with 0*)
    let ini_order_from_grp grp=
      let (hp,_,_,_,_) = List.hd grp in
      (grp,hp,0) (*called one topo*)
    in
    let update_order_from_grp updated_hps incr (grp,hp, old_n)=
      if CP.mem_svl hp updated_hps then
        (grp,hp,old_n+incr)
      else (grp,hp,old_n)
    in
  (*each grp, find succ_hp, add number of each succ hp + 1*)
    let process_one_dep_grp topo dep_grp=
      let (hp,_,_,_,_) = List.hd dep_grp in
      let succ_hps = List.concat (List.map (fun (_,_,_,f,_) -> CF.get_hp_rel_name_formula f) dep_grp) in
    (*remove dups*)
      let succ_hps1 = Gen.BList.remove_dups_eq CP.eq_spec_var succ_hps in
    (* DD.ninfo_pprint ("       process_dep_group succ_hps: " ^ (!CP.print_svl succ_hps)) no_pos; *)
    (*remove itself hp and unk_hps*)
      let succ_hps2 = List.filter (fun hp1 -> not (CP.eq_spec_var hp1 hp) &&
          not (CP.mem_svl hp1 unk_hps)) succ_hps1
      in
      List.map (update_order_from_grp succ_hps2 1) topo
    in
    let topo0 = List.map ini_order_from_grp nrec_grps in
    let dep_grps = List.filter (fun grp -> List.length grp > 0) dep_grps in
    let topo1 = List.fold_left process_one_dep_grp topo0 dep_grps in
    (*sort decreasing and return the topo list*)
    let topo2 = List.sort (fun (_,_,n1) (_,_,n2) -> n2-n1) topo1 in
    topo2
  in
  (*for debugging*)
  let topo_sort dep_grps nrec_grps=
    let pr0 = (pr_list_ln SAU.string_of_par_def_w_name_short) in
    let pr1 =  pr_list_ln pr0 in
    let pr2 =  pr_list_ln (pr_triple pr0 !CP.print_sv string_of_int) in
    Debug.no_2 "topo_sort" pr1 pr1 pr2
        (fun _ _ -> topo_sort_x dep_grps nrec_grps) dep_grps nrec_grps
  in
  (*END for debugging*)
  let helper_x grps rec_inds nrec_inds=
    let indeps,deps = List.partition is_independ_group grps in
    (*classify indeps into rec and non_rec*)
    let lrec_inds,lnrec_inds = List.partition is_rec_group indeps in
    (*for return*)
    let res_rec_inds = rec_inds@lrec_inds in
    let res_nrec_inds = nrec_inds@lnrec_inds in
    (* let lrec_deps,l_nrec_deps = comp_rec_grps_fix res_rec_inds  deps in *)
    let lrec_deps,l_nrec_deps = List.partition is_rec_group deps in
    (*find deps on non_recs*)
    let rec_hps = List.map
      (fun grp -> let (hp,_,_,_,_) = List.hd grp in hp)
      (res_rec_inds@lrec_deps)
    in
    (*deps may have mutual rec*)
    let mutrec_term_grps,mutrec_nonterm_grps, deps_0,mutrec_hps = SAU.succ_subst_with_mutrec prog deps unk_hps in
    (*add rec grp*)
    let l_nrec_deps1 = List.filter
      (fun grp -> let (hp,_,_,_,_) = List.hd grp in not(CP.mem_svl hp mutrec_hps))
      l_nrec_deps
    in
    (*topo deps*)
    let deps_1 = mutrec_term_grps@mutrec_nonterm_grps @ deps_0 in
    let topo_nrec_grps = topo_sort deps_1 (res_nrec_inds@l_nrec_deps1) in
    (*remove order number*)
    let topo_nrec_grps1 = List.map (fun (grp,hp,_) -> (grp,hp)) topo_nrec_grps in
    let rec loop_helper deps0 nrec_grps=
      let rec look_up_newer_nrec ls (cur_grp,hp)=
        match ls with
          | [] -> cur_grp
          | dep_grp::gss ->
              begin
                  match dep_grp with
                    | [] ->  look_up_newer_nrec gss (cur_grp,hp)
                    | _ ->
                        let hp1,_,_,_,_ = List.hd dep_grp in
                        if CP.eq_spec_var hp1 hp then dep_grp
                        else look_up_newer_nrec gss (cur_grp,hp)
              end
      in
      match nrec_grps with
        | [] -> deps0
        | (nrec_grp,nrec_hp)::ss ->
            (*find the latest in deps0, if applicable*)
            let nrec_grp1 = look_up_newer_nrec deps0 (nrec_grp,nrec_hp) in
            let _, deps1 = subst_dep_groups deps0 rec_hps [nrec_grp1] in
            loop_helper deps1 ss
    in
    let deps1 = loop_helper deps_1 topo_nrec_grps1
    in
    (* let r, deps1 = subst_dep_groups deps rec_hps (res_nrec_inds@l_nrec_deps) in *)
    (* ((List.length indeps>0 || r), deps1, res_rec_inds,res_nrec_inds) *)
    (*re-classify rec_ndep*)
    let indeps2,deps2 = List.partition is_independ_group deps1 in
    (*classify indeps into rec and non_rec*)
    let rec_inds2, nrec_indeps2 = List.partition is_rec_group indeps2 in
    (false, deps2, res_rec_inds@rec_inds2,res_nrec_inds@nrec_indeps2)
  in
  (*for debugging*)
   let helper grps rec_inds nrec_inds=
     let pr1 = pr_list_ln (pr_list_ln SAU.string_of_par_def_w_name_short) in
     let pr2= pr_quad string_of_bool pr1 pr1 pr1 in
     Debug.no_3 "pardef_subst_fix:helper" pr1 pr1 pr1 pr2
         (fun _ _ _ -> helper_x grps rec_inds nrec_inds) grps rec_inds nrec_inds
   in
  (*END for debugging*)
  let rec helper_fix cur rec_indps nrec_indps=
    let r,new_cur,new_rec_indps,new_nrec_indps = helper cur rec_indps nrec_indps in
    if r then helper_fix new_cur new_rec_indps new_nrec_indps
    else
      (* let pr1 = pr_list_ln (pr_list_ln (pr_quad !CP.print_sv !CP.print_svl Cprinter.prtt_string_of_formula !CP.print_svl)) in *)
      (* let _ = DD.info_pprint ("      new_cur: " ^ (pr1 new_cur)) no_pos in *)
      (*subs new_cur with new_rec_indps (new_nrec_indps is substed already)*)
      let new_cur1 = List.map SAU.remove_dups_pardefs new_cur in
      let new_cur2 = SAU.succ_subst_with_rec_indp prog new_rec_indps unk_hps new_cur1 in
      (new_cur2@new_rec_indps@new_nrec_indps)
  in
  helper_fix groups [] []

(*this subst is for a nice matching between inferred HP
and lib based predicates*)
let pardef_subst_fix prog unk_hps groups=
  let pr1 = pr_list_ln (pr_list_ln SAU.string_of_par_def_w_name_short) in
  Debug.no_1 "pardef_subst_fix" pr1 pr1
      (fun _ -> pardef_subst_fix_x prog unk_hps groups) groups

let is_valid_pardef (_,args,_,_,f,_)=
  let ls_succ_args = snd (List.split (CF.get_HRels_f f)) in
  let succ_args = List.concat ls_succ_args in
  let ptrs = CF.get_ptrs_f f in
  let dups = (CP.intersect_svl ptrs succ_args) in
  let root_arg=
    match args with
      | [] -> report_error no_pos "sa.is_valid_pardef: hp must have at least one arguments"
      | a::_ -> a
  in
  let b1 = not (CP.mem_svl root_arg dups) in
  (b1 (* && (not (check_unsat f)) *))

let rec partition_pdefs_by_hp_name pdefs parts=
  match pdefs with
    | [] -> parts
    | (a1,a2,og, a3,a4)::xs ->
          let part,remains= List.partition (fun (hp_name,_,_,_,_) -> CP.eq_spec_var a1 hp_name) xs in
          partition_pdefs_by_hp_name remains (parts@[[(a1,a2,og,a3,a4)]@part])

let generalize_hps_par_def_x prog is_pre non_ptr_unk_hps unk_hpargs link_hps post_hps
      pre_def_grps predef_hps par_defs=
  (*partition the set by hp_name*)
  let pr1 = pr_list_ln (pr_list_ln (pr_penta !CP.print_sv !CP.print_svl Cprinter.prtt_string_of_h_formula_opt Cprinter.prtt_string_of_formula !CP.print_svl)) in
  let unk_hps = (List.map fst unk_hpargs) in
  let par_defs1 = List.concat (List.map (get_pdef_body unk_hps post_hps) par_defs) in
  let par_defs2 = (* List.filter is_valid_pardef *) par_defs1 in
  let groups = partition_pdefs_by_hp_name par_defs2 [] in
  (*do not generate anyting for LINK preds*)
  let groups1 = List.filter (fun grp ->
      match grp with
        | [] -> false
        | ((hp,_,_,_,_)::_) -> not (CP.mem_svl hp link_hps)
  ) groups
  in
  (*
    subst such that each partial def does not contain other hps
    dont subst recursively search_largest_matching between two formulas
  *)
  let _ = DD.ninfo_pprint ("      groups1: " ^ (pr1 groups)) no_pos in
  let groups20 =
    if predef_hps <> [] then pardef_subst_fix prog unk_hps (groups1@pre_def_grps)
    else
      groups1
  in
  (*filter out groups of pre-preds which defined already*)
  let groups2 =  List.filter (fun grp ->
      match grp with
        | [] -> false
        | ((hp,_,_,_,_)::_) -> not (CP.mem_svl hp predef_hps)
  ) groups20
  in
  (* let _ = Debug.info_pprint ("     END: " ) no_pos in *)
  (*remove empty*)
  let _ = DD.ninfo_pprint ("      groups2: " ^ (pr1 groups2)) no_pos in
  let groups3 = List.filter (fun grp -> grp <> []) groups2 in
  let _ = DD.tinfo_hprint (add_str "before remove redundant" pr1) groups2 no_pos in
  (*each group, do union partial definition*)
  let hpdefs,elim_ss = List.fold_left (fun (hpdefs,elim_ss) pdefs->
      let new_defs,ss = generalize_one_hp prog is_pre hpdefs non_ptr_unk_hps unk_hps link_hps pdefs in
      ((hpdefs@new_defs), elim_ss@ss)
  ) ([],[]) groups3
  in
  let prh = Cprinter.string_of_h_formula in
  let _ = DD.tinfo_hprint (add_str "elim_ss" (pr_list (pr_pair prh prh))) elim_ss no_pos in
  let pr2 = Cprinter.string_of_hp_rel_def in
  let pr_hpd = pr_list (fun (_,a)-> pr2 a) in
  let _ = DD.tinfo_hprint (add_str "after remove redundant" pr_hpd) hpdefs no_pos in
  let hpdefs1 =
    if !Globals.pred_elim_useless then
      List.map (fun (hp,(a,b,g, def)) ->
          (hp, (a,b,g, CF.subst_hrel_f def elim_ss))) hpdefs
    else
      hpdefs
  in
  hpdefs1

(*todo: remove non_ptr_unk_hps*)
let generalize_hps_par_def prog is_pre non_ptr_unk_hps unk_hpargs link_hps post_hps pre_defs predef_hps par_defs=
 let pr1 = pr_list_ln SAU.string_of_par_def_w_name in
  let pr2 = Cprinter.string_of_hp_rel_def in
  let pr3 = fun (_,a)-> pr2 a in
  Debug.no_4 "generalize_hps_par_def" !CP.print_svl !CP.print_svl pr1
      !CP.print_svl (pr_list_ln pr3)
      (fun _ _ _ _ -> generalize_hps_par_def_x prog is_pre non_ptr_unk_hps unk_hpargs
          link_hps post_hps pre_defs predef_hps par_defs)
      post_hps link_hps par_defs predef_hps

(*for tupled defs*)
let generalize_hps_cs_new_x prog callee_hps hpdefs unk_hps link_hps cs=
  let generalize_hps_one_cs constr=
    let lhs,rhs = constr.CF.hprel_lhs,constr.CF.hprel_rhs in
    let lhds, lhvs,l_hp = CF.get_hp_rel_formula lhs in
    let rhds, rhvs,r_hp = CF.get_hp_rel_formula rhs in
    let lhp_args = List.map (fun (id, eargs, _) -> (id, List.concat (List.map CP.afv eargs))) (l_hp) in
    let rhp_args = List.map (fun (id, eargs, _) -> (id, List.concat (List.map CP.afv eargs))) (r_hp) in
    (*filer def hp out*)
    let dfs = (hpdefs@callee_hps@unk_hps) in
    let diff = List.filter (fun (hp1,_) -> not(CP.mem_svl hp1 dfs)) lhp_args in
    let diff1 = List.filter (fun (hp1,_) -> not(CP.mem_svl hp1 link_hps)) diff in
    match diff1 with
      | [] -> ([],[],[]) (*drop constraint, no new definition*)
      | _ -> begin
          let _ = DD.binfo_pprint ">>>>>> generalize_one_cs_hp: <<<<<<" no_pos in
          if lhvs <> [] || lhds <> [] then
            ([constr],[],[])
          else
            let lhps, ls_largs = List.split lhp_args in
            let rhps, ls_rargs = List.split rhp_args in
            let largs = CP.remove_dups_svl (List.concat ls_largs) in
            let rargs = CP.remove_dups_svl (List.concat ls_rargs) in
            let keep_ptrs = SAU.look_up_closed_ptr_args prog (lhds@rhds) (lhvs@rhvs) (largs@rargs) in
            let pos = CF.pos_of_formula lhs in
            let nrhs = CF.mkAnd_pure rhs (MCP.mix_of_pure (CF.get_pure lhs)) pos in
            let keep_def_hps = lhps@rhps@unk_hps@hpdefs in
            let r = CF.drop_data_view_hrel_nodes nrhs SAU.check_nbelongsto_dnode SAU.check_nbelongsto_vnode SAU.check_neq_hrelnode keep_ptrs keep_ptrs keep_def_hps in
            if (not (SAU.is_empty_f r)) then
              let hps = List.map fst diff in
              let hfs = List.map (fun (hp,args) -> (CF.HRel (hp, List.map (fun x -> CP.mkVar x pos) args, pos))) diff in
              let hf = CF.join_star_conjunctions hfs in
              let def_tit = match diff with
                | [(hp,args)] -> CP.HPRelDefn (hp, List.hd args, List.tl args)
                | _ -> CP.HPRelLDefn hps
              in
              let _ = DD.ninfo_pprint ">>>>>> generalize_one_cs_hp: <<<<<<" pos in
              let _ = DD.ninfo_pprint ((let pr = pr_list (pr_pair !CP.print_sv !CP.print_svl) in pr diff) ^ "::=" ^
                  (Cprinter.prtt_string_of_formula r) ) pos in
                  ([],[((def_tit, hf, None , r))], hps)
            else
              ([constr],[], [])
        end
  in
  let cs1, hp_defs, hp_names = List.fold_left (fun (ls1,ls2,ls3) c ->
      let r1,r2,r3 = generalize_hps_one_cs c in
  (ls1@r1, ls2@r2, ls3@r3)
  ) ([],[],[]) cs
  in
  (*combine hp_defs*)
  let hpdefs = SAU.combine_hpdefs hp_defs in
  (cs1, hpdefs, hp_names)

let generalize_hps_cs_new prog callee_hps hpdefs unk_hps link_hps cs=
   let pr1 = pr_list_ln Cprinter.string_of_hprel in
   let pr3  = pr_list Cprinter.string_of_hp_rel_def in
   let pr4 (_,b,c) = let pr = pr_pair pr3 !CP.print_svl in pr (b,c) in
  Debug.no_4 "generalize_hps_cs_new" pr1 !CP.print_svl !CP.print_svl !CP.print_svl pr4
      (fun _ _ _ _ -> generalize_hps_cs_new_x prog callee_hps hpdefs unk_hps link_hps cs)
      cs callee_hps hpdefs unk_hps

let generalize_hps_x prog is_pre callee_hps unk_hps link_hps sel_post_hps pre_defs predef_hps cs par_defs=
  DD.binfo_pprint ">>>>>> step 6: generalization <<<<<<" no_pos;
(*general par_defs*)
  let non_ptr_unk_hps = List.concat (List.map (fun (hp,args) ->
      if List.exists (fun a ->
          not ( CP.is_node_typ a))
        args then [hp]
      else []) unk_hps) in
  let pair_names_defs = generalize_hps_par_def prog is_pre non_ptr_unk_hps unk_hps link_hps
    sel_post_hps pre_defs predef_hps par_defs in
  let hp_names,hp_defs = List.split pair_names_defs in
(*for each constraints, we may pick more definitions*)
  let remain_constr, hp_def1, hp_names2 = generalize_hps_cs_new prog callee_hps hp_names (List.map fst unk_hps) link_hps cs in
  (*room for unk predicates processing*)
  (remain_constr, (hp_defs@hp_def1), hp_names@hp_names2)

let generalize_hps prog is_pre callee_hps unk_hps link_hps sel_post_hps pre_defs predef_hps cs par_defs=
  let pr1 = pr_list_ln Cprinter.string_of_hprel in
  let pr2 = pr_list_ln SAU.string_of_par_def_w_name in
  let pr3 = pr_list Cprinter.string_of_hp_rel_def in
  Debug.no_4 "generalize_hp" !CP.print_svl !CP.print_svl pr1 pr2 (pr_triple pr1 pr3 !CP.print_svl)
      (fun _ _ _ _ -> generalize_hps_x prog is_pre callee_hps unk_hps link_hps sel_post_hps
          pre_defs predef_hps cs par_defs)
      callee_hps link_hps cs par_defs

(***************************************************************
                     END GENERALIZATION
****************************************************************)

(***************************************************************
                      LIB MATCHING
****************************************************************)
let collect_sel_hp_def_x cond_path defs sel_hps unk_hps m=
  (*currently, use the first lib matched*)
  let m = List.map (fun (hp, l) -> (hp, List.hd l)) m in
  let mlib = List.map (fun (hp, _) -> hp) m in
  let rec look_up_lib hp ms=
    match ms with
      | [] -> None
      | (hp1,hf1)::ss -> if CP.eq_spec_var hp hp1 then
            Some (CF.formula_of_heap hf1 no_pos)
          else look_up_lib hp ss
  in
  let mk_hprel_def kind hprel og opf opflib=
    {
        CF.hprel_def_kind = kind;
        CF.hprel_def_hrel = hprel;
        CF.hprel_def_guard = og;
        CF.hprel_def_body = [(cond_path,opf)];
        CF.hprel_def_body_lib = opflib;
    }
  in
  let compute_def_w_lib (hp,(a,hprel,og, f))=
    let olib = look_up_lib hp m in
    (* if CP.mem_svl hp unk_hps then *)
    (*   (mk_hprel_def a hprel None None) *)
    (* else *)
    begin
        let f1 =
          match olib with
            | None ->
            (*subs lib form inside f if applicable*)
                let f_subst = CF.subst_hrel_hview_f f m in
                f_subst
            | Some lib_f -> lib_f
        in
        (mk_hprel_def a hprel og (Some f) (Some f1))
    end
  in
  let look_up_depend cur_hp_sel f=
    let hps = CF.get_hp_rel_name_formula f in
    let dep_hp = Gen.BList.difference_eq CP.eq_spec_var hps (cur_hp_sel(* @unk_hps *)) in
    (CP.remove_dups_svl dep_hp)
  in
  let look_up_hp_def new_sel_hps non_sel_hp_def=
    List.partition (fun (hp,_) -> CP.mem_svl hp new_sel_hps) non_sel_hp_def
  in
  let rec find_closed_sel cur_sel cur_sel_hpdef non_sel_hp_def incr=
    let rec helper1 ls res=
      match ls with
        | [] -> res
        | (hp,(a,hf,og,f))::lss ->
            let incr =
              if CP.mem_svl hp (cur_sel(* @unk_hps *)) then
                []
              else
                [hp]
            in
            let new_hp_dep = look_up_depend cur_sel f in
            helper1 lss (CP.remove_dups_svl (res@incr@new_hp_dep))
    in
    let incr_sel_hps = helper1 incr [] in
    (*nothing new*)
    if incr_sel_hps = [] then cur_sel_hpdef else
      let incr_sel_hp_def,remain_hp_defs = look_up_hp_def incr_sel_hps non_sel_hp_def in
      find_closed_sel (cur_sel@incr_sel_hps) (cur_sel_hpdef@incr_sel_hp_def) remain_hp_defs incr_sel_hp_def
  in
  let defsw = List.map (fun (a,hf,og,f) ->
      (List.hd (CF.get_hp_rel_name_h_formula hf), (a,hf,og,f))) defs in
  let sel_defw,remain_hp_defs = List.partition (fun (hp,_) -> CP.mem_svl hp sel_hps) defsw in
  (* let sel_defw1 = Gen.BList.remove_dups_eq (fun (hp1,_) (hp2,_) -> CP.eq_spec_var hp1 hp2) sel_defw in *)
  let closed_sel_defw = find_closed_sel sel_hps sel_defw remain_hp_defs sel_defw in
  let all_sel_defw = List.map compute_def_w_lib closed_sel_defw in
  (*remove hp not in orig but == lib*)
  let inter_lib = Gen.BList.difference_eq CP.eq_spec_var mlib sel_hps in
  List.filter (fun hdef ->
      let a1 = hdef.CF.hprel_def_kind in
      let hp = SAU.get_hpdef_name a1 in
      not (CP.mem_svl hp inter_lib))
      all_sel_defw

let collect_sel_hp_def defs sel_hps unk_hps m=
  let pr1 = pr_list_ln Cprinter.string_of_hp_rel_def in
  let pr2 = !CP.print_svl in
  let pr3b = pr_list_ln Cprinter.prtt_string_of_h_formula in
  let pr3a = fun (hp,vns) -> (!CP.print_sv hp) ^ " === " ^
      (* ( String.concat " OR " view_names) *) (pr3b vns) in
  let pr3 = pr_list_ln pr3a in
  let pr4 = (pr_list_ln Cprinter.string_of_hprel_def) in
  Debug.no_3 "collect_sel_hp_def" pr1 pr2 pr3 pr4
      (fun _ _ _ -> collect_sel_hp_def_x defs sel_hps unk_hps m) defs sel_hps m

let match_hps_views_x (hp_defs: CF.hp_rel_def list) (vdcls: CA.view_decl list):
(CP.spec_var* CF.h_formula list) list=
  let hp_defs1 = List.filter (fun (def,_,_,_) -> match def with
    | CP.RelDefn _ -> true
    | _ -> false
  ) hp_defs in
  let m = List.map (SAU.match_one_hp_views vdcls) hp_defs1 in
    (List.filter (fun (_,l) -> l<>[]) m)

let match_hps_views (hp_defs: CF.hp_rel_def list) (vdcls: CA.view_decl list):
(CP.spec_var* CF.h_formula list) list=
  let pr1 = pr_list_ln Cprinter.string_of_hp_rel_def in
  let pr2 = pr_list_ln  Cprinter.prtt_string_of_h_formula  in
  let pr3a = fun (hp,vns) -> (!CP.print_sv hp) ^ " === " ^
      (* ( String.concat " OR " view_names) *) (pr2 vns) in
  let pr3 = pr_list_ln pr3a in
  let pr4 = pr_list_ln (Cprinter.string_of_view_decl) in
  Debug.no_2 "match_hps_views" pr1 pr4 pr3
      (fun _ _ -> match_hps_views_x hp_defs vdcls) hp_defs vdcls


(***************************************************************
                     END LIB MATCHING
****************************************************************)
let partition_constrs_x constrs post_hps0=
  let get_post_hp post_hps cs=
    let ohp = CF.extract_hrel_head cs.CF.hprel_rhs in
        match ohp with
          | Some hp -> if (CP.mem_svl hp post_hps) then post_hps else
              let lhps = CF.get_hp_rel_name_formula cs.CF.hprel_lhs in
              if CP.mem_svl hp lhps then
                ( post_hps@[hp])
              else post_hps
          | None -> post_hps
  in
  let classify new_post_hps (pre_cs,post_cs,pre_oblg,tupled_hps, post_oblg) cs =
    let is_post =
      try
        let ohp = CF.extract_hrel_head cs.CF.hprel_rhs in
        match ohp with
          | Some hp -> (CP.mem_svl hp new_post_hps)
          | None -> false
      with _ -> false
    in
    if is_post then (pre_cs,post_cs@[cs],pre_oblg,tupled_hps,post_oblg) else
      let lhs_hps = CF.get_hp_rel_name_formula cs.CF.hprel_lhs in
      if CP.intersect_svl (new_post_hps) lhs_hps = [] then
        (*identify pre-oblg*)
        let l_hds, l_hvs,lhrels =CF.get_hp_rel_formula cs.CF.hprel_lhs in
        let r_hds, r_hvs,rhrels =CF.get_hp_rel_formula cs.CF.hprel_rhs in
        if (List.length l_hds > 0 || List.length l_hvs > 0) && List.length lhrels > 0 &&
          (* (List.length r_hds > 0 || List.length r_hvs > 0) && *) List.length rhrels > 0
        then
          (pre_cs,post_cs,pre_oblg@[cs],tupled_hps@(CP.diff_svl (List.map (fun (a,_,_) -> a) rhrels) lhs_hps),post_oblg)
        else
        (pre_cs@[cs],post_cs,pre_oblg,tupled_hps,post_oblg)
      else (pre_cs,post_cs,pre_oblg,tupled_hps,post_oblg@[cs])
  in
  let new_post_hps = (* List.fold_left get_post_hp [] constrs *) [] in
  let pre_constrs,post_constrs,pre_oblg, tupled_dep_on_hps, post_oblg_constrs = List.fold_left (classify (post_hps0@new_post_hps)) ([],[],[],[],[]) constrs in
  (*partition pre-constrs, filter ones in pre-obligation*)
  let pre_constrs1, pre_oblg_ext = List.partition (fun cs ->
      let lhs_hps = CF.get_hp_rel_name_formula cs.CF.hprel_lhs in
      CP.intersect_svl lhs_hps tupled_dep_on_hps = []
  ) pre_constrs in
  (pre_constrs1,post_constrs, pre_oblg@pre_oblg_ext, post_oblg_constrs, new_post_hps)
  (* (pre_constrs,post_constrs, pre_oblg, post_oblg_constrs, new_post_hps) *)

let partition_constrs constrs post_hps=
  let pr1 = pr_list_ln Cprinter.string_of_hprel_short in
  let pr2 = !CP.print_svl in
  Debug.no_2 "partition_constrs" pr1 pr2 (pr_penta pr1 pr1 pr1 pr1 pr2)
      (fun _ _ -> partition_constrs_x constrs post_hps) constrs post_hps

(***************************************************************
                     PROCESS INFER ACTION
****************************************************************)

let infer_analize_dang prog is=
   let constrs1, unk_hpargs1, unk_map1, link_hpargs1, _ = SAC.analize_unk prog is.CF.is_post_hps is.CF.is_constrs
    is.CF.is_unk_map is.CF.is_dang_hpargs is.CF.is_link_hpargs in
   { is with
       CF.is_constrs = constrs1;
       CF.is_link_hpargs = link_hpargs1;
       CF.is_dang_hpargs = unk_hpargs1;
       CF.is_unk_map = unk_map1
   }

let infer_split_base prog is=
  if !Globals.sa_sp_split_base || !Globals.sa_infer_split_base then
    (* let unk_hps1 = List.map fst is.IC.is_dang_hpargs in *)
    (* let link_hps1 = List.map fst is.IC.is_link_hpargs in *)
    let n_constrs, n_unk_map, n_link_hpargs =
      split_base_constr prog is.CF.is_cond_path is.CF.is_constrs is.CF.is_post_hps [] is.CF.is_unk_map
          (List.map fst is.CF.is_dang_hpargs) (List.map fst is.CF.is_link_hpargs)
    in
    { is with
        CF.is_constrs = n_constrs;
        CF.is_link_hpargs = n_link_hpargs;
        CF.is_unk_map = n_unk_map;
    }
  else is

let infer_pre_trans_closure prog is=
  let n_constrs,_ = apply_transitive_impl_fix prog is.CF.is_post_hps []
    (List.map fst is.CF.is_dang_hpargs)
    (List.map fst is.CF.is_link_hpargs) is.CF.is_constrs
  in
  { is with
      CF.is_constrs = n_constrs;
  }

let infer_pre_synthesize_x prog proc_name callee_hps is need_preprocess detect_dang=
  let constrs0 = List.map (SAU.weaken_strengthen_special_constr_pre true) is.CF.is_constrs in
  let unk_hps1 = (List.map fst is.CF.is_dang_hpargs) in
  let link_hps = (List.map fst is.CF.is_link_hpargs) in
  let _ = DD.binfo_pprint ">>>>>> pre-predicates: step pre-5: group & simpl impl<<<<<<" no_pos in
  let pr_par_defs,rem_constrs1 = get_par_defs_pre constrs0 in
  let par_defs, rem_constrs2, hconj_unify_cond = combine_pdefs_pre prog unk_hps1 link_hps pr_par_defs in
  let _ = DD.binfo_pprint ">>>>>> pre-predicates: step pre-7: remove redundant x!=null<<<<<<" no_pos in
  let _ = DD.binfo_pprint ">>>>>> pre-predicates: step pre-8: strengthen<<<<<<" no_pos in
  let rem_constrs3, hp_defs, defined_hps = generalize_hps prog true callee_hps is.CF.is_dang_hpargs link_hps is.CF.is_post_hps [] [] constrs0 par_defs in
  (* check hconj_unify_cond*)
  let hp_defs1, new_equivs, unk_equivs = if hconj_unify_cond = [] then
    (hp_defs,[], [])
  else
    let is_sat, new_hpdefs, equivs, unk_equivs = SAC.reverify_cond prog unk_hps1 link_hps hp_defs hconj_unify_cond in
    if not is_sat then report_error no_pos "SA.infer_shapes_init_pre: HEAP CONJS do not SAT"
    else (new_hpdefs, equivs,  unk_equivs)
  in
  { is with
      CF.is_constrs = rem_constrs1@rem_constrs2@rem_constrs3;
      CF.is_hp_equivs = new_equivs@unk_equivs;
      CF.is_hp_defs = is.CF.is_hp_defs@hp_defs1;
  }

let infer_pre_synthesize prog proc_name callee_hps is need_preprocess detect_dang=
  let pr1 = Cprinter.string_of_infer_state_short in
  Debug.no_1 "infer_pre_synthesize" pr1 pr1
      (fun _ -> infer_pre_synthesize_x prog proc_name callee_hps is need_preprocess detect_dang) is

let infer_post_synthesize_x prog proc_name callee_hps is need_preprocess detect_dang=
  let constrs1 = List.map (SAU.weaken_strengthen_special_constr_pre false) is.CF.is_constrs in
  let _ = DD.binfo_pprint ">>>>>> step post-4: step remove unused predicates<<<<<<" no_pos in
  let par_defs = get_par_defs_post constrs1 in
  let _ = DD.binfo_pprint ">>>>>> post-predicates: step post-5: remove redundant x!=null : not implemented yet<<<<<<" no_pos in

  let _ = DD.binfo_pprint ">>>>>> post-predicates: step post-61: weaken<<<<<<" no_pos in
  (*subst pre-preds into if they are not recursive -do with care*)
  let pre_hps_need_fwd= SAU.get_pre_fwd is.CF.is_post_hps par_defs in
  let pre_defs, pre_hps = SAU.extract_fwd_pre_defs pre_hps_need_fwd is.CF.is_hp_defs in
  let pair_names_defs = generalize_hps_par_def prog false [] is.CF.is_dang_hpargs (List.map fst is.CF.is_link_hpargs) is.CF.is_post_hps
    pre_defs pre_hps par_defs in
  let hp_names,hp_defs = List.split pair_names_defs in
  {is with CF.is_constrs = [];
      CF.is_hp_defs = is.CF.is_hp_defs@hp_defs}

let infer_post_synthesize prog proc_name callee_hps is need_preprocess detect_dang=
  let pr1 = Cprinter.string_of_infer_state_short in
  Debug.no_1 "infer_post_synthesize" pr1 pr1
      (fun _ -> infer_post_synthesize_x prog proc_name callee_hps is need_preprocess detect_dang) is

(*for each oblg generate new constrs with new hp post in rhs*)
    (*call to infer_shape? proper? or post?*)
let rec infer_shapes_from_fresh_obligation_x iprog cprog proc_name callee_hps is_pre is sel_lhps sel_rhps need_preprocess detect_dang def_hps=
  (*if rhs is emp heap, should retain the constraint*)
  let pre_constrs, pre_oblg = List.partition (fun cs -> SAU.is_empty_heap_f cs.CF.hprel_rhs) is.CF.is_constrs in
  let ho_constrs0, nondef_post_hps = List.fold_left (collect_ho_ass cprog is_pre def_hps) ([],[]) pre_oblg in
  let ho_constrs = ho_constrs0@pre_constrs in
  if ho_constrs = [] then is else
    (***************  PRINTING*********************)
    let _ =
    begin
      let pr = pr_list_ln Cprinter.string_of_hprel_short in
      print_endline "";
      print_endline "\n*************************************************";
      print_endline "*******relational assumptions (obligation)********";
      print_endline "****************************************************";
      print_endline (pr ho_constrs0);
      print_endline "*************************************"
    end
    in
    let _ =
    begin
      let pr = pr_list_ln Cprinter.string_of_hprel_short in
      print_endline "";
      print_endline "\n*************************************************";
      print_endline "*******relational assumptions (pre-assumptions)********";
      print_endline "****************************************************";
      print_endline (pr pre_constrs);
      print_endline "*************************************"
    end
    in
    (***************  END PRINTING*********************)
    let is2 = infer_init iprog cprog proc_name is.CF.is_cond_path ho_constrs callee_hps (sel_lhps@sel_rhps)
      (*post-preds in lhs which dont have ad definition should be considered as pre-preds*)
      (CP.diff_svl (is.CF.is_post_hps@sel_rhps) nondef_post_hps)
      is.CF.is_unk_map is.CF.is_dang_hpargs is.CF.is_link_hpargs
      need_preprocess detect_dang
    in
    {is2 with CF.is_constrs = [];
        CF.is_hp_defs = is.CF.is_hp_defs@is2.CF.is_hp_defs;
    }

and infer_shapes_from_fresh_obligation iprog cprog proc_name callee_hps
      is_pre is sel_lhps sel_rhps need_preprocess detect_dang def_hps=
  let pr1 = Cprinter.string_of_infer_state_short in
  Debug.no_1 "infer_shapes_from_fresh_obligation" pr1 pr1
      (fun _ -> infer_shapes_from_fresh_obligation_x iprog cprog proc_name callee_hps is_pre is sel_lhps sel_rhps need_preprocess detect_dang def_hps) is

and infer_shapes_from_obligation_x iprog prog proc_name callee_hps is_pre is need_preprocess detect_dang=
  let def_hps = List.fold_left (fun ls (hp_kind, _,_,_) ->
      match hp_kind with
        |  CP.HPRelDefn (hp,_,_) -> ls@[hp]
        | CP.HPRelLDefn hps -> ls@hps
        | _ -> ls
  ) [] is.CF.is_hp_defs in
  let classify_hps (r_lhs, r_rhs, dep_def_hps, r_oblg_constrs,r_rem_constrs) cs=
    let lhs_hps = CF.get_hp_rel_name_formula cs.CF.hprel_lhs in
    let rhs_hps = CF.get_hp_rel_name_formula cs.CF.hprel_rhs in
    let dep_define_hps1, rem_lhs = List.partition (fun hp -> CP.mem_svl hp def_hps) lhs_hps in
    let dep_define_hps2, rem_rhs = List.partition (fun hp -> CP.mem_svl hp def_hps) rhs_hps in
    if (* (rem_lhs = [] && rem_rhs=[]) || *)(is_pre && rem_rhs = [] && rem_lhs = []) ||
      ((not is_pre) && (rem_lhs <> [])) then
      (r_lhs, r_rhs, dep_def_hps, r_oblg_constrs, r_rem_constrs@[cs])
    else
      (r_lhs@rem_lhs, r_rhs@rem_rhs, dep_def_hps@dep_define_hps1@dep_define_hps2,r_oblg_constrs@[cs], r_rem_constrs)
  in
  let constrs0 = is.CF.is_constrs in
  if constrs0 = [] then is else
    let constrs1 = SAU.remove_dups_constr constrs0 in
    (*the remain contraints will be treated as tupled ones.*)
    let sel_lhs_hps, sel_rhs_hps, dep_def_hps, oblg_constrs, rem_constr = List.fold_left classify_hps ([],[],[],[],[]) constrs1 in
    if oblg_constrs = [] then
      let pr1 = pr_list_ln  Cprinter.string_of_hprel_short in
      DD.binfo_pprint ("proving:\n" ^ (pr1 rem_constr)) no_pos;
      (* let _ = if rem_constr = [] then () else *)
      (* (\*prove rem_constr*\) *)
      (* (\*transform defs to cviews*\) *)
      (* let need_trans_hprels = List.filter (fun (hp_kind, _,_,_) -> *)
      (*     match hp_kind with *)
      (*       |  CP.HPRelDefn (hp,_,_) -> CP.mem_svl hp dep_def_hps *)
      (*       | _ -> false *)
      (* ) (pre_defs@post_defs) in *)
      (* let n_cviews,chprels_decl = Saout.trans_hprel_2_cview iprog prog proc_name need_trans_hprels in *)
      (* let in_hp_names = List.map CP.name_of_spec_var dep_def_hps in *)
      (* (\*for each oblg, subst + simplify*\) *)
      (* let rem_constr2 = SAC.trans_constr_hp_2_view_x iprog prog proc_name (pre_defs@post_defs) *)
      (*   in_hp_names chprels_decl rem_constr in *)
      (* let _ = List.fold_left (collect_ho_ass prog is_pre def_hps) ([],[]) rem_constr2 in *)
      (* () *)
      (* in *)
      is
    else
      (* let _ = DD.info_pprint ("dep_def_hps: " ^ (!CP.print_svl dep_def_hps)) no_pos in *)
      let need_trans_hprels = List.filter (fun (hp_kind, _,_,_) ->
        match hp_kind with
          |  CP.HPRelDefn (hp,_,_) -> CP.mem_svl hp dep_def_hps
          | _ -> false
    ) is.CF.is_hp_defs in
    (*transform defs to cviews*)
    let n_cviews,chprels_decl = Saout.trans_hprel_2_cview iprog prog proc_name need_trans_hprels in
    let in_hp_names = List.map CP.name_of_spec_var dep_def_hps in
    (*for each oblg, subst + simplify*)
    let constrs2 = SAC.trans_constr_hp_2_view_x iprog prog proc_name is.CF.is_hp_defs
      in_hp_names chprels_decl oblg_constrs in
    (*for each oblg generate new constrs with new hp post in rhs*)
    (*call to infer_shape? proper? or post?*)
    let is1 = {is with CF.is_constrs = constrs2;} in
    let n_is=
      infer_shapes_from_fresh_obligation iprog prog proc_name callee_hps
          is_pre is1 sel_lhs_hps sel_rhs_hps need_preprocess detect_dang def_hps in
    let pr1 = pr_list_ln  Cprinter.string_of_hprel_short in
    DD.binfo_pprint ("rem_constr:\n" ^ (pr1 rem_constr)) no_pos;
    if rem_constr = [] then
      (*return*)
      n_is
    else
      (*loop*)
      let n_is1 = {n_is with CF.is_constrs = rem_constr;} in
      let n_is2 = infer_shapes_from_obligation iprog prog proc_name callee_hps is_pre n_is1 need_preprocess detect_dang in
      n_is2

and infer_shapes_from_obligation iprog prog proc_name callee_hps is_pre is need_preprocess detect_dang=
  let pr1 = Cprinter.string_of_infer_state_short in
  Debug.no_1 "infer_shapes_from_obligation" pr1 pr1
      (fun _ -> infer_shapes_from_obligation_x iprog prog proc_name callee_hps is_pre is need_preprocess detect_dang) is

and infer_shapes_proper iprog prog proc_name callee_hps is need_preprocess detect_dang=
  let unk_hps = List.map fst is.CF.is_dang_hpargs in
  let link_hps = List.map fst is.CF.is_link_hpargs in
  (*partition constraints into 4 groups: pre-predicates, pre-oblg,post-predicates, post-oblg*)
  let pre_constrs,post_constrs, pre_oblg_constrs, post_oblg_constrs, new_post_hps =
    partition_constrs is.CF.is_constrs is.CF.is_post_hps
  in
  let post_hps1 = is.CF.is_post_hps@new_post_hps in
  let pre_constrs1 = List.map (SAU.simp_match_unknown unk_hps link_hps) pre_constrs in
  (*pre-synthesize*)
  let is_pre = {is with CF.is_constrs = pre_constrs1;
      CF.is_post_hps = post_hps1;
  } in
  let pre_act = IC.icompute_action_pre () in
  let is_pre1 = iprocess_action iprog prog proc_name callee_hps is_pre pre_act need_preprocess detect_dang in
  (*pre-oblg*)
  let is_pre_oblg1 = if pre_oblg_constrs = [] then is_pre1
  else
    let is_pre_oblg = { is_pre1 with CF.is_constrs = pre_oblg_constrs} in
    let pre_obl_act = IC.icompute_action_pre_oblg () in
    iprocess_action iprog prog proc_name callee_hps is_pre_oblg pre_obl_act need_preprocess detect_dang
  in
  (*post-synthesize*)
  let is_post = {is_pre_oblg1 with CF.is_constrs = post_constrs } in
  let post_act = IC.icompute_action_post () in
  let is_post1 = iprocess_action iprog prog proc_name callee_hps is_post post_act need_preprocess detect_dang in
  (*post-oblg*)
  let is_post_oblg1 = if post_oblg_constrs = [] then is_post1
  else
    let is_post_oblg = {is_post1 with CF.is_constrs = post_oblg_constrs } in
    let post_obl_act = IC.icompute_action_post_oblg () in
    iprocess_action iprog prog proc_name callee_hps is_post_oblg post_obl_act need_preprocess detect_dang
  in
  is_post_oblg1

(***************************************************************
                     END PROCESS INFER ACTION
****************************************************************)
and iprocess_action_x iprog prog proc_name callee_hps is act need_preprocess detect_dang=
  let rec_fct l_is l_act = iprocess_action iprog prog proc_name callee_hps l_is l_act need_preprocess detect_dang in
  match act with
    | IC.I_infer_dang -> infer_analize_dang prog is
    | IC.I_pre_trans_closure -> infer_pre_trans_closure prog is
    | IC.I_split_base -> infer_split_base prog is
    | IC.I_partition -> infer_shapes_proper iprog prog proc_name callee_hps is need_preprocess detect_dang
    | IC.I_pre_synz -> infer_pre_synthesize prog proc_name callee_hps is need_preprocess detect_dang
    | IC.I_pre_oblg -> infer_shapes_from_obligation iprog prog proc_name callee_hps true is need_preprocess  detect_dang
    | IC.I_post_synz -> infer_post_synthesize prog proc_name callee_hps is need_preprocess detect_dang
    | IC.I_post_oblg -> infer_shapes_from_obligation iprog prog proc_name callee_hps false is need_preprocess  detect_dang
    | IC.I_seq ls_act -> List.fold_left (fun is (_,act) -> rec_fct is act) is ls_act

and iprocess_action iprog prog proc_name callee_hps is act need_preprocess detect_dang=
  let pr1 = IC.string_of_iaction in
  let pr2 = Cprinter.string_of_infer_state_short in
  Debug.no_2 "iprocess_action" pr2 pr1 pr2
      (fun _ _ -> iprocess_action_x iprog prog proc_name callee_hps is act need_preprocess detect_dang) is act

and infer_init iprog prog proc_name cond_path constrs0 callee_hps sel_hps
    post_hps unk_map unk_hpargs0a link_hpargs need_preprocess detect_dang =
  (* let prog_vars = [] in *) (*TODO: improve for hip*)
  (********************************)
  let unk_hpargs0b = List.fold_left (fun ls ((hp,_),xpure) ->
      let args = match xpure.CP.xpure_view_node with
        | None -> xpure.CP.xpure_view_arguments
        | Some r -> r::xpure.CP.xpure_view_arguments
      in
      ls@[(hp,args)]
  ) [] unk_map
  in
  let unk_hpargs = Gen.BList.remove_dups_eq (fun (hp1,_) (hp2,_) -> CP.eq_spec_var hp1 hp2) (unk_hpargs0a@unk_hpargs0b) in
  let is = IC.mk_is constrs0 link_hpargs unk_hpargs unk_map sel_hps post_hps cond_path [] [] in
  let act = IC.icompute_action_init need_preprocess detect_dang in
  iprocess_action iprog prog proc_name callee_hps is act need_preprocess detect_dang

let infer_shapes_x iprog prog proc_name (constrs0: CF.hprel list) sel_hps post_hps hp_rel_unkmap unk_hpargs link_hpargs0 need_preprocess detect_dang: (CF.hprel list * CF.hp_rel_def list)
      (* (CF.hprel list * CF.hp_rel_def list* (CP.spec_var*CP.exp list * CP.exp list) list ) *) =
  (*move to outer func*)
  (* let callee_hpdefs = *)
  (*   try *)
  (*       Cast.look_up_callee_hpdefs_proc prog.Cast.new_proc_decls proc_name *)
  (*   with _ -> [] *)
  (* in *)
  (* let callee_hps = List.map (fun (hpname,_,_) -> SAU.get_hpdef_name hpname) callee_hpdefs in *)
  let callee_hps = [] in
  let _ = DD.binfo_pprint ("  sel_hps:" ^ !CP.print_svl sel_hps) no_pos in
  let _ = DD.binfo_pprint ("  sel post_hps:" ^ (!CP.print_svl post_hps)) no_pos in
  let all_post_hps = CP.remove_dups_svl (post_hps@(SAU.collect_post_preds prog constrs0)) in
  let _ = DD.binfo_pprint ("  all post_hps:" ^ (!CP.print_svl all_post_hps)  ^ "\n") no_pos in
  let grp_link_hpargs = SAU.dang_partition link_hpargs0 in
  (*TODO: LOC: find a group of rel ass with the same cond_path.
    Now, assume = []
  *)
  let cond_path = [] in
  (*for temporal*)
  let link_hpargs = match grp_link_hpargs with
    | [] -> []
    | (_, a)::_ -> a
  in
  let is = infer_init iprog prog proc_name cond_path constrs0
    callee_hps sel_hps
    all_post_hps hp_rel_unkmap unk_hpargs
   link_hpargs need_preprocess detect_dang in
  let link_hp_defs = SAC.generate_hp_def_from_link_hps prog cond_path is.CF.is_hp_equivs is.CF.is_link_hpargs in
  let hp_defs1,tupled_defs = SAU.partition_tupled is.CF.is_hp_defs in
  (*decide what to show: DO NOT SHOW hps relating to tupled defs*)
  let m = match_hps_views is.CF.is_hp_defs prog.CA.prog_view_decls in
  let sel_hps1 = if !Globals.pred_elim_unused_preds then sel_hps else
    CP.remove_dups_svl ((List.map (fun (a,_,_,_) -> SAU.get_hpdef_name a) hp_defs1)@sel_hps)
  in
  let sel_hp_defs = collect_sel_hp_def cond_path hp_defs1 sel_hps1 is.CF.is_dang_hpargs m in
  let tupled_defs1 = List.map (fun (a, hf,og, f) -> {
      CF.hprel_def_kind = a;
      CF.hprel_def_hrel = hf;
      CF.hprel_def_guard = og;
      CF.hprel_def_body = [(cond_path, Some f)];
      CF.hprel_def_body_lib = Some f;
  }
  ) tupled_defs in
  let shown_defs = if !Globals.pred_elim_unused_preds then sel_hp_defs@link_hp_defs else
    sel_hp_defs@tupled_defs1@link_hp_defs
  in
  let _ = List.iter (fun hp_def -> rel_def_stk # push hp_def) shown_defs in
  (is.CF.is_constrs,is.CF.is_hp_defs)

let infer_shapes iprog prog proc_name (hp_constrs: CF.hprel list) sel_hp_rels sel_post_hp_rels
      hp_rel_unkmap unk_hpargs link_hpargs need_preprocess detect_dang:
 (* (CF.cond_path_type * CF.hp_rel_def list*(CP.spec_var*CP.exp list * CP.exp list) list) = *)
  (* (CF.hprel list * CF.hp_rel_def list*(CP.spec_var*CP.exp list * CP.exp list) list) = *)
      (CF.hprel list * CF.hp_rel_def list) =
  (* let pr0 = pr_list !CP.print_exp in *)
  let pr1 = pr_list_ln Cprinter.string_of_hprel_short in
  let pr2 = pr_list_ln Cprinter.string_of_hp_rel_def in
  (* let pr3 = pr_list (pr_triple !CP.print_sv pr0 pr0) in *)
  (* let pr4 = pr_list (pr_pair (pr_list (pr_pair !CP.print_sv string_of_int)) CP.string_of_xpure_view) in *)
  let pr4 = (pr_list (pr_pair (pr_pair !CP.print_sv (pr_list string_of_int)) CP.string_of_xpure_view)) in
  let pr5 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in
  let pr5a = pr_list (pr_pair CF.string_of_cond_path (pr_pair !CP.print_sv !CP.print_svl)) in
  let _ = if !Globals.print_heap_pred_decl then
    let all_hps = CF.get_hp_rel_name_assumption_set hp_constrs in
    let all_hp_decls = List.fold_left (fun ls hp ->
        try
          let hp_decl = Cast.look_up_hp_def_raw prog.Cast.prog_hp_decls (CP.name_of_spec_var hp) in
          ls@[hp_decl]
        with _ -> ls
    ) [] all_hps
    in
    if !Globals.sleek_flag then () 
    else
      let _ = print_endline "\nHeap Predicate Declarations" in
      let _ = print_endline "===========================" in
      let _ = List.iter (fun hpdcl -> print_string (Cprinter.string_of_hp_decl hpdcl)) all_hp_decls in
      ()
  else ()
  in
  Debug.no_6 "infer_shapes" pr_id pr1 !CP.print_svl pr4 pr5 pr5a (pr_pair pr1 pr2)
      (fun _ _ _ _ _ _ -> infer_shapes_x iprog prog proc_name hp_constrs sel_hp_rels
          sel_post_hp_rels hp_rel_unkmap unk_hpargs link_hpargs
          need_preprocess detect_dang)
      proc_name hp_constrs sel_post_hp_rels hp_rel_unkmap unk_hpargs link_hpargs
