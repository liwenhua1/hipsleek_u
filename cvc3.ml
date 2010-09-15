open Globals
module CP = Cpure

let log_cvc3_formula = ref false
let cvc3_log = ref stdout
let infilename = "input.cvc3." ^ (string_of_int (Unix.getpid ()))
let resultfilename = "result.txt." ^ (string_of_int (Unix.getpid()))
let cvc3_command = "cvc3 " ^ infilename ^ " > " ^ resultfilename

let set_log_file fn =
  log_cvc3_formula := true;
  if fn = "" then
	cvc3_log := open_out "formula.cvc"
  else if Sys.file_exists fn then
	failwith "--log-cvc3: file exists"
  else
	begin
		cvc3_log := open_out fn (* opens fn for writing and returns an output channel for fn - cvc3_log is the output channel*);
		output_string !cvc3_log cvc3_command
	end

let run_cvc3 (input : string) : unit =
  begin 
	let chn = open_out infilename in
	  output_string chn input;
	  close_out chn;
	  ignore (Sys.command cvc3_command)
  end
  
let log_answer_cvc3 (answer : string) : unit =
	 if !log_cvc3_formula then 
	  begin
		output_string !cvc3_log answer;
		flush !cvc3_log
	  end
		
let rec cvc3_of_spec_var (sv : CP.spec_var) = match sv with
  | CP.SpecVar (_, v, p) -> v ^ (if CP.is_primed sv then "PRMD" else "")

and cvc3_of_exp a = match a with
  | CP.Null _ -> "0"
  | CP.Var (sv, _) -> cvc3_of_spec_var sv
  | CP.IConst (i, _) -> string_of_int i
  | CP.FConst _ -> failwith ("[cvc3ite.ml]: ERROR in constraints (float should not appear here)")
  | CP.Add (a1, a2, _) ->  (cvc3_of_exp a1) ^ " + " ^ (cvc3_of_exp a2)
  | CP.Subtract (a1, a2, _) ->  (cvc3_of_exp a1) ^ " - " ^ (cvc3_of_exp a2)
  | CP.Mult (a1, a2, _) -> (cvc3_of_exp a1) ^ " * " ^ (cvc3_of_exp a2)
  | CP.Div (a1, a2, _) -> failwith ("[cvc3.ml]: divide is not supported.")
  | CP.Max _ 
  | CP.Min _ -> failwith ("cvc3.cvc3_of_exp: min/max should not appear here")
  | CP.Bag ([], _) -> ""
  | CP.Bag _ | CP.BagUnion _ | CP.BagIntersect _ | CP.BagDiff _ ->
  	  failwith ("[cvc3.ml]: ERROR in constraints (set should not appear here)");
  | CP.List _ | CP.ListCons _ | CP.ListHead _ | CP.ListTail _ | CP.ListLength _ | CP.ListAppend _ | CP.ListReverse _ ->
      failwith ("Lists are not supported in cvc3")
  
and cvc3_of_b_formula b = match b with
  | CP.BConst (c, _) -> if c then "(TRUE)" else "(FALSE)"
  (* | CP.BVar (sv, _) -> cvc3_of_spec_var sv *)
  | CP.BVar (sv, _) -> (cvc3_of_spec_var sv) ^ " = 1"
  | CP.Lt (a1, a2, _) -> (cvc3_of_exp a1) ^ " < " ^ (cvc3_of_exp a2)
  | CP.Lte (a1, a2, _) -> (cvc3_of_exp a1) ^ " <= " ^ (cvc3_of_exp a2)
  | CP.Gt (a1, a2, _) -> (cvc3_of_exp a1) ^ " > " ^ (cvc3_of_exp a2)
  | CP.Gte (a1, a2, _) -> (cvc3_of_exp a1) ^ " >= " ^ (cvc3_of_exp a2)
  | CP.Eq (a1, a2, _) -> (cvc3_of_exp a1) ^ " = " ^ (cvc3_of_exp a2)
  | CP.Neq (a1, a2, _) -> 
	  if CP.is_null a2 then 
		(cvc3_of_exp a1) ^ " > 0"
	  else if CP.is_null a1 then 
		(cvc3_of_exp a2) ^ " > 0"
	  else
		(cvc3_of_exp a1) ^ " /= " ^ (cvc3_of_exp a2)
  | CP.EqMax (a1, a2, a3, _) ->
	  let a1str = cvc3_of_exp a1 in
	  let a2str = cvc3_of_exp a2 in
	  let a3str = cvc3_of_exp a3 in
		"((" ^ a2str ^ " >= " ^ a3str ^ " AND " ^ a1str ^ " = " ^ a2str ^ ") OR (" 
		^ a3str ^ " > " ^ a2str ^ " AND " ^ a1str ^ " = " ^ a3str ^ "))"
  | CP.EqMin (a1, a2, a3, _) ->
	  let a1str = cvc3_of_exp a1 in
	  let a2str = cvc3_of_exp a2 in
	  let a3str = cvc3_of_exp a3 in
		"((" ^ a2str ^ " >= " ^ a3str ^ " AND " ^ a1str ^ " = " ^ a3str ^ ") OR (" 
		^ a3str ^ " > " ^ a2str ^ " AND " ^ a1str ^ " = " ^ a2str ^ "))"
  | CP.BagIn (v, e, l)			-> " in(" ^ (cvc3_of_spec_var v) ^ ", " ^ (cvc3_of_exp e) ^ ")"
  | CP.BagNotIn (v, e, l)	-> " NOT(in(" ^ (cvc3_of_spec_var v) ^ ", " ^ (cvc3_of_exp e) ^"))"
  | CP.BagSub (e1, e2, l)	-> " subset(" ^ cvc3_of_exp e1 ^ ", " ^ cvc3_of_exp e2 ^ ")"
  | CP.BagMax _ | CP.BagMin _ -> failwith ("cvc3_of_b_formula: BagMax/BagMin should not appear here.\n")
  | CP.ListIn _
  | CP.ListNotIn _
  | CP.ListAllN _
  | CP.ListPerm _ -> failwith ("Lists are not supported in cvc3")
	  
