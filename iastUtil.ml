
open Globals

module F = Iformula
module P = Ipure
module Err = Error
module CP = Cpure

open Iast

(********************************)
let transform_exp 
    (e:exp) 
    (init_arg:'b)
    (f:'b->exp->(exp * 'a) option)  
    (f_args:'b->exp->'b)
    (comb_f:'a list -> 'a) 
    (zero:'a) 
    : (exp * 'a) =
  let rec helper (in_arg:'b) (e:exp) :(exp* 'a) =	
    match (f in_arg e) with
    | Some e1 -> e1
    | None  -> 
      let n_arg = f_args in_arg e in 
      match e with	
      | Assert _ 
      | BoolLit _ 
      | Break _
      | Continue _ 
      | Debug _ 
      | Dprint _ 
      | Empty _ 
      | FloatLit _ 
      | IntLit _
      | Java _ 
      | Null _ 
      | This _ 
      | Time _ 
      | Unfold _ 
      | Var _ -> (e,zero)
      | Assign b ->
        let e1,r1 = helper n_arg b.exp_assign_lhs  in
        let e2,r2 = helper n_arg b.exp_assign_rhs  in
        (Assign { b with exp_assign_lhs = e1; exp_assign_rhs = e2;},(comb_f [r1;r2]))
      | Binary b -> 
        let e1,r1 = helper n_arg b.exp_binary_oper1  in
        let e2,r2 = helper n_arg b.exp_binary_oper2  in
        (Binary {b with exp_binary_oper1 = e1; exp_binary_oper2 = e2;},(comb_f [r1;r2]))
      | Bind b -> 
        let e1,r1 = helper n_arg b.exp_bind_body  in     
        (Bind {b with exp_bind_body = e1; },r1)
      | Block b -> 
        let e1,r1 = helper n_arg b.exp_block_body  in     
        (Block {b with exp_block_body = e1;},r1)
      | CallRecv b -> 
        let e1,r1 = helper n_arg b.exp_call_recv_receiver  in     
        let ler = List.map (helper n_arg) b.exp_call_recv_arguments in    
        let e2l,r2l = List.split ler in
        let r = comb_f (r1::r2l) in
        (CallRecv {b with exp_call_recv_receiver = e1;exp_call_recv_arguments = e2l;},r)
      | CallNRecv b -> 
        let ler = List.map (helper n_arg) b.exp_call_nrecv_arguments in    
        let e2l,r2l = List.split ler in
        let r = comb_f r2l in
        (CallNRecv {b with exp_call_nrecv_arguments = e2l;},r)
      | Cast b -> 
        let e1,r1 = helper n_arg b.exp_cast_body  in  
        (Cast {b with exp_cast_body = e1},r1)
      | Catch b -> 
	let e1,r1 = helper n_arg b.exp_catch_body in
  	(Catch {b with exp_catch_body = e1},r1)
      | Cond b -> 
        let e1,r1 = helper n_arg b.exp_cond_condition in
        let e2,r2 = helper n_arg b.exp_cond_then_arm in
        let e3,r3 = helper n_arg b.exp_cond_else_arm in
        let r = comb_f [r1;r2;r3] in
        (Cond {b with
          exp_cond_condition = e1;
          exp_cond_then_arm = e2;
          exp_cond_else_arm = e3;},r)
      | Finally b ->
	let e1,r1 = helper n_arg b.exp_finally_body in
	(Finally {b with exp_finally_body=e1},r1)
      | Label (l,b) -> 
        let e1,r1 = helper n_arg b in
        (Label (l,e1),r1)
      | Member b -> 
        let e1,r1 = helper n_arg b.exp_member_base in
        (Member {b with exp_member_base = e1;},r1)
      | New b -> 
        let el,rl = List.split (List.map (helper n_arg) b.exp_new_arguments) in
        (New {b with exp_new_arguments = el},(comb_f rl))
      | Raise b -> (match b.exp_raise_val with
        | None -> (e,zero)
        | Some body -> 
          let e1,r1 = helper n_arg body in
          (Raise {b with exp_raise_val = Some e1},r1))
      | Return b->(match b.exp_return_val with
        | None -> (e,zero)
        | Some body -> 
          let e1,r1 = helper n_arg body in
          (Return {b with exp_return_val = Some e1},r1))
      | Seq b -> 
        let e1,r1 = helper n_arg  b.exp_seq_exp1 in 
        let e2,r2 = helper n_arg  b.exp_seq_exp2 in 
        let r = comb_f [r1;r2] in
        (Seq {b with exp_seq_exp1 = e1;exp_seq_exp2 = e2;},r)
      | Try b -> 
        let ecl = List.map (helper n_arg) b.exp_catch_clauses in
        let fcl = List.map (helper n_arg) b.exp_finally_clause in
        let tb,r1 = helper n_arg b.exp_try_block in
        let catc, rc = List.split ecl in
        let fin, rf = List.split fcl in
        let r = comb_f (r1::(rc@rf)) in
        (Try {b with
          exp_try_block = tb;
          exp_catch_clauses = catc;
          exp_finally_clause = fin;},r)
      | Unary b -> 
        let e1,r1 = helper n_arg b.exp_unary_exp in
        (Unary {b with exp_unary_exp = e1},r1)
      | ConstDecl b -> 
        let l = List.map (fun (c1,c2,c3)-> 
          let e1,r1 = helper n_arg c2 in
          ((c1,e1,c3),r1))b.exp_const_decl_decls in
        let el,rl = List.split l in
        let r = comb_f rl in
        (ConstDecl {b with exp_const_decl_decls=el},r) 
      | VarDecl b -> 
        let ll = List.map (fun (c1,c2,c3)-> match c2 with
          | None -> ((c1,None,c3),zero)
          | Some s -> 
            let e1,r1 = helper n_arg s in
            ((c1,Some e1, c3),r1)) b.exp_var_decl_decls in 
        let dl,rl =List.split ll in
        let r = comb_f rl in
        (VarDecl {b with exp_var_decl_decls = dl},r)
      | While b -> 
        let wrp,r = match b.exp_while_wrappings with
          | None -> (None,zero)
          | Some s -> 
            let wrp,r = helper n_arg s in
            ((Some wrp),r) in
        let ce,cr = helper n_arg b.exp_while_condition in
        let be,br = helper n_arg b.exp_while_body in
        let r = comb_f [r;cr;br] in
        (While {b with
          exp_while_condition = ce;
          exp_while_body = be;
          exp_while_wrappings = wrp},r) in
  helper init_arg e

  (*this maps an expression by passing an argument*)
let map_exp_args (e:exp) (arg:'a) (f:'a -> exp -> exp option) (f_args: 'a -> exp -> 'a) : exp =
  let f1 ac e = push_opt_void_pair (f ac e) in
  fst (transform_exp e arg f1 f_args voidf ())

  (*this maps an expression without passing an argument*)
let map_exp (e:exp) (f:exp->exp option) : exp = 
  (* fst (transform_exp e () (fun _ e -> push_opt_void_pair (f e)) idf2  voidf ()) *)
  map_exp_args e () (fun _ e -> f e) idf2 

  (*this computes a result from expression passing an argument*)
let fold_exp_args (e:exp) (init_a:'a) (f:'a -> exp-> 'b option) (f_args: 'a -> exp -> 'a) (comb_f: 'b list->'b) (zero:'b) : 'b =
  let f1 ac e = match (f ac e) with
    | Some r -> Some (e,r)
    | None ->  None in
  snd(transform_exp e init_a f1 f_args comb_f zero)
 
  (*this computes a result from expression without passing an argument*)
let fold_exp (e:exp) (f:exp-> 'b option) (comb_f: 'b list->'b) (zero:'b) : 'b =
  fold_exp_args e () (fun _ e-> f e) voidf2 comb_f zero

  (*this iterates over the expression and passing an argument*)
let iter_exp_args (e:exp) (init_arg:'a) (f:'a -> exp-> unit option) (f_args: 'a -> exp -> 'a) : unit =
  fold_exp_args  e init_arg f f_args voidf ()

  (*this iterates over the expression without passing an argument*)
let iter_exp (e:exp) (f:exp-> unit option)  : unit =  iter_exp_args e () (fun _ e-> f e) voidf2

  (*this computes a result from expression passing an argument with side-effects*)
let fold_exp_args_imp (e:exp)  (arg:'a) (imp:'c ref) (f:'a -> 'c ref -> exp-> 'b option)
  (f_args: 'a -> 'c ref -> exp -> 'a) (f_imp: 'c ref -> exp -> 'c ref) (f_comb:'b list->'b) (zero:'b) : 'b =
  let fn (arg,imp) e = match (f arg imp e) with
    | Some r -> Some (e,r)
    | None -> None in
  let fnargs (arg,imp) e = ((f_args arg imp e), (f_imp imp e)) in
  snd(transform_exp e (arg,imp) fn fnargs f_comb zero)

  (*this iterates over the expression and passing an argument*)
let iter_exp_args_imp e (arg:'a) (imp:'c ref) (f:'a -> 'c ref -> exp -> unit option)
  (f_args: 'a -> 'c ref -> exp -> 'a) (f_imp: 'c ref -> exp -> 'c ref) : unit =
  fold_exp_args_imp e arg imp f f_args f_imp voidf ()
  
  
let local_var_decl (e:exp):(ident*typ*loc) list = 
  let f e = match e with
      | ConstDecl b->
        let v_list = List.map (fun (c1,_,l)-> (c1,b.exp_const_decl_type,l)) b.exp_const_decl_decls in
        Some (v_list)
      | VarDecl b -> 
        let v_list = List.map (fun (c1,_,l)-> (c1,b.exp_var_decl_type,l)) b.exp_var_decl_decls in
        Some (v_list)
      | Seq _ -> None
      | _ -> Some([]) in
  (*snd (transform_exp e () f idf2 comb_f []) *)
  fold_exp e f  (List.concat) []
 
(**
find the var decls of a block and add them into exp_block_local_vars
**)
let rec float_var_decl (e:exp) : exp  = 
  let f e = match e with
    | Block b->
      let e = float_var_decl b.exp_block_body in
      let decl_list = local_var_decl e in
      let ldups = Util.find_dups_f (fun (c1,_,_)(c2,_,_)-> (String.compare c1 c2)=0) decl_list in
      let _ = if ldups<>[] then 
          Error.report_error 
            {Err.error_loc = b.exp_block_pos; 
             Err.error_text = 
                (String.concat "," (List.map (fun (c,_,pos)-> 
                  c ^ ", line " 
                  ^ (string_of_int pos.start_pos.Lexing.pos_lnum) 
                  ^ ", col "
                  ^ (string_of_int (pos.start_pos.Lexing.pos_cnum - pos.start_pos.Lexing.pos_bol))) ldups))
             ^ " is redefined in the current block"}
      in
      Some (Block {b with
        exp_block_body =e;
        exp_block_local_vars=decl_list;})
    | _ -> None 
  in map_exp e f  
(*
  let comb_f l = () in
  let (r,_) = transform_exp e () f idf2 comb_f () in
  r
*)
  
let float_var_decl_prog prog = 
  {prog with
      prog_proc_decls = List.map (fun c-> 
        {c with
          proc_body = match c.proc_body with
            | None -> None
            | Some bd -> Some (float_var_decl bd)}
      ) prog.prog_proc_decls;}


let float_var_decl_prog2 prog = 
  map_proc prog (fun c-> 
        {c with
          proc_body = match c.proc_body with
            | None -> None
            | Some bd -> Some (float_var_decl bd)})
       


(*

*)

        
     (*   
      let float_var = () in
  let proc_tr = (idf,idf,float_var) in
  transform_program (idf,idf,idf,idf,proc_tr,idf) prog 
let rec transform_seq e = 
 let rec lin e = match e with
  | Seq b -> (lin b.exp_seq_exp1) @(lin b.exp_seq_exp2)
  | _ -> [e] in
 let rec folder l = match l with
  | [t]-> t
  | h::t-> Seq {
              exp_seq_exp1 = h;
              exp_seq_exp2 = folder t;
              exp_seq_pos = no_pos;} in
 match e with
  | Seq _ -> 
    let l = lin e in
    let l = List.map (transform_exp transform_seq) l in 
    (Some (folder l),None)
  | _ -> (None,None)
 *)
  (*
let push (stk:('a) list ref) (el:'a) : () = 
  stk:= (e1::!stk)
let pop (stk:('a) list ref) :'a =
  let h = List.hd !stk in
  stk:=(List.tl !stk);
  h
let new_stack () : ('a list) list ref = ref []
  
let check_use_before_declare (e:exp) : () =
  let  global = pop stk in
  let comb_f l = () in
  let rec helper (e:exp) = 
    transform f comb_f () e   
  
  and f e = match e with
      | ConstDecl b->
        (List.iter (fun (c,e,pos) -> 
          let _ = if (List.mem c decl_lst) then           
           Error.report_error 
              {Err.error_loc = b.pos; 
               Err.error_text = (String.concat "," (List.map (fun (c,_,pos)-> 
                  c^", line " ^ (string_of_int pos.start_pos.Lexing.pos_lnum) ^", col "^
                                (string_of_int (pos.start_pos.Lexing.pos_cnum - pos.start_pos.Lexing.pos_bol))) ldups))^" is redefined in the current block"}in
          
          helper e;
          decl_lst := c::!decl_lst) b.exp_const_decl_decls)
      | VarDecl b -> 
        List.iter (fun (c,e,pos) ->
         let _ = if (List.mem c decl_lst) then           
           Error.report_error 
              {Err.error_loc = pos; 
               Err.error_text = (String.concat "," (List.map (fun (c,_,pos)-> 
                  c^", line " ^ (string_of_int pos.start_pos.Lexing.pos_lnum) ^", col "^
                                (string_of_int (pos.start_pos.Lexing.pos_cnum - pos.start_pos.Lexing.pos_bol))) ldups))^" is redefined in the current block"}in
          (match e with
            | None -> ()
            | Some s -> helper s); decl_lst := c::!decl_lst) b.exp_var_decl_decls 
      | Block b ->  check_use_before_declare b.exp_block_local_var (Util.difference (prev_decl_lst@decl_lst) block_var)
      | Bind b -> 
         let _ = if (List.mem b.exp_bind_bound_var l) && (not (List.mem b.exp_bind_bound_var (prev_decl_lst @!decl_lst))) then
         Error.report_error 
              {Err.error_loc = exp_bind_pos; 
               Err.error_text = (String.concat "," (List.map (fun (c,_,pos)-> 
                  c^", line " ^ (string_of_int pos.start_pos.Lexing.pos_lnum) ^", col "^
                                (string_of_int (pos.start_pos.Lexing.pos_cnum - pos.start_pos.Lexing.pos_bol))) ldups))^
              " bind var " ^b.exp_bind_bound_var^" used before declare"}in
        let stored_decl = !decl_lst in
        decl_lst :=
 (*
  { exp_bind_bound_var : ident;
				 exp_bind_fields : ident list;
				 exp_bind_body : exp;
				 exp_bind_path_id : control_path_id;
				 exp_bind_pos : loc }
      
 
 
 
      if (b in l) & !(b in decl)
          error "used before declared"
      push decl
      decl=decl+fields
      let free = helper bind_body 
      pop decl
      return ((b+free)-l)
         
  *)
        
      if (List.mem b.exp_bind_bound_var l) 
        if (List.mem b.exp_bind_bound_var l) && (not (List.mem b.exp_bind_bound_var !decl_lst)) 
          then 
           Error.report_error 
              {Err.error_loc = b.exp_bind_pos; 
               Err.error_text = b.exp_bind_bound_var^" used before declaration "
               
               
      
      
      | Try
      | Var b ->
       { exp_var_name : ident;
				exp_var_pos : loc }
      | _ -> None in
  helper e
    

*)

(*
let rec exp_to_right_seq_assoc e =  e *)(*match e with
  | Assert _ -> e
  | Assign b -> Assign {b with  
                  exp_assign_lhs = exp_to_right_seq_assoc b.exp_assign_lhs;
                  exp_assign_rhs = exp_to_right_seq_assoc b.exp_assign_rhs;}
  | Binary b -> Binary {b with
                  exp_binary_oper1 : exp;
				   exp_binary_oper2 : exp;
				   }
  | Bind of exp_bind
  | Block of exp_block
  | BoolLit of exp_bool_lit
  | Break of exp_break
  | CallRecv of exp_call_recv
  | CallNRecv of exp_call_nrecv
  | Cast of exp_cast
  | Cond of exp_cond
  | ConstDecl of exp_const_decl
  | Continue of exp_continue
  | Debug of exp_debug
  | Dprint of exp_dprint
  | Empty of loc
  | FloatLit of exp_float_lit
  | IntLit of exp_int_lit
  | Java of exp_java
  | Label of ((control_path_id * path_label) * exp)
  | Member of exp_member
  | New of exp_new
  | Null of loc
  | Raise of exp_raise 
  | Return of exp_return
  | Seq of exp_seq
  | This of exp_this
  | Time of (bool*string*loc)
  | Try of exp_try
  | Unary of exp_unary
  | Unfold of exp_unfold
  | Var of exp_var
  | VarDecl of exp_var_decl
  | While of exp_while  *)
  (*
  
let proc_to_right_seq_assoc proc =match proc.proc_body with
  | None  -> proc
  | Some b -> {proc with proc_body = Some (exp_to_right_seq_assoc b)} 
let to_right_seq_assoc prog = {prog with prog_proc_decls=List.map proc_to_right_seq_assoc prog.prog_proc_decls}

(*****************************************)
(*****************************************)
let map_proc_of_prog (prog:prog_decl) (f_p : proc_decl -> proc_decl) : prog_decl =
  { prog with
    prog_proc_decls = List.map (f_p) prog.prog_proc_decls;
  }

let fold_proc_of_prog
    (prog:prog_decl)
    (f_p : proc_decl -> 'b) 
    (f_comb: 'b -> 'b -> 'b) 
    (zero:'b) 
    : 'b =
  List.fold_left (fun x p -> f_comb (f_p p) x) zero prog.prog_proc_decls

let iter_proc_of_prog (prog:prog_decl) (f_p : proc_decl -> unit) : unit =
  fold_proc prog (f_p) (fun _ _ -> ()) ()

let float_var_decl_proc proc : proc_decl =
  { proc with
    proc_body = match proc.proc_body with
    | None -> None
    | Some bd -> Some (float_var_decl bd)
  }
    
let float_var_decl_proc_of_prog prog =
  map_proc_of_prog prog float_var_decl_proc

(*
  this maps an expression without passing an argument
*)
let map_exp (e:exp) (f:exp->exp option) : exp =
  transform_exp e () (fun _ e -> f e) (fun _ _ -> ()) (fun _ -> ()) ()

(*
  this maps an expression by passing an argument
*)
let map_exp_args 
    (e:exp) 
    (arg:'a) 
    (f:'a->exp->exp option)
    (f_args:'a->exp->'a)
    : exp = 
  let f1 ac e = 
    match (f ac e) with
    | Some e1 -> Some (e1, ())
    | None -> None
  in
  let comb_f _ = () in
  transform_exp e arg f1 f_args comb_f ()

(*
  this computes a result from expression
  without passing an argument
*)
let fold_exp 
    (e:exp) 
    (f:exp -> 'b option)
    (combin_f:'b list -> 'b)
    (zero:'b) 
    : 'b =
  let f1 e _ = match (f e) with
    | Some r -> Some (e, r)
    | None -> None
  in
  let f_args _ _ = () in
  transform_exp e () f1 f_args comb_f zero

(*
  this computes a result from expression by
  passing an argument 
*)
let fold_exp_args 
    (e:exp) 
    (arg:'a) 
    (f:'a -> exp-> 'b option)
    (f_args: 'a -> exp -> 'a)
    (f_comb: 'b list -> 'b) 
    (zero:'b) 
    : 'b =
  let f1 ac e = match (f ac e) with
    | Some r -> Some (e,r)
    | None -> None
  in
  snd (transform_exp e arg f1 f_args f_comb zero) 

*)



(**** guan ****)
module H = Hashtbl

module Ident = struct
    type t = ident
    let compare = compare
end
    
module IdentSet = Set.Make(Ident)
  
let to_IS (l : ident list) : IdentSet.t  =
  List.fold_left (fun a e -> IdentSet.add e a) (IdentSet.empty) l

let from_IS (s : IdentSet.t) : (ident list)  =
  IdentSet.elements s

let rec union_all (l : IdentSet.t list) : IdentSet.t =
  match l with
	[] -> IdentSet.empty
  | _  -> IdentSet.union (List.hd l) (union_all (List.tl l))

module IS = IdentSet

let string_of_IS (s : IS.t) : string =
  "{ " ^ String.concat ", " (IdentSet.elements s) ^ " }"

let compose f g a = f (g a)
let ex_args f a b = f b a
let three1 (a,b,c) = a
let three2 (a,b,c) = b
let three3 (a,b,c) = c

let rec check_exp_if_use_before_declare
    (e:exp) ((local,global):IS.t*IS.t) (stk:IS.t ref) : unit =
  let f_args (local, global) stk e = (match e with
    | Bind b ->
      (IS.empty, union_all [to_IS b.exp_bind_fields; !stk; global]) (* inner blk *)
    | Block b ->
      let three1 (a,_,_) = a in
      let lvars0 = List.map three1 b.exp_block_local_vars in
      let lvars = to_IS lvars0 in
      (lvars, union_all [!stk; global]) (* new blk *)
    | Catch b -> 
      let gv = union_all [!stk;global] in
        (match b.exp_catch_var with
        | None ->  (IS.empty, gv)
        | Some v ->
          (IS.empty, IS.add v gv)
        )
    | Seq b -> (local, global)
    | _ -> (local, union_all [!stk; global])) (* inner block *) 
  in
  let f_imp stk e = 
    match e with
    | Seq b -> stk
    | VarDecl b ->
      let three1 (a,_,_) = a in
      let vars0 = List.map three1 b.exp_var_decl_decls in
      let vars = to_IS vars0 in
      stk := union_all [vars; !stk]; stk
    | _ -> let ef = ref IS.empty in ef
  in
  let f (local, global) stk e = 
    match e with
    | ConstDecl b ->
      let helper (v,e,_) = 
        check_exp_if_use_before_declare e (local, global) stk;
        stk := IS.add v !stk;
        ()
      in
      Some (List.iter helper b.exp_const_decl_decls)
    | VarDecl b ->
      let helper (v,e,_) = 
        (match e with 
        | None -> ()
        | Some e0 ->  
          check_exp_if_use_before_declare e0 (local, global) stk;
        );
        stk := IS.add v !stk;
        ()
      in
      Some (List.iter helper b.exp_var_decl_decls)
    | Bind b ->
      let v = b.exp_bind_bound_var in
      let pos = b.exp_bind_pos in
      let gvs = union_all [global; !stk] in
      if not (IS.mem v gvs) 
      then 
        if (IS.mem v local) 
        then
        Error.report_error 
        {Err.error_loc = pos;
         Err.error_text = v ^ ", line " 
         ^ (string_of_int pos.start_pos.Lexing.pos_lnum) ^", col "
         ^ (string_of_int (pos.start_pos.Lexing.pos_cnum 
                           - pos.start_pos.Lexing.pos_bol))
         ^" is used before declared"}
        else 
          Error.report_error 
            {Err.error_loc = pos;
             Err.error_text = v ^ ", line " 
             ^ (string_of_int pos.start_pos.Lexing.pos_lnum) ^", col "
             ^ (string_of_int (pos.start_pos.Lexing.pos_cnum 
                               - pos.start_pos.Lexing.pos_bol))
             ^" is not declared"}
      else Some ()
      
    | Var x ->
      let v = x.exp_var_name in
      let pos = x.exp_var_pos in
      let gvs = IS.union global !stk in
      if not (IS.mem v gvs) 
      then 
        if (IS.mem v local) 
        then
          (*let _ = print_endline ("local var:"^string_of_IS local) in*)
        Error.report_error 
        {Err.error_loc = pos;
         Err.error_text = v ^ ", line " 
         ^ (string_of_int pos.start_pos.Lexing.pos_lnum) ^", col "
         ^ (string_of_int (pos.start_pos.Lexing.pos_cnum 
                           - pos.start_pos.Lexing.pos_bol))
         ^" is used before declared"}
        else 
          (*let _ = print_endline ("local var:"^string_of_IS local) in*)
          Error.report_error 
            {Err.error_loc = pos;
             Err.error_text = v ^ ", line " 
             ^ (string_of_int pos.start_pos.Lexing.pos_lnum) ^", col "
             ^ (string_of_int (pos.start_pos.Lexing.pos_cnum 
                               - pos.start_pos.Lexing.pos_bol))
             ^" is not declared"}
      else Some ()
    | _ -> None
  in iter_exp_args_imp e (local,global) stk f f_args f_imp


(*
let subst_of_ident_with_bool (subs:(ident,ident) H.t) i0 : ident * bool = 
  try 
    H.find subs i0, true
  with Not_found -> i0, false


let to_HS a b = 
  let hs = H.create 10 in
  List.iter2 (H.add hs) a b;
  hs
let combine_of_h h1 h2 = 
  H.iter (H.add h1) h2;
  h2
let is_empty_of_h h= 
  H.length h = 0
let from_H h = 
  let r = ref [] in
  let fun0 a b = 
    r := (a,b) :: !r 
  in
  H.iter fun0 h;
  !r


let new_naming (vs:IS.t) : ((ident, ident) H.t) = 
  let vs1 = from_IS vs in
  let fvs2 = List.map new_name_var vs1 in
  to_HS vs1 fvs2
*)

(* apply substitution to an id *)
let subst_of_ident_with_bool (subs:(ident *ident) list) (id:ident) 
    : ident * bool =
  try
    List.assoc id subs, true
  with
  Not_found -> id, false

(* intersection of two lists of ids *)
let intersect (lst1:'a list) (lst2:'a list) : 'a list =
  List.filter (fun x -> List.mem x lst2) lst1

let new_name_var v = 
  v ^ "_" ^ string_of_int (fresh_int ())

(* make new renaming substitution that avoids name clash *)
let new_naming (lst:ident list) : (ident * ident) list =
  List.map (fun x -> (x,new_name_var x (* fresh name *))) lst


let rename_struc_formula subs1 f = 
  let fun0 (a,b) = [((a,Primed),(b,Primed));((a,Unprimed),(b,Unprimed))] in
  let subs2 = List.concat (List.map fun0 subs1) in
  F.subst_struc subs2 f

let rename_formula subs1 f = 
  let fun0 (a,b) = [((a,Primed),(b,Primed));((a,Unprimed),(b,Unprimed))] in
  let subs2 = List.concat (List.map fun0 subs1) in
  F.subst subs2 f


(* bvas - have been declared vars
   subs - substitution list - pair of vars list
*)
let rec rename_exp (e:exp) ((bvars,subs):(IS.t)*((ident * ident) list)) : exp = 
  let f_args (bvars, subs) e =
    match e with
    | Bind b ->
      (union_all [to_IS b.exp_bind_fields; bvars], subs)
    | Block b ->
      let lvars0 = List.map three1 b.exp_block_local_vars in
      let lvars = to_IS lvars0 in
      (union_all [lvars; bvars], subs)
    | Catch b ->
      let x = b.exp_catch_var in
      (match x with
      | None -> (bvars, subs)
      | Some v -> (IS.add v bvars, subs)
      )
    | _ -> (bvars, subs)
  in 
  let f (bvars, subs) e = 
    match e with 
    | Assert f -> 
      let ft1 = 
        match f.exp_assert_asserted_formula with 
        | None -> None
        | Some (sf, bl) -> Some (rename_struc_formula subs sf, bl)
      in
      let fa1 = 
        match f.exp_assert_assumed_formula with
        | None -> None
        | Some fml -> Some (rename_formula subs fml)
      in
      Some (Assert 
              { f with
                exp_assert_asserted_formula = ft1;
                exp_assert_assumed_formula = fa1;
              })
    | Var b -> Some (Var {b with exp_var_name = fst (subst_of_ident_with_bool subs b.exp_var_name);})
    | VarDecl b ->
      let helper (v, e, l) = 
        let e1 = 
          (match e with
          | None -> None
          | Some e0 -> Some (rename_exp e0 (bvars, subs))
          )
        in
        let (v1, b) = subst_of_ident_with_bool subs v in
        (v1, e1, l)
      in
      Some (VarDecl {b with exp_var_decl_decls = List.map helper b.exp_var_decl_decls})
    | ConstDecl b ->
      let helper (v,e,l) = 
        let e1 = (rename_exp e (bvars, subs)) in
        let (v1, b) = subst_of_ident_with_bool subs v in
        (v1, e1, l)
      in
      Some (ConstDecl {b with exp_const_decl_decls = List.map helper b.exp_const_decl_decls})

    | Bind b ->
      let x = b.exp_bind_bound_var in
      let flds = to_IS b.exp_bind_fields in
      let e = b.exp_bind_body in
      let clash_fields = IS.inter bvars flds in
      let clash_subs = new_naming (from_IS clash_fields) in
      let new_fields = List.map (compose fst (subst_of_ident_with_bool clash_subs)) b.exp_bind_fields in
      let (nx, nb) = subst_of_ident_with_bool subs x in
      if (nb || not (IS.is_empty clash_fields)) 
      then 
        let new_e = rename_exp e (IS.union flds bvars, subs @ clash_subs) in
        (Some (Bind 
                 { b with 
                   exp_bind_bound_var = nx;
                   exp_bind_fields = new_fields;
                   exp_bind_body = new_e;
                 }))
      else None
   
    | Block b ->
      let lvars = to_IS (List.map three1 b.exp_block_local_vars) in
      let clash_lvars = IS.inter bvars lvars in
      if (IS.is_empty clash_lvars) then None
      else 
        let clash_subs = new_naming (from_IS clash_lvars) in
        let new_vars = 
          let fun0 (a,b,c) = (fst (subst_of_ident_with_bool clash_subs a), b, c) in
          List.map fun0 b.exp_block_local_vars in
        let e = b.exp_block_body in
        let new_e = rename_exp e (IS.union lvars bvars, subs @ clash_subs) in
        Some (Block 
                { b with
                  exp_block_local_vars = new_vars;
                  exp_block_body = new_e;
                })

    | Catch b -> begin
      match b.exp_catch_var with 
      | None -> None
      | Some x -> 
        let e = b.exp_catch_body in
        if (IS.mem x bvars) then None
        else 
          let clash_subs = new_naming ([x]) in
          let nx = fst (subst_of_ident_with_bool clash_subs x) in
          let ne = rename_exp e (IS.add x bvars, subs @ clash_subs) in
          Some (Catch 
                  { b with
                    exp_catch_var = Some nx;
                    exp_catch_body = ne;
                  })
    end
    | _ -> None
  in
  map_exp_args e (bvars, subs) f f_args




let rename_proc gvs proc : proc_decl = 
  let pv v = v.param_name in
  let pargs = to_IS (List.map pv proc.proc_args) in
  let clash_vars = IS.inter pargs gvs in
  let clash_subs = new_naming (from_IS clash_vars) in

  let nargs = 
    let fun0 v = 
      {v with param_name = fst (subst_of_ident_with_bool clash_subs v.param_name);} 
    in 
    List.map fun0 proc.proc_args 
  in

  let nsps1 = rename_struc_formula clash_subs proc.proc_static_specs in
  let nspd1 = rename_struc_formula clash_subs proc.proc_dynamic_specs in

  let nas1 = to_IS (List.map pv nargs) in
  let bvars = IS.union gvs nas1 in
  let ne = match proc.proc_body with 
    | None -> None
    | Some e0 -> 
      let e = rename_exp e0 (bvars,clash_subs) in
      (*print_endline (Iprinter.string_of_exp e); *)
      check_exp_if_use_before_declare e (IS.empty, IS.union nas1 gvs) (ref IS.empty); 
      Some ( e )
  in
  { proc with
    proc_args = nargs;
    proc_static_specs = nsps1;
    proc_dynamic_specs = nspd1;
    proc_body = ne;
  }


let rename_prog prog : prog_decl = 
  let gvs = to_IS (List.concat (
    let fun0 (a,b,c) = a in
    let fun1 a = List.map fun0 a.exp_var_decl_decls in
    List.map fun1 prog.prog_global_var_decls))
  in 
  let prog = float_var_decl_prog prog in
  map_proc prog (rename_proc gvs) 



(********free var************)
let rec find_free_read_write (e:exp) bound 
    : (IS.t * IS.t) = (* read set, write set *)
  let f_args bound e = 
    match e with
    | Bind b ->
      let flds = to_IS b.exp_bind_fields in
      IS.union flds bound 
    | Block b ->
      let lvars = to_IS (List.map three1 b.exp_block_local_vars) in
      IS.union lvars bound
    | Catch b ->
      let x = b.exp_catch_var in
      (match x with 
      | None -> bound
      | Some v -> IS.add v bound
      )
    | _ -> bound 
  in
  let f bound e = 
    match e with
    | Var b ->
      let v = b.exp_var_name in
      if (IS.mem v bound) then None
      else Some (IS.singleton v, IS.empty)
    | Assign b ->
      let el = b.exp_assign_lhs in
      let er = b.exp_assign_rhs in
      (match el with 
      | Var x ->
        let v = x.exp_var_name in
        if (IS.mem v bound) then None
        else let (rs,ws) = find_free_read_write er bound in
             Some (rs, IS.add v ws)
      | _ -> None
      )
    | Unary b ->
        (match b.exp_unary_op with
        | OpUMinus | OpNot -> None
	| OpPreInc | OpPreDec | OpPostInc | OpPostDec ->
            (match b.exp_unary_exp with
            | Var b0 ->
                let v = b0.exp_var_name in
                if (IS.mem v bound) then None
                else Some (IS.empty, IS.singleton v)
            | _ -> None
            )
        )   
    | _ -> None
  in
  let f_comb s =
    let s1,s2 = List.split s in
    union_all s1, union_all s2 
  in
  fold_exp_args e bound f f_args f_comb (IS.empty, IS.empty)
      

let find_free_vars (e:exp) bound : IS.t = 
  let (rs,ws) = find_free_read_write e bound in
  IS.union rs ws


let find_free_read_write_of_proc proc : (IS.t * IS.t) = 
  let pv v = v.param_name in
  let pargs = to_IS (List.map pv proc.proc_args) in
  let (rs,ws) = 
    match proc.proc_body with
    | None -> (IS.empty, IS.empty)
    | Some e -> find_free_read_write e pargs
  in 
  (IS.diff rs ws, ws)

module MNV = struct
  type t = ident
  let compare = compare
  let hash = Hashtbl.hash
  let equal = ( = )
end
module NG = Graph.Imperative.Digraph.Concrete(MNV)
module NGComponents = Graph.Components.Make(NG)
module NGPathCheck = Graph.Path.Check(NG)

let addin_callgraph_of_exp (cg:NG.t) exp mnv : unit = 
  let f e = 
    match e with
    | CallRecv e ->
      NG.add_edge cg mnv e.exp_call_recv_method;
      Some ()
    | CallNRecv e ->
      NG.add_edge cg mnv e.exp_call_nrecv_method;
      Some ()
    | _ -> None
  in
  iter_exp exp f 


let addin_callgraph_of_proc cg proc : unit = 
  match proc.proc_body with
  | None -> ()
  | Some e -> addin_callgraph_of_exp cg e proc.proc_name

let callgraph_of_prog prog : NG.t = 
  let cg = NG.create () in
  let pn pc = pc.proc_name in
  let mns = List.map pn prog.prog_proc_decls in
  List.iter (NG.add_vertex cg) mns;
  List.iter (addin_callgraph_of_proc cg) prog.prog_proc_decls;
  cg

let method_lookup prog n : proc_decl = 
  let fun0 proc = proc.proc_name = n in
  List.find fun0 prog.prog_proc_decls


let to_HS a b = 
  let hs = H.create 10 in
  List.iter2 (H.add hs) a b;
  hs
let combine_of_h h1 h2 = 
  H.iter (H.add h1) h2;
  h2
let is_empty_of_h h= 
  H.length h = 0
let from_H h = 
  let r = ref [] in
  let fun0 a b = 
    r := (a,b) :: !r 
  in
  H.iter fun0 h;
  !r

let ngscc_list cg = NGComponents.scc_list cg 
let ngscc cg = NGComponents.scc cg

let create_progfreeht_of_prog prog = 
  let ht = H.create 10 in
  let fun0 proc = 
    H.add ht proc.proc_name (find_free_read_write_of_proc proc)
  in 
  List.iter fun0 prog.prog_proc_decls;
  ht


let merge0 ht ms : ((ident list) * (IS.t * IS.t)) = 
  let rs1s, ws1s = List.split (List.map (H.find ht) ms) in
  let rws = union_all rs1s, union_all ws1s in
  (*  let fun0 m = H.replace ht m rws in
      List.iter fun0 ms; *)
  ms,rws

let merge1 ht (mss:(string list list)) : (((ident list) * (IS.t * IS.t)) list) = 
  List.map (merge0 ht) mss


let cmbn_rw a b = 
  (IS.union (fst a) (fst b)), (IS.union (snd a) (snd b))


let push_freev0 cg ms0 (mss0:(((ident list) * (IS.t * IS.t)) list)) = 
  let predms0 = List.concat (List.map (NG.pred cg) (fst ms0)) in
  let fun0 (ms1:((ident list) * (IS.t * IS.t))) = 
    if (intersect predms0 (fst ms1)) = [] 
    then
      ms1 
    else       
      let rw1 = cmbn_rw (snd ms0) (snd ms1) in
      (fst ms1, rw1)
  in
  List.map fun0 mss0
    
let rec push_freev1 cg mss0 = 
  match mss0 with
  | [] -> []
  | [a] -> [a]
  | (a::b) ->
    a :: push_freev1 cg (push_freev0 cg a b)

let update_ht0 ht mss0 = 
  let fun0 ms0 =
    let (r,w) = snd ms0 in
    let rw = (IS.diff r w, w) in
    let fun1 n = H.replace ht n rw in
    List.iter fun1 (fst ms0)
  in
  List.iter fun0 mss0




(*

*)
(*
let is_

let merge1 ht mss = 
*)

let ht_of_gvdef gvdefs =
  let h = H.create 10 in
  let fun0 gv = 
    let t = gv.exp_var_decl_type in
    List.iter (ex_args (H.add h) t) 
      (List.map three1 gv.exp_var_decl_decls)
  in 
  List.iter fun0 gvdefs; 
  h 

let param_of_v ht md lc nm = 
  let t = H.find ht nm in
  match t with 
  | Prim _ ->
      { param_type = t;
        param_name = nm;
        param_mod = md;
        param_loc = lc;
      }
  | _ ->
      { param_type = t;
        param_name = nm;
        param_mod = RefMod;
        param_loc = lc;
      }

let add_free_var_to_proc gvdefs ht proc = 
  let ght = ht_of_gvdef gvdefs in
  let (rs,ws) = H.find ht proc.proc_name in
  (*let _ = print_endline ("proc rs:"^ string_of_IS rs) in
    let _ = print_endline ("proc ws:"^ string_of_IS ws) in*)
  let fun0 md is = 
    List.map (param_of_v ght md proc.proc_loc) (from_IS is)
  in
  let ars = fun0 NoMod rs in
  let aws = fun0 RefMod ws in
  { proc with
    proc_args = proc.proc_args @ ars @ aws;
  }



let exp_of_var l v = Var
  { exp_var_name = v;
    exp_var_pos = l;
  }

let exp_of_is l vs = 
  List.map (exp_of_var l) (from_IS vs)

let exp_of_rws l (rs,ws) = 
  (*let _ = print_endline ("exp rs:"^ string_of_IS rs) in
    let _ = print_endline ("exp ws:"^ string_of_IS ws) in*)
  exp_of_is l rs @ exp_of_is l ws

let addin_callargs_of_exp ht e : exp = 
  let f e = 
    match e with
    | CallRecv e ->
        let cn = e.exp_call_recv_method in
        let rws = H.find ht cn in
        let loc = e.exp_call_recv_pos in
        let eags = exp_of_rws loc rws in
        Some (CallRecv 
                { e with
                  exp_call_recv_arguments = 
                    e.exp_call_recv_arguments @ eags;
                })

    | CallNRecv e ->
        let cn = e.exp_call_nrecv_method in
        let rws = H.find ht cn in
        let loc = e.exp_call_nrecv_pos in
        let eags = exp_of_rws loc rws in
        Some (CallNRecv 
                { e with
                  exp_call_nrecv_arguments = 
                    e.exp_call_nrecv_arguments @ eags;
                })

    | _ -> None
  in
  map_exp e f 


let map_body_of_proc f proc = 
  { proc with
      proc_body = match proc.proc_body with
      | None -> None
      | Some e -> Some (f e)
          ;
  }


let add_globalv_to_mth_prog prog = 
  let cg = callgraph_of_prog prog in
  let ht = create_progfreeht_of_prog prog in
  let scclist = List.rev (ngscc_list cg) in
  let sccfv = merge1 ht scclist in
  let mscc = push_freev1 cg sccfv in
  let _ = update_ht0 ht mscc in
  let newsig_procs = 
    List.map (add_free_var_to_proc prog.prog_global_var_decls ht) 
      prog.prog_proc_decls in
  let new_procs = 
    List.map (map_body_of_proc (addin_callargs_of_exp ht))
      newsig_procs in
  { prog with
      prog_proc_decls = new_procs;
  }

  
let pre_process_of_iprog prog = 
  let prog = float_var_decl_prog prog in
  let prog = rename_prog prog in
  let prog = add_globalv_to_mth_prog prog in
  prog





(*

(e:exp) ((local,global):IS.t*IS.t) (stk:IS.t ref) : unit =

*)