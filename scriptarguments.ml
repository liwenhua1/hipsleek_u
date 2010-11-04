let parse_only = ref false

let rtc = ref false

let comp_pred = ref false

let pred_to_compile = ref ([] : string list)

let print_version_flag = ref false

let inter = ref false

let enable_gui = ref false

type front_end =
  | XmlFE
  | NativeFE

let fe = ref NativeFE

let set_pred arg = 
  comp_pred := true;
  pred_to_compile := arg :: !pred_to_compile
  
let set_proc_verified arg =
  let procs = Util.split_by "," arg in
	Globals.procs_verified := procs @ !Globals.procs_verified
	
let set_frontend fe_str = match fe_str  with
  | "native" -> fe := NativeFE
  | "xml" -> fe := XmlFE
  | _ -> failwith ("Unsupported frontend: " ^ fe_str)


(* arguments/flags that might be used both by sleek and hip *)
let common_arguments = [
	("--no-omega-simpl", Arg.Clear Globals.omega_simpl,
	 "Do not use Omega to simplify the arithmetic constraints when using other solver");
	("--simpl-pure-part", Arg.Set Globals.simplify_pure,
	 "Simplify the pure part of the formulas");
	("--combined-lemma-heuristic", Arg.Set Globals.lemma_heuristic,
	 "Use the combined coerce&match + history heuristic for lemma application");
	("--move-exist-to-LHS", Arg.Set Globals.move_exist_to_LHS,
	 "Move instantiation (containing existential vars) to the LHS at the end of the folding process");
	("--max-renaming", Arg.Set Globals.max_renaming,
	 "Always rename the bound variables");
	("--no-anon-exist", Arg.Clear Globals.anon_exist,
	 "Disallow anonymous variables in the precondition to be existential");
	("--LHS-wrap-exist", Arg.Set Globals.wrap_exist,
	 "Existentially quantify the fresh vars in the residue after applying ENT-LHS-EX");
	("-noee", Arg.Clear Tpdispatcher.elim_exists_flag,
	 "No eleminate existential quantifiers before calling TP.");
	("-nofilter", Arg.Clear Tpdispatcher.filtering_flag,
	 "No assumption filtering.");
	("--check-coercions", Arg.Set Globals.check_coercions,
	 "Check coercion validity");
	("-dd", Arg.Set Debug.devel_debug_on,
     "Turn on devel_debug");
	("-dd-print-orig-conseq", Arg.Unit Debug.enable_dd_and_orig_conseq_printing,
     "Enable printing of the original consequent while debugging. Automatically enables -dd (debugging) ");
	("-gist", Arg.Set Globals.show_gist,
     "Show gist when implication fails");
	("--hull-pre-inv", Arg.Set Globals.hull_pre_inv,
	 "Hull precondition invariant at call sites");
	("--sat-timeout", Arg.Set_float Globals.sat_timeout,
	 "Timeout for sat checking");
	("--imply-timeout", Arg.Set_float Globals.imply_timeout,
     "Timeout for imply checking");
	("--log-proof", Arg.String Prooftracer.set_proof_file,
     "Log (failed) proof to file");
	("--trace-all", Arg.Set Globals.trace_all,
     "Trace all proof paths");
	("--log-cvcl", Arg.String Cvclite.set_log_file,
     "Log all CVC Lite formula to specified log file");
	("--log-cvc3", Arg.String Cvc3.set_log_file,
	 "Log all CVC3 formula to specified log file");
	("--log-omega", Arg.Set Omega.log_all_flag,
	 "Log all formulae sent to Omega Calculator in file allinput.oc");
	("--log-isabelle", Arg.Set Isabelle.log_all_flag,
	 "Log all formulae sent to Isabelle in file allinput.thy");
	("--log-coq", Arg.Set Coq.log_all_flag,
	 "Log all formulae sent to Coq in file allinput.v");
	("--log-mona", Arg.Set Mona.log_all_flag,
	 "Log all formulae sent to Mona in file allinput.mona");
	("--log-redlog", Arg.Set Redlog.is_log_all,
     "Log all formulae sent to Reduce/Redlog in file allinput.rl");
	("--use-isabelle-bag", Arg.Set Isabelle.bag_flag,
	 "Use the bag theory from Isabelle, instead of the set theory");
	("--no-coercion", Arg.Clear Globals.use_coercion,
     "Turn off coercion mechanism");
	("--no-exists-elim", Arg.Clear Globals.elim_exists,
	 "Turn off existential quantifier elimination during type-checking");
	("--no-diff", Arg.Set Solver.no_diff,
	 "Drop disequalities generated from the separating conjunction");
	("--no-set", Arg.Clear Globals.use_set,
	 "Turn off set-of-states search");
	("--unsat-elim", Arg.Set Globals.elim_unsat,
     "Turn on unsatisfiable formulae elimination during type-checking");
	("-nxpure", Arg.Set_int Globals.n_xpure,
     "Number of unfolding using XPure");
	("-parse", Arg.Set parse_only,
	 "Parse only");
	("--print-iparams", Arg.Set Globals.print_mvars,
	 "Print input parameters of predicates");
	("--print-x-inv", Arg.Set Globals.print_x_inv,
	 "Print computed view invariants");
	("-stop", Arg.Clear Globals.check_all,
	 "Stop checking on erroneous procedure");
	("--build-image", Arg.Symbol (["true"; "false"], Isabelle.building_image),
	 "Build the image theory in Isabelle - default false");
	("-tp", Arg.Symbol (["cvcl"; "cvc3"; "omega"; "co"; "isabelle"; "coq"; "mona"; "om";
	 "oi"; "set"; "cm"; "redlog"; "rm"; "prm" ], Tpdispatcher.set_tp),
	 "Choose theorem prover:\n\tcvcl: CVC Lite\n\tcvc3: CVC3\n\tomega: Omega Calculator (default)\n\tco: CVC Lite then Omega\n\tisabelle: Isabelle\n\tcoq: Coq\n\tmona: Mona\n\tom: Omega and Mona\n\toi: Omega and Isabelle\n\tset: Use MONA in set mode.\n\tcm: CVC Lite then MONA.");
	("--use-field", Arg.Set Globals.use_field,
	 "Use field construct instead of bind");
	("--use-large-bind", Arg.Set Globals.large_bind,
	 "Use large bind construct, where the bound variable may be changed in the body of bind");
	("-v", Arg.Set Debug.debug_on, 
	 "Verbose");
	("--pipe", Arg.Unit Tpdispatcher.Netprover.set_use_pipe, 
	 "use external prover via pipe");
	("--dsocket", Arg.Unit (fun () -> Tpdispatcher.Netprover.set_use_socket "loris-7:8888"), 
	 "<host:port>: use external prover via loris-7:8888");
	("--socket", Arg.String Tpdispatcher.Netprover.set_use_socket, 
	 "<host:port>: use external prover via socket");
	("--prover", Arg.String Tpdispatcher.set_tp, 
	 "<p,q,..> comma-separated list of provers to try in parallel");
	("--enable-sat-stat", Arg.Set Globals.enable_sat_statistics, 
	 "enable sat statistics");
	("--epi", Arg.Set Globals.profiling, 
	 "enable profiling statistics");
	("--sbc", Arg.Set Globals.enable_syn_base_case, 
	 "use only syntactic base case detection");
	("--eci", Arg.Set Globals.enable_case_inference,
	 "enable struct formula inference");
	("--pcp", Arg.Set Globals.print_core,
	 "print core representation");
	("--pip", Arg.Set Globals.print_input,
	 "print input representation");
	("--web", Arg.String (fun s -> (Tpdispatcher.Netprover.set_use_socket_for_web s); Tpdispatcher.webserver := true; Typechecker.webserver := true; Paralib1v2.webs := true; Paralib1.webs := true) ,  
	 "<host:port>: use external web service via socket");
	("-para", Arg.Int Typechecker.parallelize, 
	 "Use Paralib map_para instead of List.map in typecheker");
	("--priority",Arg.String Tpdispatcher.Netprover.set_prio_list, 
	 "<proc_name1:prio1;proc_name2:prio2;...> To be used along with webserver");
	("--decrprio",Arg.Set Tpdispatcher.decr_priority , 
	 "use a decreasing priority scheme");
	("--rl-no-pseudo-ops", Arg.Set Redlog.no_pseudo_ops, 
	 "Do not pseudo-strengthen/weaken formulas before send to Redlog");
	("--rl-no-ee", Arg.Set Redlog.no_elim_exists, 
	 "Do not try to eliminate existential quantifier with Redlog");
	("--rl-timeout", Arg.Set_int Redlog.timeout, 
	 "Set timeout (in seconds) for is_sat or imply with Redlog");
	("--failure-analysis",Arg.Set Globals.failure_analysis, 
	 "Turn on failure analysis");
	("--exhaust-match",Arg.Set Globals.exhaust_match, 
	 "Turn on exhaustive matching for base case of predicates"); 
  ] 