and cvc3_of_sv_type sv = match sv with
  | CP.SpecVar (CP.Prim Bag, _, _) -> "SET"
  | CP.SpecVar (CP.Prim Bool, _, _) -> "INT" (* "BOOLEAN" *)
  | _ -> "INT"

and cvc3_of_formula f = match f with
  | CP.BForm (b,_) -> "(" ^ (cvc3_of_b_formula b) ^ ")"
  | CP.And (p1, p2, _) -> "(" ^ (cvc3_of_formula p1) ^ " AND " ^ (cvc3_of_formula p2) ^ ")"
  | CP.Or (p1, p2,_, _) -> "(" ^ (cvc3_of_formula p1) ^ " OR " ^ (cvc3_of_formula p2) ^ ")"
  | CP.Not (p,_, _) ->
	  begin
		match p with
		  | CP.BForm (CP.BVar (bv, _),_) -> (cvc3_of_spec_var bv) ^ " = 0"
		  | _ -> "(NOT (" ^ (cvc3_of_formula p) ^ "))"
	  end
  | CP.Forall (sv, p,_, _) ->
	  let typ_str = cvc3_of_sv_type sv in
  		"(FORALL (" ^ (cvc3_of_spec_var sv) ^ ": " ^ typ_str ^ "): " ^ (cvc3_of_formula p) ^ ")"
  | CP.Exists (sv, p, _,_) -> 
	  let typ_str = cvc3_of_sv_type sv in
  		"(EXISTS (" ^ (cvc3_of_spec_var sv) ^ ": " ^ typ_str ^ "): " ^ (cvc3_of_formula p) ^ ")"

(*
  split a list of spec_vars to three lists:
  - int vars
  - boolean vars
  - set/bag vars
*)
and split_vars (vars : CP.spec_var list) = (vars, [], [])

and imply_raw (ante : CP.formula) (conseq : CP.formula) : bool option =
  let ante_fv = CP.fv ante in
  let conseq_fv = CP.fv conseq in
  let all_fv = CP.remove_dups (ante_fv @ conseq_fv) in
  let int_vars, bool_vars, bag_vars = split_vars all_fv in
  let bag_var_decls = 
	if Util.empty bag_vars then "" 
	else (String.concat ", " (List.map cvc3_of_spec_var bag_vars)) ^ ": SET;\n" in
  let int_var_decls = 
	if Util.empty int_vars then "" 
	else (String.concat ", " (List.map cvc3_of_spec_var int_vars)) ^ ": INT;\n" in
  let bool_var_decls =
	if Util.empty bool_vars then ""
	else (String.concat ", " (List.map cvc3_of_spec_var bool_vars)) ^ ": INT;\n" in 
  let var_decls = bool_var_decls ^ bag_var_decls ^ int_var_decls in
  let ante_str =
	"ASSERT (" ^ (cvc3_of_formula ante) ^ ");\n" in
  let ante_str_new = "a_dummy, b_dummy: INT;\nASSERT a_dummy = b_dummy; \n" ^ ante_str in	
  let conseq_str =  "QUERY (" ^ (cvc3_of_formula conseq) ^ ");\n" in
	(* talk to CVC3 *)
  let f_cvc3 = Util.break_lines ((*predicates ^*) var_decls ^ ante_str_new ^ conseq_str) in
	if !log_cvc3_formula then begin
	  output_string !cvc3_log "%%% imply\n";
	  (*output_string !cvc3_log (Cprinter.string_of_pure_formula conseq);
	  output_string !cvc3_log "\n";*)
	  output_string !cvc3_log f_cvc3;
	  flush !cvc3_log
	end;
	run_cvc3 f_cvc3;
	let chn = open_in resultfilename in
	let res_str = input_line chn in
	let n = String.length "Valid." in
	let l = String.length res_str in
	  if l >= n then
		let tmp = String.sub res_str 0 n in
		  if tmp = "Valid." then 
			(
			 close_in chn; 
			 log_answer_cvc3 "%%%Res: Valid\n\n";
			 Some true)
		  else
			let n1 = String.length "Invalid." in
			  if l >= n1 then
				let tmp1 = String.sub res_str 0 n1 in
				  if tmp1 = "Invalid." then
					begin
					  (
					   close_in chn; 
					   log_answer_cvc3 "%%%Res: Invalid\n\n";
					   Some false)
					end
				  else
					(
						close_in chn; 
						log_answer_cvc3  "%%%Res: Unknown\n\n";
						None)
			  else
				(
				  close_in chn; 
				  log_answer_cvc3  "%%%Res: Unknown\n\n";
				  None)
	  else 
		((*print_string "imply_raw:Unknown 3";*) 
		  close_in chn; 
		  if !log_cvc3_formula then log_answer_cvc3 "%%%Res: Unknown\n";
		  None)
		  
