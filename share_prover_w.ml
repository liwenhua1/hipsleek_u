open Genopen Debug let no_pos = Globals.no_poslet report_error = Gen.report_errormodule Ts = Tree_shares.Tsmodule CP = Cpure(*module Sv:Share_prover.SV =  struct	type t = CP.spec_var	let cnt = ref 1	let eq = CP.eq_spec_var	(*type t_spec = CP.spec_var		let rconv v = v	let conv v = v	let string_of_s v1 = CP.string_of_spec_var v1	let get_name_s v = CP.string_of_spec_var v	*)    let string_of v1 = CP.string_of_spec_var v1		let rename s a =  match s with CP.SpecVar(t,_,p)-> CP.SpecVar(t,a,p)    let get_name v = CP.string_of_spec_var v		let var_of v = CP.SpecVar(Globals.Tree_sh,v,Globals.Unprimed)    let fresh_var v = cnt:=!cnt+1; rename v ("__ts_fv_"^(string_of_int !cnt))end*)	module Ss_proc_Z3:Share_prover.SAT_SLV = functor (Sv:Share_prover.SV) ->  struct	type t_var = Sv.t	type nz_cons = t_var list list 	type p_var = (*include Gen.EQ_TYPE with type t=v*)		| PVar of t_var 		| C_top	type eq_syst = (t_var*t_var*p_var) list				let mkTop () = C_top	let mkVar v = PVar v	let getVar v = match v with | C_top -> None | PVar v -> Some v			let string_of_eq (v1,v2,v3) = (Sv.string_of v1)^" * "^(Sv.string_of v2)^" = "^(match v3 with | PVar v3 ->  Sv.string_of v3 | _ -> " true")	let string_of_eq_l l = String.concat "\n" (List.map string_of_eq l)		let to_sv v = CP.SpecVar(Globals.Bool,Sv.string_of v,Globals.Unprimed)		let mkBfv v = CP.BForm ((CP.BVar (to_sv v,no_pos),None),None)			let f_of_eqs eqs = List.fold_left (fun a (e1,e2,e3)-> 			let bf1,bf2 = mkBfv e1, mkBfv e2 in			let f_eq =  match e3 with				| PVar v3->					let bf3 = mkBfv v3 in					let f1 = CP.And (bf3, CP.And (bf2, CP.Not (bf1,None,no_pos),no_pos), no_pos) in					let f2 = CP.And (bf3, CP.And (bf1, CP.Not (bf2,None,no_pos),no_pos), no_pos) in					let f3 = CP.Or (CP.Not (bf2,None,no_pos), CP.Not (bf1,None,no_pos), None, no_pos) in					let r = CP.Or (f1,f2,None,no_pos) in					CP.And(r,f3,no_pos)				| C_top -> 					let f1 = CP.And (bf2, CP.Not (bf1,None,no_pos),no_pos) in					let f2 = CP.And (bf1, CP.Not (bf2,None,no_pos),no_pos) in							CP.Or (f1,f2,None,no_pos) in			CP.mkAnd a f_eq no_pos) (CP.mkTrue no_pos) eqs 			let check_nz_sat f_eq f_nz_l = 		let f_tot = List.fold_left (fun a c-> CP.mkAnd a c no_pos) f_eq f_nz_l in		if Smtsolver.is_sat f_tot "0" then true 		else List.for_all (fun c-> Smtsolver.is_sat (CP.mkAnd f_eq c no_pos) "1") f_nz_l			let call_sat non_zeros eqs = 			let f = f_of_eqs eqs in		let f_nz_l = List.map (List.fold_left (fun a c-> CP.mkOr a (mkBfv c) None no_pos) (CP.mkTrue no_pos))  non_zeros in		check_nz_sat f f_nz_l			let call_sat non_zeros eqs = 		let nzs = String.concat "," (List.map (fun l-> "{"^(String.concat "," (List.map Sv.string_of l))^"}") non_zeros) in		let eqss = string_of_eq_l eqs in		Debug.devel_zprint (lazy ("Z3 SAT: "^nzs^"\n"^eqss^"\n")) no_pos;		let r = call_sat non_zeros eqs in		Debug.devel_zprint (lazy ("r: "^(string_of_bool r)^"\n")) no_pos; r(*t_var list -> nz_cons -> eq_syst -> t_var list -> nz_cons -> eq_syst -> (t_var*bool) list -> (t_var*t_var) list-> bool*)	let call_imply (a_ev:t_var list) a_nz_cons a_l_eqs (c_ev:t_var list) c_nz_cons c_l_eqs c_const_vars c_subst_vars  = 		let ante_eq_f = f_of_eqs a_l_eqs in		let ante_nz_l = List.map (List.fold_left (fun a c-> CP.mkOr a (mkBfv c) None no_pos) (CP.mkTrue no_pos))  a_nz_cons in		if not (check_nz_sat ante_eq_f ante_nz_l) then true		else			let ante_tot = CP.mkExists (List.map to_sv a_ev) (List.fold_left (fun a c-> CP.mkAnd a c no_pos) ante_eq_f ante_nz_l) None no_pos in			let conseq_tot = 				let conseq_eq_f = f_of_eqs c_l_eqs in				let conseq_nz_f = List.fold_left (fun a c->					let r = List.fold_left (fun a c-> CP.mkOr a (mkBfv c) None no_pos) (CP.mkTrue no_pos) c in					CP.And (a,r,no_pos)) conseq_eq_f  c_nz_cons in				let vc_f = List.fold_left (fun a (v,c)-> 					let r = if c then mkBfv v else CP.Not (mkBfv v, None, no_pos) in					CP.And (r,a,no_pos)) conseq_nz_f  c_const_vars in				let ve_f = List.fold_left (fun a (v1,v2)->					let f1 = CP.Or (CP.Not (mkBfv v1, None, no_pos),mkBfv v2, None, no_pos) in					let f2 = CP.Or (CP.Not (mkBfv v2, None, no_pos),mkBfv v1, None, no_pos) in					CP.And (CP.And (f1,f2,no_pos),a,no_pos)) vc_f c_subst_vars in				CP.mkExists (List.map to_sv c_ev) ve_f None no_pos in			let _ = Debug.devel_zprint (lazy ("share prover: call_imply ante:  "^ (Cprinter.string_of_pure_formula ante_tot))) no_pos in			let _ = Debug.devel_zprint (lazy ("share prover: call_imply conseq:  "^ (Cprinter.string_of_pure_formula conseq_tot))) no_pos in			Smtsolver.imply ante_tot conseq_tot 0.0						let call_imply (a_ev:t_var list) a_nz_cons a_l_eqs c_ev c_nz_cons c_l_eqs c_const_vars c_subst_vars  = 			let nzsf l = String.concat "," (List.map (fun l-> "{"^(String.concat "," (List.map Sv.string_of l))^"}") l) in			let consl = Gen.Basic.pr_list (Gen.Basic.pr_pair Sv.string_of string_of_bool) c_const_vars in			let cvel = Gen.Basic.pr_list (Gen.Basic.pr_pair Sv.string_of Sv.string_of) c_subst_vars in			let anzs = nzsf a_nz_cons in			let cnzs = nzsf c_nz_cons in			let aeqss = string_of_eq_l a_l_eqs in			let ceqss = string_of_eq_l c_l_eqs in			Debug.devel_zprint (lazy ("Imply ante: "^anzs^";\n"^aeqss^";\n")) no_pos;			Debug.devel_zprint (lazy ("Imply conseq: "^cnzs^";\n"^cvel^";\n"^consl^";\n"^ceqss^";\n")) no_pos;			let r = call_imply a_ev a_nz_cons a_l_eqs c_ev c_nz_cons c_l_eqs c_const_vars c_subst_vars in			Debug.devel_zprint (lazy ("r: "^(string_of_bool r))) no_pos; rend;;(*module SSV = Share_prover.Sv*)module Solver_byt = Share_prover.Dfrac_s_solver(Ts)(Share_prover.Sv)(Ss_proc_Z3)(*to switch to z3 as library change solver from solver_byt to Solver_nat*)(*module Solver_nat = Shares_z3_lib.Solver*)module Solver= Solver_bytlet tr_var v= CP.string_of_spec_var vlet sv_eq = Share_prover.Sv.eq let mkVperm v = Solver.Vperm (tr_var v)let mkCperm t = Solver.Cperm tlet rec simpl fl = 	List.fold_left (fun (ve,vc,j) e-> 		match e with 		| CP.Eq (e1,e2,_) -> 		 (match (e1,e2) with 			| CP.Var (v1,_),CP.Var (v2,_) -> (tr_var v1, tr_var v2)::ve,vc,j			| CP.Var (v,_),CP.Tsconst t 			| CP.Tsconst t, CP.Var (v,_) -> ve,(tr_var v,fst t)::vc,j			| CP.Add(e1,e2,_),CP.Tsconst (t,_)  			| CP.Tsconst (t,_),CP.Add(e1,e2,_) -> 			   (match e1,e2 with				 | CP.Var (v1,_), CP.Var (v2,_) -> ve,vc,(mkVperm v1, mkVperm v2, mkCperm t)::j			     | CP.Tsconst (t1,_), CP.Tsconst (t2,_) ->				     if (Ts.can_join t1 t2)&& Ts.eq t (Ts.join t1 t2) then ve,vc,j					 else raise Solver.Unsat_exception				 | CP.Var (v1,_), CP.Tsconst (t1,_)				 | CP.Tsconst (t1,_), CP.Var (v1,_) -> 					if Ts.eq t t1 then raise Solver.Unsat_exception					else if Ts.contains t t1 then ve,(tr_var v1,Ts.subtract t t1)::vc,j					else raise Solver.Unsat_exception				| _,_ -> report_error no_pos "unexpected share formula")			| CP.Add(e1,e2,_),CP.Var (v,_)			| CP.Var (v,_),CP.Add(e1,e2,_) -> 			   (match e1,e2 with				 | CP.Var (v1,_), CP.Var (v2,_) -> ve,vc,(mkVperm v1, mkVperm v2, mkVperm v)::j			     | CP.Tsconst (t1,_), CP.Tsconst (t2,_) ->				     if (Ts.can_join t1 t2) then ve,(tr_var v,Ts.join t1 t2)::vc,j					 else raise Solver.Unsat_exception				 | CP.Var (v1,_), CP.Tsconst (t,_) 				 | CP.Tsconst (t,_), CP.Var (v1,_) -> ve,vc,(mkCperm t, mkVperm v1, mkVperm v)::j				 | _,_ -> report_error no_pos "unexpected share formula")			| _,_ -> report_error no_pos "unexpected share formula")		| _ -> report_error no_pos "unexpected non_equality") ([],[],[]) fl		let simpl fl = 	let pr1 = pr_list (fun c-> !CP.print_b_formula (c,None)) in	let pe = pr_list (pr_pair (fun c->c) (fun c->c)) in	let pc = pr_list (pr_pair (fun c->c) Ts.string_of) in	let pre1 e = match e with | Solver.Vperm t-> t | Solver.Cperm t-> Ts.string_of t in	let peq = pr_list (pr_triple pre1 pre1 pre1) in	let pr2 = pr_triple pe pc peq in	Debug.no_1_loop "simpl" pr1 pr2 simpl fl		let fv_eq_syst acc l = 	let f c = match c with | Solver.Vperm v-> [v] | Solver.Cperm _ -> [] in	List.fold_left (fun a (e1,e2,e3)-> a@(f e1)@(f e2)@(f e3)) acc l 		let sleek_sat_wrapper ((evs,f):CP.spec_var list * CP.p_formula list):bool = 	try 		let ve,vc,le = simpl f in		let lv1 = List.fold_left (fun a (v1,v2)-> v1::v2::a) [] ve in		let lv2 = List.fold_left (fun a (v,_)-> v::a) lv1 vc in		let eqs = {			Solver.eqs_ex = List.map tr_var evs ;			Solver.eqs_nzv = Gen.BList.remove_dups_eq sv_eq (fv_eq_syst lv2 le);			Solver.eqs_vc = vc;			Solver.eqs_ve = ve;			Solver.eqs_eql = le;} in		Solver.is_sat eqs	with | Solver.Unsat_exception -> false	let sleek_imply_wrapper (aevs,ante) (cevs,conseq) =    try 		let ave,avc,ale = simpl ante in		let avc = (Perm.PERM_const.full_perm_name, Ts.top)::avc in		let alv = fv_eq_syst (List.fold_left (fun a (v,_)-> v::a) (List.fold_left (fun a (v1,v2)-> v1::v2::a) [] ave) avc) ale in		let aeqs = {			Solver.eqs_ex = List.map tr_var aevs ;			Solver.eqs_nzv = Gen.BList.remove_dups_eq sv_eq alv;			Solver.eqs_vc = avc;			Solver.eqs_ve = ave;			Solver.eqs_eql = ale;} in		try			let cve,cvc,cle = simpl conseq in			let clv = fv_eq_syst (List.fold_left (fun a (v,_)-> v::a) (List.fold_left (fun a (v1,v2)-> v1::v2::a) [] cve) cvc) cle in			let ceqs = {				Solver.eqs_ex = List.map tr_var cevs ;				Solver.eqs_nzv = Gen.BList.remove_dups_eq sv_eq clv;				Solver.eqs_vc = cvc;				Solver.eqs_ve = cve;				Solver.eqs_eql = cle;} in			Solver.imply aeqs ceqs		with | Solver.Unsat_exception -> not (Solver.is_sat aeqs)	with | Solver.Unsat_exception -> true		let sleek_imply_wrapper (aevs,ante) (cevs,conseq) = 	let pr = pr_pair !CP.print_svl (pr_list (fun c-> !CP.print_b_formula (c,None))) in	Debug.no_2_loop "sleek_imply_wrapper" pr pr string_of_bool sleek_imply_wrapper (aevs,ante) (cevs,conseq)	