(* arguments/flags used only by hip *)	
let hip_specific_arguments = [ ("-cp", Arg.String set_pred,
   "Compile specified predicate to Java.");
  ("-rtc", Arg.Set rtc,
   "Compile to Java with runtime checks.");
  ("-nopp", Arg.String Rtc.set_nopp,
   "-nopp caller:callee: do not check callee's pre/post in caller");
  ("-nofield", Arg.String Rtc.set_nofield,
   "-nofield proc: do not perform field check in proc");
  ("--verify-callees", Arg.Set Globals.verify_callees,
   "Verify callees of the specified procedures");
  ("-inline", Arg.String Inliner.set_inlined,
   "Procedures to be inlined");
  ("-p", Arg.String set_proc_verified, 
   "Procedure to be verified. If none specified, all are verified.");
  ("-print", Arg.Set Globals.print_proc,
   "Print procedures being checked");
  ("--pgbv", Arg.Set Globals.pass_global_by_value, 
   "pass read global variables by value");
  ("--sqt", Arg.Set Globals.seq_to_try,
   "translate seq to try");
  ] 

(* arguments/flags used only by sleek *)	
let sleek_specific_arguments = [
   ("-fe", Arg.Symbol (["native"; "xml"], set_frontend),
	"Choose frontend:\n\tnative: Native (default)\n\txml: XML");
   ("-int", Arg.Set inter,
    "Run in interactive mode.");
   ("--slk-err", Arg.Set Globals.print_err_sleek,
	"print sleek errors");
   ("--iw",  Arg.Set Globals.wrap_exists_implicit_explicit ,
    "existentially wrap instantiations after the entailment");
   ] 

(* arguments/flags used only in the gui *)	
let gui_specific_arguments = [
	("--gui", Arg.Set enable_gui, "enable GUI"); 
	]
	
(* all hip's arguments and flags *)	
let hip_arguments = common_arguments @ hip_specific_arguments 

(* all sleek's arguments and flags *)	
let sleek_arguments = common_arguments @ sleek_specific_arguments 

(* all arguments and flags used in the gui*)	
let gui_arguments = common_arguments @ hip_specific_arguments @ gui_specific_arguments