and imply (ante : CP.formula) (conseq : CP.formula) : bool =
  let result0 = imply_raw ante conseq in
  let result = match result0 with
	| Some f -> f
	| None -> begin
		false  (* unknown is assumed to be false *)
		  (*failwith "CVC3 is unable to perform implication check"*)
	  end
  in
	begin
	  try
		ignore (Sys.remove infilename);
		ignore (Sys.remove resultfilename)
	  with
		| e -> ignore e
	end;
	result

and is_sat_raw (f : CP.formula) (sat_no : string) : bool option =
  let all_fv = CP.remove_dups (CP.fv f) in
  let int_vars, bool_vars, bag_vars = split_vars all_fv in
  let bag_var_decls = 
	if Util.empty bag_vars then "" 
	else (String.concat ", " (List.map cvc3_of_spec_var bag_vars)) ^ ": SET;\n" in
  let int_var_decls = 
	if Util.empty int_vars then "" 
	else (String.concat ", " (List.map cvc3_of_spec_var int_vars)) ^ ": INT;\n" in
  let bool_var_decls =
	if Util.empty bool_vars then ""
	else (String.concat ", " (List.map cvc3_of_spec_var bool_vars)) ^ ": INT;\n" in (* BOOLEAN *)
  let var_decls = bool_var_decls ^ bag_var_decls ^ int_var_decls in
  let f_str = cvc3_of_formula f in
  let query_str = "CHECKSAT (" ^ f_str ^ ");\n" in
	(* talk to CVC3 *)
  let f_cvc3 = Util.break_lines ( (*predicates ^*) var_decls (* ^ f_str *) ^ query_str) in
	if !log_cvc3_formula then begin
	  output_string !cvc3_log ("%%% is_sat " ^ sat_no ^ "\n");
	  output_string !cvc3_log f_cvc3;
	  flush !cvc3_log
	end;
	run_cvc3 f_cvc3;
	let chn = open_in resultfilename in
	let res_str = input_line chn in
	  begin
		let n = String.length "Satisfiable." in
		let l = String.length res_str in
		  if l >= n then
			let tmp = String.sub res_str 0 n in
			  if tmp = "Satisfiable." then 
				begin
				  close_in chn;
				  log_answer_cvc3  ("%%%Res: Satisfiable\n\n");
				  Some true
				end
			  else
				let n1 = String.length "Unsatisfiable." in
				  if l >= n1 then
					let tmp1 = String.sub res_str 0 n1 in
					  if tmp1 = "Unsatisfiable." then
						(
						 close_in chn; 
						 log_answer_cvc3 ("%%%Res: Unsatisfiable\n\n");
						 Some false)
					  else begin
						(
						 close_in chn; 
						 log_answer_cvc3  ("%%%Res: Unknown\n\n");
						 None)
					  end
				  else begin
					(
					 close_in chn; 
					 log_answer_cvc3  ("%%%Res: Unknown\n\n");
					 None)
				  end
		  else begin
			(
			 close_in chn; 
			 log_answer_cvc3("%%%Res: Unknown\n\n");
			 None)
		  end
	  end
		
and is_sat (f : CP.formula) (sat_no : string) : bool =
  let result0 = is_sat_raw f sat_no in
  let result = match result0 with
	  | Some f -> f
	  | None -> begin
	  	  if !log_cvc3_formula then begin
	  		output_string !cvc3_log "%%% is_sat --> true (from unknown)\n"
	  	  end;
	  	  (*failwith "CVC3 is unable to perform satisfiability check"*)
	  	  true
	  	end
  in
	begin
	  try
		ignore (Sys.remove infilename); 
		ignore (Sys.remove resultfilename)
	  with
		| e -> ignore e
	end;
	result