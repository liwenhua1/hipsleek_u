(** pretty printing for formula and cast *)

open Format
open Globals 
(* open Exc.ETABLE_NFLOW *)
open Exc.GTable
open Lexing 
open Cast 
open Cformula
open Mcpure_D
open Gen.Basic 
(* open Label_only *)
open Printf

module LO = Label_only.LOne
module LO2 = Label_only.Lab2_List
module P = Cpure
module MP = Mcpure


let is_short n = (n==2);;

let is_medium n = (n==1);;

let is_long n = (n==0);;

(* (\* pretty printing for primitive types *\) *)
(* let string_of_prim_type = function  *)
(*   | Bool          -> "boolean" *)
(*   | Float         -> "float" *)
(*   | Int           -> "int" *)
(*   | Void          -> "void" *)
(*   | BagT t        -> "bag("^(string_of_prim_type t)^")" *)
(*   | TVar t        -> "TVar["^(string_of_int t)^"]" *)
(*   | List          -> "list" *)
(* ;; *)




(** the formatter that fmt- commands will use *)
let fmt = ref (std_formatter)
let pr_mem = ref true

(** primitive formatter comands *)
let fmt_string x = pp_print_string (!fmt) x
let fmt_bool x = pp_print_bool (!fmt) x
let fmt_int x = pp_print_int (!fmt) x
let fmt_float x = pp_print_float (!fmt) x
let fmt_char x = pp_print_char (!fmt) x
let fmt_space x = pp_print_space (!fmt) x
let fmt_break x = pp_print_break (!fmt) x
let fmt_cut x = pp_print_cut (!fmt) x
let fmt_set_margin x = pp_set_margin (!fmt) x
let fmt_print_newline x = pp_print_newline (!fmt) x
let fmt_print_flush x = pp_print_flush (!fmt) x
let fmt_open_box n = pp_open_box (!fmt) n
let fmt_open_vbox n = pp_open_vbox (!fmt) n
let fmt_open_hbox n = pp_open_hbox (!fmt) n
let fmt_close_box x = pp_close_box (!fmt) x
let fmt_open x = fmt_open_box x
let fmt_close x = fmt_close_box x
(* test cvs commit*)

let texify l nl = if !Globals.texify then l else nl

let pr_int i = fmt_int i

let pr_pair_aux pr_1 pr_2 (a,b) =
  (* fmt_string "("; *)
  pr_1 a; fmt_string ":";
  pr_2 b
  (* ;fmt_string ")" *)

let pr_opt f x = match x with
    | None -> fmt_string "None"
    | Some v -> (fmt_string "Some("; (f v); fmt_string ")")
  
(* let pr_opt lst (f:'a -> ()) x:'a = *)
(*   if not(Gen.is_empty lst) then f a *)
(*   else (); *)

(** polymorphic conversion to a string with -i- spaces identation*)
let poly_string_of_pr_gen (i:int) (pr: 'a -> unit) (e:'a) : string =
  (* let _ = print_string ("############ commit test") in *)
  let old_fmt = !fmt in
  begin
    (* fmt := str_formatter; *)
    let b = (Buffer.create 80) in
    begin
      fmt := formatter_of_buffer (b);
      fmt_open_box 0;
      fmt_string (String.make i ' ');
      pr e;
      fmt_close();
      fmt_print_flush();
      (* (let s = flush_str_formatter()in *)
      (* fmt := old_fmt; s) *)
      (let s = Buffer.contents(b) in
      fmt := old_fmt; s)
    end
  end    

(** conversion to a string with a 1-space indentation *)    
let poly_string_of_pr (pr: 'a -> unit) (e:'a) : string =
  poly_string_of_pr_gen 1 pr e

(** polymorphic function for debugging printer *)
let poly_printer_of_pr (crt_fmt: Format.formatter) (pr: 'a -> unit) (e:'a) : unit =
  let old_fmt = !fmt in
  begin
    fmt := crt_fmt;
    pr e;
    fmt := old_fmt;
  end    


(** shorter op code used internally *)
let op_add_short = "+" 
let op_sub_short = "-" 
let op_mult_short = "*" 
let op_div_short = "/" 
let op_max_short = "mx" 
let op_min_short = "mi" 
let op_union_short = "U" 
let op_intersect_short = "I" 
let op_diff_short = "D"
let op_and_short = "&"  
let op_or_short = "|"  
let op_not_short = "!"  
let op_star_short = "*"  
let op_starminus_short = "-*" 
let op_phase_short = ";"  
let op_conj_short = "U*"  
let op_conjsep_short = "/&\\"  
let op_conjstar_short = "&*" 
let op_conjconj_short = "&" 
let op_f_or_short = "or"  
let op_lappend_short = "APP"
let op_cons_short = ":::"

(** op code that will be printed *)
let op_add = "+" 
let op_sub = "-" 
let op_mult = "*" 
let op_div = "/" 
let op_max = "max" 
let op_min = "min" 
let op_union = "union" 
let op_intersect = "intersect" 
let op_diff = "-" 
let op_lt = if not (!print_html) then "<" else "&lt;"
let op_lte = "<=" 
let op_gt = if not (!print_html) then ">" else "&gt;"
let op_gte = ">=" 
let op_sub_ann = "<:" 
let op_eq = "=" 
let op_neq = "!=" 
let op_and = " & "  
let op_or = " | "  
let op_not = "!"  
let op_star = " * "  
let op_starminus = " -* " 
let op_phase = " ; "  
let op_conj = " U* "  
let op_conjstar = " &* " 
let op_conjconj = " & " 
let op_f_or = "or" 
let op_lappend = "app"
let op_cons = ":::"


(** add a bracket around e if is simple yields false *)
(* 
  hard to read wo brackets..
   [ G(x_25) ::=  x_25::node<flted_13_14,right>@M&0<=flted_13_14 | flted_13_14=0] 
*)
let pr_bracket (isSimple:'a -> bool) (pr_elem:'a -> unit) (e:'a) : unit =
 if (isSimple e) then pr_elem e
 else (fmt_string "("; pr_elem e; fmt_string ")")

(** invoke f_open ; f_elem x1; f_sep .. f_sep; f_elem xn; f_close *)
let pr_list_open_sep (f_open:unit -> unit) 
    (f_close:unit -> unit) (f_sep:unit->unit) (f_empty:unit->unit)
    (f_elem:'a -> unit) (xs:'a list) : unit =
  let rec helper xs = match xs with
    | [] -> failwith "impossible to be [] in pr_list_open_sep"
    | [x] -> (f_elem x)
    | y::ys -> (f_elem y; f_sep(); helper ys) 
  in match xs with
    | [] -> f_empty()
    | xs -> f_open(); (helper xs); f_close() 

let pr_list_open_sep (f_open:unit -> unit) 
    (f_close:unit -> unit) (f_sep:unit->unit) (f_empty:unit->unit)
    (f_elem:'a -> unit) (xs:'a list) : unit =
  Debug.no_1 "pr_list_open_sep" string_of_int (fun _ -> "?") (fun _ -> pr_list_open_sep  (f_open:unit -> unit) 
    (f_close:unit -> unit) (f_sep:unit->unit) (f_empty:unit->unit)
    (f_elem:'a -> unit) xs) (List.length xs)

(** @param sep = "SAB"-space-cut-after-before,"SA"-space cut-after,"SB" -space-before 
 "AB"-cut-after-before,"A"-cut-after,"B"-cut-before, "S"-space, "" no-cut, no-space*)
let pr_op_sep_gen sep op =
  if sep="A" then (fmt_string op; fmt_cut())
  else if sep="B" then (fmt_cut();fmt_string op)
  else if sep="AB" then (fmt_cut();fmt_string op;fmt_cut())
  else if sep="SB" then (fmt_space();fmt_string op;fmt_string(" "))
  else if sep="SA" then (fmt_string(" "); fmt_string op; fmt_space())
  else if sep="SAB" then (fmt_space();fmt_string op; fmt_space())
  else if sep="S" then fmt_string (" "^op^" ")
  else fmt_string op (* assume sep="" *)

(** print op and a break after *)
let pr_cut_after op = pr_op_sep_gen "A" op
  (* fmt_string (" "^op); fmt_space()  *)

  (** print op and a break after *)
let pr_cut_before op = pr_op_sep_gen "SB" op
  (* fmt_space(); fmt_string (op^" ") *)

  (** print op and a break after *)
let pr_cut_after_no op =  pr_op_sep_gen "A" op
  (* fmt_string op; fmt_cut() *) 

  (** print op and a break after *)
let pr_cut_before_no op =  pr_op_sep_gen "B" op
  (* fmt_cut(); fmt_string op *)

(*   (\* print op and a break after *\) *)
(* let pr_vbrk_after op = (fun () -> fmt_string (op); fmt_cut() ) *)

(* (\* print op and a break before *\) *)
(* let pr_vbrk_before op = (fun () -> fmt_cut(); fmt_string (op);  ) *)

(* (\* print op and a break before *\) *)
(* let pr_brk_before op = (fun () -> (\* fmt_cut() ;  *\)(fmt_string op)) *)

(* let pr_list_sep x = pr_list_open_sep (fun x -> x) (fun x -> x) x  *)

(* let pr_list x = pr_list_sep fmt_space x;; *)

(* let pr_list_comma x = pr_list_sep (fun () -> fmt_string ","; fmt_space()) x  *)

(* let pr_list_args op x = pr_list_open_sep  *)
(*   (fun () -> fmt_open 1; fmt_string op; fmt_string "(") *)
(*   (fun () -> fmt_string ")"; fmt_close();)  *)
(*   fmt_space x *)

(** @param box_opt Some(s,i) for boxing options "V" -vertical,"H"-horizontal,"B"-box 
    @param sep_opt (Some s) for breaks at separator where "B"-before, "A"-after, "AB"-both  *) 
let pr_args_gen f_empty box_opt sep_opt op open_str close_str sep_str f xs =
  let f_o x = match x with
    | Some(s,i) -> 
          if s="V" then fmt_open_vbox i
          else if s="H" then fmt_open_hbox ()
          else  fmt_open_box i; (* must be B *)
    | None -> () in
  let f_c x = match x with
    | Some(s,i) -> fmt_close();
    | None -> () in
  let opt_cut () = match box_opt with
    | Some(s,i) -> 
          if s="V" then fmt_cut()
          else  ()
    | None -> () in
  let f_s x sep = match x with
    | Some s -> if s="A" then (fmt_string sep_str; fmt_cut())
      else if s="AB" then (fmt_cut(); fmt_string sep_str; fmt_cut()) 
      else (fmt_cut(); fmt_string sep_str)  (* must be Before *)
    | None -> fmt_string sep_str in 
  pr_list_open_sep 
      (fun () -> (f_o box_opt); fmt_string op; fmt_string open_str; opt_cut())
      (fun () -> opt_cut(); fmt_string close_str; (f_c box_opt)) 
      (fun () -> f_s sep_opt sep_str) 
      f_empty  f xs

 (** invoke pr_args_gen  *)   
let pr_args box_opt sep_opt op open_str close_str sep_str f xs =
  pr_args_gen (fun () -> fmt_string (op^open_str^close_str) ) box_opt sep_opt op open_str close_str sep_str f xs

 (** invoke pr_args_gen and print nothing when xs  is empty  *)      
let pr_args_option box_opt sep_opt op open_str close_str sep_str f xs =
  pr_args_gen (fun () -> ()) box_opt sep_opt op open_str close_str sep_str f xs


(** @param box_opt (s,i) wrap a "V" (vertical),"H" (horizontal) or just a box *)    
let wrap_box box_opt f x =  
  let f_o (s,i) = 
    if s="V" then fmt_open_vbox i
    else if s="H" then fmt_open_hbox ()
    else  fmt_open_box i;
  in
    f_o box_opt; f x; fmt_close()

let pr_wrap_opt hdr (f: 'a -> unit) (x:'a option) =
  match x with
    | None -> ()
    | Some x ->
          begin
            fmt_cut();
            fmt_open_hbox ();
            fmt_string hdr;
            f x;
            fmt_close_box()
          end

(** if f e  is not true print with a cut in front of  hdr*)    
let pr_wrap_test hdr (e:'a -> bool) (f: 'a -> unit) (x:'a) =
  if (e x) then ()
  else 
    begin
      fmt_cut (); 
      fmt_open_hbox ();
      fmt_string hdr; 
      (* f x; *)
      wrap_box ("B",1) f x;
      fmt_close_box()
    end

let pr_wrap_test_nocut hdr (e:'a -> bool) (f: 'a -> unit) (x:'a) =
  if (e x) then ()
  else 
    begin
      let ff a = f a; fmt_string " " in
      fmt_open_hbox ();
      fmt_string hdr;
      (* f x; *)
      wrap_box ("B",1) ff x;
      fmt_close_box()
    end


(** if f e  is not true print with a cut in front of  hdr*)    
let pr_wrap (f: 'a -> unit) (x:'a) =
  begin
  fmt_open_hbox();
  f x;
  fmt_close_box()
  end

(** if f e  is not true print without cut in front of  hdr*)      
let pr_wrap_test_nocut hdr (e:'a -> bool) (f: 'a -> unit) (x:'a) =
  if (e x) then ()
  else (fmt_string hdr; (wrap_box ("B",0) f x))


(** print hdr , a cut and a boxed  f a  *)  
let pr_vwrap_naive_nocut hdr (f: 'a -> unit) (x:'a) =
  begin
    fmt_string (hdr); fmt_cut();
    wrap_box ("B",2) f  x
  end

(** call pr_wrap_naive_nocut with a cut in front of *)
let pr_vwrap_naive hdr (f: 'a -> unit) (x:'a) =
  begin
    fmt_cut();
     pr_vwrap_naive_nocut hdr f x;
  end

(** this wrap is to be used in a vbox setting
   if hdr is big and the size of printing exceeds
   margin, it will do a cut and indent before continuing
*)
let pr_vwrap_nocut hdr (f: 'a -> unit) (x:'a) =
  if (String.length hdr)>7 then
    begin
      let s = poly_string_of_pr_gen 0 f x in
      if (String.length s) < 70 then (* to improve *)
        fmt_string (hdr^s)
      else begin
        fmt_string hdr; 
        fmt_cut ();
	    (* fmt_string s; *)
        fmt_string " ";
        wrap_box ("B",0) f  x
      end
    end
  else  begin 
    fmt_string hdr; 
    wrap_box ("B",2) f  x
  end
 
(** call pr_wrap_nocut with a cut in front of*)    
let pr_vwrap hdr (f: 'a -> unit) (x:'a) =
  begin
    fmt_cut();
    pr_vwrap_nocut hdr f x
  end

(* let pr_args open_str close_str sep_str f xs =  *)
(*   pr_list_open_sep  *)
(*     (fun () -> (\* fmt_open 1; *\) fmt_string open_str) *)
(*     (fun () -> fmt_string close_str; (\* fmt_close(); *\))  *)
(*     (pr_brk_after sep_str) f xs *)

(*  let pr_args_vbox open_str close_str sep_str f xs =  *)
(*   pr_list_open_sep  *)
(*     (fun () -> fmt_open_vbox 1; fmt_string open_str) *)
(*     (fun () -> fmt_string close_str; fmt_close();)  *)
(*     (pr_vbrk_after sep_str) f xs *)

(* let pr_op_args op open_str close_str sep_str f xs =  *)
(*   pr_list_open_sep  *)
(*     (fun () -> (\* fmt_open 1; *\) fmt_string op; fmt_string open_str) *)
(*     (fun () -> fmt_string close_str; (\* fmt_close(); *\))  *)
(*     (pr_brk_after sep_str) f xs *)

(** print a tuple with cut after separator*)
let pr_tuple op f xs = pr_args None (Some "A") op "(" ")" "," f xs

(** print an angle list with cut after separator*)  
let pr_angle op f xs =
  if !print_html then
    pr_args None (Some "A") op  "&lt;" "&gt;" "," f xs
  else
    pr_args None (Some "A") op  "<" ">" "," f xs

let pr_sharp_angle op f xs =
  if !print_html then
    pr_args None (Some "A") op  "&lt&#9839;" "&gt&#9839;" "," f xs
  else
    pr_args None (Some "A") op  "<#" "#>" "," f xs

(** print a sequence with cut after separator*)  
let pr_seq op f xs = pr_args None (Some "A") op "[" "]" "; " f xs

(** print a sequence with cut after separator in a VBOX*)    
let pr_seq_vbox op f xs = pr_args (Some ("V",1)) (Some "A") op "[" "]" ";" f xs

(** print a sequence without cut and box *)    
let pr_seq_nocut op f xs = pr_args None None op "[" "]" ";" f xs

let pr_seq_option op f xs = pr_args_option None (Some "A") op "[" "]" ";" f xs

(** print a list with cut after separator*)    
let pr_list_none f xs = pr_args None (Some "A") "" "" "" "," f xs

 (** print a set with cut after separator*)  
let pr_set f xs = pr_args None (Some "A") "" "{" "}" "," f xs

let pr_coq_list f xs = pr_args None (Some "A") "" "[|" "|]" "," f xs

 (** print a set with cut after separator in a VBOX*)  
let pr_set_vbox f xs = pr_args (Some ("V",1)) (Some "A") "{" "}" "," f xs

(** print prefix op(x1..xn) but use x1 alone if n=1 *)
let pr_fn_args op f xs = match xs with
  | [x] -> f x
  | _ -> (pr_tuple op f xs)

(** print infix form : x1 op .. op xn *)
let pr_list_op sep f xs = pr_args None (Some "A") "" "" "" sep f xs
  
  (** print infix form : x1 op .. op xn *)
let pr_list_op_vbox sep f xs = 
  pr_args (Some ("V",0)) (Some "B") "" "" "" sep f xs

(**a list with a cut before separator *)  
let pr_list_op_none sep f xs = pr_args None (Some "B") "" "" "" sep f xs

(** print a list in a vbox and each element is in a box*)  
let pr_list_vbox_wrap sep f xs =
  if (String.length sep > 3) then
    pr_args (Some ("V",0)) (Some "AB") "" "" "" sep
      (fun x -> fmt_string " "; wrap_box ("B",0) f x) xs
  else   pr_args (Some ("V",0)) (Some "B") "" "" "" sep (wrap_box ("B",0) f) xs

 (**print f_1 op  f_2 and a space *)   
let pr_op_adhoc (f_1:unit -> unit) (op:string) (f_2:unit -> unit) =
  f_1(); fmt_string op ; f_2(); fmt_space()

(**print  f e1  op f e2 and a space *)
let pr_op (f:'a -> unit) (e1:'a) (op:string) (e2:'a)  =
  (f e1); fmt_string op ; (f e2); fmt_space()


(* let pr_op_sep   *)
(*     (pr_sep: unit -> unit )  *)
(*     (isSimple: 'a -> bool) *)
(*     (pr_elem: 'a -> unit) *)
(*     (x:'a) (y:'a)  *)
(*     =  (pr_bracket isSimple pr_elem x); pr_sep();  *)
(*        (pr_bracket isSimple pr_elem y) *)


(* let pr_op op = pr_op_sep (pr_brk_after op) *)

(* (\* let pr_call  (isSimple:'a->bool) (pr_elem: 'a -> unit) (fn:string) (args:'a list)   *\) *)
(* (\*     = fmt_string fn; (pr_list_args pr_elem args)   *\) *)

(* (\* this op printing has no break *\) *)
(* let pr_op f = pr_op_sep (fun () -> fmt_string " ") f *)

(* let pr_op_no f = pr_op_sep (fun () -> fmt_string " ") (fun x -> true) f *)

(* (\* this op printing allows break *\) *)
(* let pr_op_brk f = pr_op_sep fmt_space f *)

(* (\* this op do not require bracket *\) *)
(* let pr_op_brk_no f = pr_op_sep fmt_space (fun x -> true) f *)

(* let precedence (op:string) : int = *)
(*   match op with *)
(*   | "&" -> 0 *)
(*   | _ -> -1 *)
 

(* let is_no_bracket (op:string) (trivial:'a->bool)  *)
(*     (split:'a -> (string * 'a * 'a) option) (elem:'a) : bool  =  *)
(*   if (trivial elem) then true *)
(*   else  *)
(*     match (split elem) with *)
(*       | None -> false *)
(*       | Some (op2,_,_) ->  *)
(*          if (precedence op2) > (precedence op) then true *)
(*          else false *)
 

let string_of_typed_spec_var x = 
  match x with
    | P.SpecVar (t, id, p) -> id ^ (match p with | Primed -> "'" | Unprimed -> "" ) ^ ":" ^ ((string_of_typ t))

let string_of_spec_var x = 
  (* string_of_typed_spec_var x *)
  match x with
    | P.SpecVar (t, id, p) ->
    	  (* An Hoa : handle printing of holes *)
          let ts = if !print_type then ":"^(string_of_typ t) else "" in
    	  (* let real_id = if (id.[0] = '#') then "#" else id *)
          (* in  *)
          (id ^(match p with
            | Primed -> "'"
            | Unprimed -> "" )^ts)

let string_of_subst stt = pr_list (pr_pair string_of_spec_var string_of_spec_var) stt

(* let is_absent imm = *)
(*   match imm with *)
(*   | ConstAnn(Accs) -> true *)
(*   | _ -> false *)

let rec string_of_imm_helper imm = 
  match imm with
    | CP.NoAnn -> "@[]"
    | CP.ConstAnn(Accs) -> "@A"
    | CP.ConstAnn(Imm) -> "@I"
    | CP.ConstAnn(Lend) -> "@L"
    | CP.ConstAnn(Mutable) -> "" (* "@M" *)
    | CP.TempAnn(t) -> "@[" ^ (string_of_imm_helper t) ^ "]"
    | CP.TempRes(l,r) -> "@[" ^ (string_of_imm_helper l) ^ ", " ^ (string_of_imm_helper r) ^ "]"
    | CP.PolyAnn(v) -> "@" ^ (string_of_spec_var v)

let rec string_of_imm imm = 
  if not !print_ann then ""
  else string_of_imm_helper imm

let rec string_of_imm_ann imm = 
  match imm with
    | CP.PolyAnn(v) -> string_of_spec_var v
    | _             -> string_of_imm_helper imm

let rec string_of_typed_imm_ann imm = 
  match imm with
    | CP.PolyAnn(v) -> string_of_typed_spec_var v
    | _             -> string_of_imm_helper imm

let string_of_annot_arg ann = 
  match ann with
    | CP.ImmAnn imm -> string_of_imm_ann imm

let string_of_annot_arg_list ann_list = 
  pr_list string_of_annot_arg ann_list

let string_of_typed_annot_arg ann = 
  match ann with
    | CP.ImmAnn imm -> string_of_typed_imm_ann imm

let string_of_view_arg arg = 
  match arg with
    | CP.SVArg sv     -> string_of_spec_var sv
    | CP.AnnotArg ann -> string_of_annot_arg ann

let string_of_view_arg_list arg_list = 
  pr_list string_of_view_arg arg_list

let string_of_typed_annot_arg ann = 
  match ann with
    | CP.ImmAnn imm -> string_of_typed_imm_ann imm

let string_of_typed_view_arg arg = 
  match arg with
    | CP.SVArg sv     -> string_of_typed_spec_var sv
    | CP.AnnotArg ann -> string_of_typed_annot_arg ann

let string_of_derv dr = 
  if not !print_ann then ""
  else if dr then "@D" else ""

let smart_string_of_spec_var x = 
  match x with
    | CP.SpecVar(t,id,p) ->
          let n=String.length id in
          if n>=4 then 
            let s=String.sub id 0 4 in
            if s="Anon" then "_"
            else string_of_spec_var x
          else string_of_spec_var x

let pr_spec_var x = fmt_string (smart_string_of_spec_var x)

let pr_view_arg x = fmt_string (string_of_view_arg x)

let pr_annot_arg x = fmt_string (string_of_annot_arg x)

let pr_annot_arg_posn x = fmt_string ((pr_pair string_of_annot_arg string_of_int) x)

let pr_typed_spec_var x = fmt_string (* (string_of_spec_var x) *) (string_of_typed_spec_var x)

let pr_typed_spec_var_lbl (l,x) = 
  let s = 
    if LO.is_common l then ""
    else (LO.string_of l)^":"
  in fmt_string (s^(string_of_typed_spec_var x))

let pr_typed_view_arg_lbl (l,x) = 
  let s = 
    if LO.is_common l then ""
    else (LO.string_of l)^":"
  in fmt_string (s^(string_of_typed_view_arg x))

let pr_list_of_spec_var xs = pr_list_none pr_spec_var xs

let pr_list_of_view_arg xs = pr_list_none pr_view_arg xs

let pr_list_of_annot_arg xs = pr_list_none pr_annot_arg xs

let pr_list_of_annot_arg_posn xs = pr_list_none pr_annot_arg_posn xs
  
let pr_imm x = fmt_string (string_of_imm x)

let pr_derv x = fmt_string (string_of_derv x)

let string_of_ident x = x

let pr_ident x = fmt_string (string_of_ident x)


(** check if top operator of e is associative and 
   return its list of arguments if so *)
let exp_assoc_op (e:P.exp) : (string * P.exp list) option = 
  match e with
    | P.Add (e1,e2,_) -> Some (op_add_short,[e1;e2])
    | P.Mult (e1,e2,_) -> Some (op_mult_short,[e1;e2])
    | P.Max (e1,e2,_) -> Some (op_max_short,[e1;e2])
    | P.Min (e1,e2,_) -> Some (op_min_short,[e1;e2])
    | P.BagUnion (es,_) -> Some (op_union_short,es)
    | P.BagIntersect (es,_) -> Some (op_intersect_short,es)
    | _ -> None

(** check if exp can be printed without a parenthesis,
     e.g. trivial expr and prefix forms *)
let exp_wo_paren (e:P.exp) = 
  match e with
    | P.Null _ 
    | P.Var _ 
    | P.AConst _ 
    | P.IConst _ 
    | P.FConst _ | P.Max _ |   P.Min _ | P.BagUnion _ | P.BagIntersect _ | P.Tsconst _  -> true
    | _ -> false

let b_formula_assoc_op (e:P.b_formula) : (string * P.exp list) option = None

(* check if exp can be printed without a parenthesis,
     e.g. trivial expr and prefix forms *)
let b_formula_wo_paren (e:P.b_formula) =
  let (pf,_) = e in
  match pf with
    | P.BConst _ 
    | P.BVar _ | P.BagMin _ | P.BagMax _ -> true
    | _ -> false

let pure_formula_assoc_op (e:P.formula) : (string * P.formula list) option = 
  match e with
    | P.And (e1,e2,_) -> Some (op_and_short,[e1;e2])
    | P.Or (e1,e2,_,_) -> Some (op_or_short,[e1;e2])
    | _ -> None

(* check if exp can be printed without a parenthesis,
     e.g. trivial expr and prefix forms *)
let pure_formula_wo_paren (e:P.formula) = 
  match e with
    | P.Forall _ 
    | P.Exists _ | P.Not _ -> true
    | P.BForm (e1,_) -> true (* b_formula_wo_paren e1 *)
    (* | P.Or _ -> true  *)
    | P.And _ -> false (*Bach: change from true to false*) 
    | _ -> false

let pure_memoised_wo_paren (e: memo_pure) = false


let h_formula_assoc_op (e:h_formula) : (string * h_formula list) option = 
  match e with
    |Star ({h_formula_star_h1 = h1; h_formula_star_h2 = h2; h_formula_star_pos =_}) ->
       Some (op_star_short,[h1;h2])
    | _ -> None

(* check if exp can be printed without a parenthesis,
     e.g. trivial expr and prefix forms *)
let h_formula_wo_paren (e:h_formula) = 
  match e with
    | DataNode _ 
    | ViewNode _ 
    | Star _ 
	| HRel _ -> true
    | _ -> false


let formula_assoc_op (e:formula) : (string * formula list) option = 
  match e with
    |Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = _}) ->
       Some (op_f_or_short,[f1;f2])
    | _ -> None
	
let struc_formula_assoc_op (e:struc_formula) : (string * struc_formula list) option = None 
  (*match e with|EOr {formula_struc_or_f1 = f1; formula_struc_or_f2 = f2} -> Some (op_f_or_short,[f1;f2])| _ -> None*)

(* check if exp can be printed without a parenthesis,
     e.g. trivial expr and prefix forms *)
let formula_wo_paren (e:formula) = 
  match e with
    | Or _ -> true
    | Base _-> true
    | Exists _-> true
	
let struc_formula_wo_paren (e:struc_formula) = true

let ft_assoc_op (e:fail_type) : (string * fail_type list) option = 
  match e with
    | Or_Reason (f1,f2) -> Some (op_or_short,[f1;f2])
    | And_Reason (f1,f2) -> Some (op_and_short,[f1;f2])
    | Union_Reason (f1,f2) -> Some (op_union_short,[f1;f2])
    | Or_Continuation (f1,f2) -> Some (op_or_short,[f1;f2])
    | _ -> None

(* check if exp can be printed without a parenthesis,
     e.g. trivial expr and prefix forms *)
let ft_wo_paren (e:fail_type) = true

(** print a formula exp to formatter *)
let rec pr_formula_exp (e:P.exp) =
  let f_b e =  pr_bracket exp_wo_paren pr_formula_exp e in
  match e with
    | P.Null l -> fmt_string "null"
    | P.Var (x, l) -> fmt_string (string_of_spec_var x) (* fmt_string (string_of_typed_spec_var x) *)
    | P.Level (x, l) -> fmt_string ("level(" ^ (string_of_spec_var x) ^ ")")
    | P.IConst (i, l) -> fmt_int i
    | P.AConst (i, l) -> fmt_string (string_of_heap_ann i)
    | P.InfConst (i,l) -> let r = "\\inf" in fmt_string r
    | P.Tsconst (i,l) -> fmt_string (Tree_shares.Ts.string_of i)
	| P.Bptriple (t,l) -> fmt_string (pr_triple string_of_spec_var string_of_spec_var string_of_spec_var t)
    | P.FConst (f, l) -> fmt_string "FLOAT ";fmt_float f
    | P.Add (e1, e2, l) -> 
          let args = bin_op_to_list op_add_short exp_assoc_op e in
          pr_list_op op_add f_b args; (*fmt_string (string_of_pos l.start_pos);*)
    | P.Mult (e1, e2, l) -> 
          let args = bin_op_to_list op_mult_short exp_assoc_op e in
          pr_list_op op_mult f_b  args
    | P.Max (e1, e2, l) -> 
          let args = bin_op_to_list op_max_short exp_assoc_op e in
          pr_fn_args op_max pr_formula_exp args
    | P.Min (e1, e2, l) -> 
          let args = bin_op_to_list op_min_short exp_assoc_op e in
          pr_fn_args op_min pr_formula_exp  args
    | P.TypeCast (ty, e1, l) ->
        fmt_string ("(" ^ (Globals.string_of_typ ty) ^ ")");
        pr_formula_exp e1;
    | P.Bag (elist, l) 	-> 
        fmt_string ("{"); 
        pr_list_none pr_formula_exp elist;
        fmt_string ("}")
    | P.BagUnion (args, l) -> 
          let args = bin_op_to_list op_union_short exp_assoc_op e in
          pr_fn_args op_union pr_formula_exp args
    | P.BagIntersect (args, l) -> 
          let args = bin_op_to_list op_intersect_short exp_assoc_op e in
          pr_fn_args op_intersect pr_formula_exp args
    | P.Subtract (e1, e2, l) ->
          f_b e1; pr_cut_after op_sub; f_b e2
    | P.Div (e1, e2, l) ->
          f_b e1; pr_cut_after op_div ; f_b e2
    | P.BagDiff (e1, e2, l) -> 
          pr_formula_exp e1; pr_cut_after op_diff ; pr_formula_exp e2
    | P.List (elist, l) -> pr_coq_list pr_formula_exp elist 
    | P.ListAppend (elist, l) -> pr_tuple op_lappend pr_formula_exp elist
    | P.ListCons (e1, e2, l)  ->  f_b e1; pr_cut_after op_cons; f_b e2
    | P.ListHead (e, l)     -> fmt_string ("head("); pr_formula_exp e; fmt_string  (")")
    | P.ListTail (e, l)     -> fmt_string ("tail("); pr_formula_exp e; fmt_string  (")")
    | P.ListLength (e, l)   -> fmt_string ("len("); pr_formula_exp e; fmt_string  (")")
    | P.ListReverse (e, l)  -> fmt_string ("rev("); pr_formula_exp e; fmt_string  (")")
		| P.Func (a, i, l) -> fmt_string (string_of_spec_var a); fmt_string ("(");
		(match i with
			| [] -> ()
			| arg_first::arg_rest -> let _ = pr_formula_exp arg_first in 
				let _ = List.map (fun x -> fmt_string (","); pr_formula_exp x) arg_rest
		in fmt_string  (")"))
		| P.ArrayAt (a, i, l) -> fmt_string (string_of_spec_var a); fmt_string ("[");
		match i with
			| [] -> ()
			| arg_first::arg_rest -> let _ = pr_formula_exp arg_first in 
				let _ = List.map (fun x -> fmt_string (","); pr_formula_exp x) arg_rest
		in fmt_string  ("]") (* An Hoa *)
;;

let pr_formula_exp_list op l = match l with
	| [] -> ()
	| h::t -> pr_formula_exp h; List.iter (fun a-> fmt_string op;pr_formula_exp a) t 

let pr_formula_exp_w_ins (e,i) = pr_formula_exp e; 
  if not !print_ann then ()
  else if i = Globals.NI then fmt_string "@NI" else ()

let pr_formula_exp_w_ins_list l = match l with
	| [] -> ()
	| h::t -> pr_formula_exp_w_ins h; List.iter (fun a-> fmt_string ",";pr_formula_exp_w_ins a) t 
  
let pr_slicing_label sl =
  match sl with
	| None -> fmt_string ""
	| Some (il, lbl, el) ->
		fmt_string ("<" ^ (if il then "IL, " else ", ") ^ (string_of_int lbl) ^ ", ");
	    fmt_string ("[");
		pr_list_none pr_formula_exp el;
		fmt_string ("]");
		fmt_string (">")

let pr_var_measures (t_ann, ls1,ls2) = 
  let pr_s op f xs = pr_args None None op "[" "]" "," f xs in
  fmt_string (string_of_term_ann t_ann);
  pr_s "" pr_formula_exp ls1;
  if ls2!=[] then
    pr_set pr_formula_exp ls2
  else ()

let sort_exp a b =
  match a with
    | P.Var (v1,_) ->
          begin
            match b with
              | P.Var (v2,_) -> 
                    if (String.compare (string_of_spec_var v1) (string_of_spec_var v2))<=0 
                    then (a,b) 
                    else (b,a)
              | _ -> (a,b)
          end
    | _ ->
          begin
            match b with
              | P.Var v2 -> (b,a)
              | _ -> (a,b)
          end

let pr_xpure_view xp = match xp with
    { 
        CP.xpure_view_node = root ;
        CP.xpure_view_name = vname;
        CP.xpure_view_arguments = args;
    } ->
        let pr = string_of_spec_var in
        let rn,args_s = match root with
          | None -> ("", pr_list_round pr args)
          | Some v -> ((pr v)^"::", pr_list_angle pr args)
        in
        fmt_string ("XPURE("^rn^vname^args_s^")")

let string_of_xpure_view xpv = poly_string_of_pr pr_xpure_view xpv

(** print a b_formula  to formatter *)
let rec pr_b_formula (e:P.b_formula) =
  let pr_s op f xs = pr_args None None op "[" "]" "," f xs in
  let f_b e =  pr_bracket exp_wo_paren pr_formula_exp e in
  let f_b_no e =  pr_bracket (fun x -> true) pr_formula_exp e in
  let (pf,il) = e in
  (* pr_slicing_label il; *)
  match pf with
    | P.LexVar t_info -> 
      fmt_string (string_of_term_ann t_info.CP.lex_ann);
      pr_s "" pr_formula_exp t_info.CP.lex_exp
      (* ;if ls2!=[] then *)
      (*   pr_set pr_formula_exp ls2 *)
      (* else () *)
    | P.BConst (b,l) -> fmt_bool b 
    | P.XPure v ->  fmt_string (string_of_xpure_view v)
    | P.BVar (x, l) -> fmt_string (string_of_spec_var x)
    | P.Lt (e1, e2, l) -> f_b e1; fmt_string op_lt ; f_b e2
    | P.Lte (e1, e2, l) -> f_b e1; fmt_string op_lte ; f_b e2
    | P.Gt (e1, e2, l) -> f_b e1; fmt_string op_gt ; f_b e2
    | P.Gte (e1, e2, l) -> f_b e1; fmt_string op_gte ; f_b e2
    | P.SubAnn (e1, e2, l) -> f_b e1; fmt_string op_sub_ann ; f_b e2
    | P.Eq (e1, e2, l) -> 
          let (e1,e2) = sort_exp e1 e2 in
          f_b_no e1; fmt_string op_eq ; f_b_no e2
    | P.Neq (e1, e2, l) -> 
          let (e1,e2) = sort_exp e1 e2 in
          f_b e1; fmt_string op_neq ; f_b e2;(* fmt_string (string_of_pos l.start_pos);*)
    | P.EqMax (e1, e2, e3, l) ->   
          let arg2 = bin_op_to_list op_max_short exp_assoc_op e2 in
          let arg3 = bin_op_to_list op_max_short exp_assoc_op e3 in
          let arg = arg2@arg3 in
          (pr_formula_exp e1); fmt_string("="); pr_fn_args op_max pr_formula_exp arg
    | P.EqMin (e1, e2, e3, l) ->   
          let arg2 = bin_op_to_list op_min_short exp_assoc_op e2 in
          let arg3 = bin_op_to_list op_min_short exp_assoc_op e3 in
          let arg = arg2@arg3 in
          (pr_formula_exp e1); fmt_string("="); pr_fn_args op_min pr_formula_exp arg
    | P.BagIn (v, e, l) -> pr_op_adhoc (fun ()->pr_spec_var v) " <in> "  (fun ()-> pr_formula_exp e)
    | P.BagNotIn (v, e, l) -> pr_op_adhoc (fun ()->pr_spec_var v) " <notin> "  (fun ()-> pr_formula_exp e)
    | P.BagSub (e1, e2, l) -> pr_op pr_formula_exp e1  "<subset> " e2
    | P.BagMin (v1, v2, l) -> pr_op pr_spec_var v1  " = <min> " v2
    | P.BagMax (v1, v2, l) -> pr_op pr_spec_var v1  " = <max> " v2
    | P.VarPerm (t,ls,l) -> 
        fmt_string (string_of_vp_ann t); fmt_string ("[");
        fmt_string (string_of_spec_var_list ls); fmt_string ("]")
    | P.ListIn (e1, e2, l) ->  pr_op_adhoc (fun ()->pr_formula_exp e1) " <Lin> "  (fun ()-> pr_formula_exp e2)
    | P.ListNotIn (e1, e2, l) ->  pr_op_adhoc (fun ()->pr_formula_exp e1) " <Lnotin> "  (fun ()-> pr_formula_exp e2)
    | P.ListAllN (e1, e2, l) ->  pr_op_adhoc (fun ()->pr_formula_exp e1) " <allN> "  (fun ()-> pr_formula_exp e2)
    | P.ListPerm (e1, e2, l) -> pr_op_adhoc (fun ()->pr_formula_exp e1) " <perm> "  (fun ()-> pr_formula_exp e2)
	| P.RelForm (r, args, l) -> fmt_string ((string_of_spec_var r) ^ "("); match args with
		| [] -> ()
		| arg_first::arg_rest -> let _ = pr_formula_exp arg_first in 
		  let _ = List.map (fun x -> fmt_string (","); pr_formula_exp x) arg_rest in fmt_string ")" (* An Hoa *) 
;;

let string_of_int_label (i,s) s2:string = (string_of_int i)^s2
let string_of_int_label_opt h s2:string = match h with | None-> "N "^s2 | Some s -> string_of_int_label s s2
let string_of_formula_type (t:formula_type):string = match t with | Globals.Simple -> "Simple" | _ -> "Complex"
let string_of_formula_label (i,s) s2:string = s2 (*((string_of_int i)^":#"^s^":#"^s2)*)
let string_of_formula_label_pr_br (i,s) s2:string = ("("^(string_of_int i)^","^s^"):"^s2)
let string_of_formula_label_opt h s2:string = match h with | None-> s2 | Some s -> (string_of_formula_label s s2)
let string_of_control_path_id (i,s) s2:string = string_of_formula_label (i,s) s2
let string_of_control_path_id_opt h s2:string = string_of_formula_label_opt h s2
let string_of_formula_label_only x :string = string_of_formula_label x ""
let pr_formula_label = pr_pair string_of_int pr_id
let pr_control_path_id_opt h = pr_option pr_formula_label h

let string_of_iast_label_table table =
  let string_of_row row =
    let string_of_label_loc (_, path_label, loc) =
      Printf.sprintf "%d: %s" path_label (string_of_full_loc loc)
    in
    let path_id, desc, labels, loc = row in
    Printf.sprintf "\nid: %s; labels: %s; loc: %s" 
      (string_of_control_path_id_opt path_id desc)
      (List.fold_left (fun s label_loc -> s ^ (string_of_label_loc label_loc) ^ ", ") "" labels)
      (string_of_full_loc loc)
  in
  List.fold_right (fun row res -> (string_of_row row) ^ res) table ""


let pr_formula_label_br l = fmt_string (string_of_formula_label_pr_br l "")
let pr_formula_label l  = fmt_string (string_of_formula_label l "")
let pr_formula_label_list l  = fmt_string ("{"^(String.concat "," (List.map (fun (i,_)-> (string_of_int i)) l))^"}")
let pr_formula_label_opt l = fmt_string (string_of_formula_label_opt l "")
let string_of_formula_label_list l :string =  poly_string_of_pr pr_formula_label_list l
let pr_spec_label_def l  = fmt_string (LO2.string_of l)
let pr_spec_label_def_opt l = fmt_string (LO2.string_of_opt l)
let pr_spec_label l  = fmt_string (LO.string_of l)

(** print a pure formula to formatter *)
let rec pr_pure_formula  (e:P.formula) = 
  let f_b e =  pr_bracket pure_formula_wo_paren pr_pure_formula e 
  in
  match e with 
    | P.BForm (bf,lbl) -> (*pr_formula_label_opt lbl;*) pr_b_formula bf
    | P.And (f1, f2, l) ->  
          let arg1 = bin_op_to_list op_and_short pure_formula_assoc_op f1 in
          let arg2 = bin_op_to_list op_and_short pure_formula_assoc_op f2 in
          let args = arg1@arg2 in
          pr_list_op op_and f_b args
    | P.AndList b -> fmt_string "\n AndList( ";
		pr_list_op_none " ; " (wrap_box ("B",0) (pr_pair_aux pr_spec_label pr_pure_formula)) b;fmt_string ") "
    | P.Or (f1, f2, lbl,l) -> 
          pr_formula_label_opt lbl; 
          let arg1 = bin_op_to_list op_or_short pure_formula_assoc_op f1 in
          let arg2 = bin_op_to_list op_or_short pure_formula_assoc_op f2 in
          let args = arg1@arg2 in
          (fmt_string "("; pr_list_op op_or f_b args; fmt_string ")")
    | P.Not (f, lbl, l) -> 
          pr_formula_label_opt lbl; 
          fmt_string "!(";f_b f;fmt_string ")"
    | P.Forall (x, f,lbl, l) -> 
          pr_formula_label_opt lbl; 
	      fmt_string "forall("; pr_spec_var x; fmt_string ":";
	      pr_pure_formula f; fmt_string ")"
    | P.Exists (x, f, lbl, l) -> 
          pr_formula_label_opt lbl; 
	      fmt_string "exists("; pr_spec_var x; fmt_string ":";
	      pr_pure_formula f; fmt_string ")"
;;

let pr_prune_status st = match st with
  | Implied_N -> fmt_string "(IN)"
  | Implied_P -> fmt_string "(IP)" 
  | Implied_R -> fmt_string "(IDup)" 
  
let pr_memoise_constraint c = 
  pr_b_formula c.memo_formula ; pr_prune_status c.memo_status
  
let string_of_memoise_constraint c = poly_string_of_pr pr_memoise_constraint c
  
let pr_memoise mem = 
  fmt_string "[";pr_list_op_none "& " pr_memoise_constraint mem; fmt_string "]"

let pr_mem_slice slc = fmt_string "[";pr_pure_formula (P.conj_of_list slc no_pos); fmt_string "]"

let pr_mem_slice_aux slc = fmt_string "[";
 pr_list_op_none "" pr_pure_formula slc ; fmt_string "]"  
 
let pr_memoise_group_vb m_gr = 
  (*if !pr_mem then *)
  fmt_cut();
  fmt_print_newline ();
  wrap_box ("V",1)
      ( fun m_gr -> fmt_string "(";pr_list_op_none "" 
          (fun c-> wrap_box ("H",1) (fun _ -> fmt_string 
						"SLICE["; pr_list_of_spec_var c.memo_group_fv; fmt_string "]["; 
						pr_list_of_spec_var c.memo_group_linking_vars; fmt_string "]";
						fmt_string (if c.memo_group_unsat then "(sat?):" else ":")) (); 
              fmt_cut ();fmt_string "  ";
              wrap_box ("B",1) pr_memoise c.memo_group_cons;
              fmt_cut ();fmt_string "  ";
              wrap_box ("B",1) pr_mem_slice c.memo_group_slice;
              fmt_cut (); fmt_string ("changed flag:"^string_of_bool c.memo_group_changed);
              fmt_cut (); fmt_string ("unsat   flag:"^string_of_bool c.memo_group_unsat);
              fmt_cut ();fmt_string "  alias set:";
              wrap_box ("B",1) fmt_string (P.EMapSV.string_of c.memo_group_aset);
              (* fmt_cut(); *)
          ) m_gr; fmt_string ")") m_gr
  (*else ()*)
  
let pr_memoise_group_standard print_P m_gr = 
  (*if !pr_mem then *)
  fmt_cut();
  wrap_box ("B",1)
      ( fun m_gr -> fmt_string "(";pr_list_op_none ""     
          (fun c-> 
              let f = MCP.fold_mem_lst (CP.mkTrue no_pos) false print_P (MCP.MemoF [c]) in
              fmt_string "[";
              wrap_box ("B",1) pr_pure_formula f;
              fmt_string "]";
              fmt_cut()
          ) m_gr; fmt_string ")") m_gr

let pr_memoise_group m_gr = match !Globals.memo_verbosity with
  | 0 -> pr_memoise_group_vb m_gr (*verbose*)
  | 1 -> pr_memoise_group_standard false  m_gr (*brief*)
  | _ -> pr_memoise_group_standard true  m_gr (*standard*)
      
let pr_remaining_branches s = match s with 
  | None -> () (* fmt_string "None" *)
  | Some s -> 
        fmt_cut();
        wrap_box ("B",1) (fun s->fmt_string "@ rem br[" ; pr_formula_label_list s; fmt_string "]") s

let string_of_remaining_branches c = poly_string_of_pr pr_remaining_branches c

let pr_prunning_conditions cnd pcond = match cnd with 
  | None -> ()
  | Some _ -> () (* fmt_cut (); fmt_string "@ prune_cond [" ; wrap_box
                    ("B",1) (fun pcond-> List.iter (fun (c,c2)-> fmt_cut (); fmt_string
                    "( " ; pr_b_formula c; fmt_string" )->"; pr_formula_label_list c2;)
                    pcond;fmt_string "]") pcond *)

let string_of_ms (m:(P.spec_var list) list) : string =
  let wrap s1 = "["^s1^"]" in
  let ls = List.map (fun l -> wrap (String.concat "," (List.map string_of_spec_var l))) m in
  wrap (String.concat ";" ls)

let pr_mem_formula  (e : mem_formula) = 
  fmt_string (string_of_ms e.mem_formula_mset)

let pr_aliasing_scenario (al :aliasing_scenario) = 
 match al with
   | Not_Aliased -> fmt_string "[Not]"
   | May_Aliased -> fmt_string "[May]"
   | Must_Aliased -> fmt_string "[Must]"
   | Partial_Aliased -> fmt_string "[Partial]"

(** print a mem formula to formatter *)
(* let rec pr_mem_formula  (e : mem_formula) =  *)
(*   match e.mem_formula_mset with *)
(*     | h :: r -> *)
(* 	fmt_string "["; *)
(* 	fmt_string (List.fold_left  *)
(* 		      (fun y x -> (y ^ ( (string_of_spec_var ((\*fst*\) x)) (\*^ "|" ^ (poly_string_of_pr  pr_pure_formula (snd x))*\) ^ ",")))  *)
(* 		      ""  *)
(* 		      h); *)
(* 	fmt_string "]"; *)
(* 	pr_mem_formula {mem_formula_mset = r} *)
(*     | [] -> fmt_string ";" *)
(* ;; *)

(** convert formula exp to a string via pr_formula_exp *)
let string_of_formula_exp (e:P.exp) : string =  poly_string_of_pr  pr_formula_exp e

let printer_of_formula_exp (crt_fmt: Format.formatter) (e:P.exp) : unit =
  poly_printer_of_pr crt_fmt pr_formula_exp e

let string_of_cperm perm =
  let perm_str = match perm with
    | None -> ""
    | Some f -> string_of_formula_exp f
  in if (Perm.allow_perm ()) then "(" ^ perm_str ^ ")" else ""

let rec pr_h_formula h = 
  let f_b e =  pr_bracket h_formula_wo_paren pr_h_formula e in
  match h with
    | Star ({h_formula_star_h1 = h1; h_formula_star_h2 = h2; h_formula_star_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_star_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_star_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_star f_b args
    | StarMinus ({h_formula_starminus_h1 = h1; h_formula_starminus_h2 = h2; h_formula_starminus_aliasing = al;
                  h_formula_starminus_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_starminus_short h_formula_assoc_op h2 in
          let arg2 = bin_op_to_list op_starminus_short h_formula_assoc_op h1 in
          let args = arg1@arg2 in
          pr_aliasing_scenario al; pr_list_op op_starminus f_b args          
    | Phase ({h_formula_phase_rd = h1; h_formula_phase_rw = h2; h_formula_phase_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_phase_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_phase_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          fmt_string "("; pr_list_op op_phase f_b args; fmt_string ")" 
    | Conj ({h_formula_conj_h1 = h1; h_formula_conj_h2 = h2; h_formula_conj_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_conj_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_conj_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_conj (pr_bracket (fun _ -> false) pr_h_formula) args
    | ConjStar ({h_formula_conjstar_h1 = h1; h_formula_conjstar_h2 = h2; h_formula_conjstar_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_conjstar_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_conjstar_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_conjstar (pr_bracket (fun _ -> false) pr_h_formula) args
    | ConjConj ({h_formula_conjconj_h1 = h1; h_formula_conjconj_h2 = h2; h_formula_conjconj_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_conjconj_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_conjconj_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_conjconj (pr_bracket (fun _ -> false) pr_h_formula) args                    
    | DataNode ({h_formula_data_node = sv;
      h_formula_data_name = c;
	  h_formula_data_derv = dr;
	  h_formula_data_imm = imm;
	  h_formula_data_param_imm = ann_param;
      h_formula_data_arguments = svs;
		h_formula_data_holes = hs; (* An Hoa *)
      h_formula_data_perm = perm; (*LDK*)
      h_formula_data_origins = origs;
      h_formula_data_original = original;
      h_formula_data_pos = pos;
      h_formula_data_remaining_branches = ann;
      h_formula_data_label = pid})->
			(** [Internal] Replace the specvars at positions of holes with '-' **)
        (*TO CHECK: this may hide some potential errors*)
          let perm_str = string_of_cperm perm in
	  let rec replace_holes svl hs n = 
	    if hs = [] then svl
	    else let sv = List.hd svl in
	    match sv with
	      | CP.SpecVar (t,vn,vp) -> 
		    if (List.hd hs = n) then
		      CP.SpecVar (t,"-",vp) :: (replace_holes (List.tl svl) (List.tl hs) (n+1))
		    else
		      sv :: (replace_holes (List.tl svl) hs (n+1))
	  in
	  let svs = replace_holes svs hs 0 in
          fmt_open_hbox ();
	  if (!Globals.texify) then
	    begin
	      fmt_string "\sepnode{";pr_spec_var sv; fmt_string ("}{"^c^"}{"); pr_list_of_spec_var svs ;fmt_string "}";
	    end
	  else
	    begin
              (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
              (* pr_formula_label_opt pid; *)
	      (* An Hoa : Replace the spec-vars at holes with the symbol '-' *)
              pr_spec_var sv; fmt_string "::";
              (if not(!Globals.allow_field_ann) ||(List.length svs != List.length ann_param) then pr_angle (c^perm_str) (fun x ->  pr_spec_var x) svs 
              else pr_angle (c^perm_str) (fun (x,y) -> 
                  (* prints absent field as "#" *)
                  (* if is_absent y then fmt_string "#" *)
                  (* else  *)(pr_spec_var x; pr_imm y)) (List.combine svs ann_param) );
	      if (!Globals.allow_imm) then pr_imm imm;
	      pr_derv dr;
              if (hs!=[]) then (fmt_string "("; fmt_string (pr_list string_of_int hs); fmt_string ")");
              (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
              if !print_derv then
                begin
                  if origs!=[] then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
	          if original then fmt_string "[Orig]"
	          else fmt_string "[Derv]"
                end;
              pr_remaining_branches ann;
	    end;
	  fmt_close();
    | ViewNode ({h_formula_view_node = sv; 
      h_formula_view_name = c; 
	  h_formula_view_derv = dr;
	  h_formula_view_imm = imm;
      h_formula_view_perm = perm; (*LDK*)
      h_formula_view_arguments = svs;
      h_formula_view_args_orig = svs_orig;  
      h_formula_view_annot_arg = anns;  
      h_formula_view_origins = origs;
      h_formula_view_original = original;
      h_formula_view_lhs_case = lhs_case;
      h_formula_view_label = pid;
      h_formula_view_remaining_branches = ann;
      h_formula_view_pruning_conditions = pcond;
	  h_formula_view_unfold_num = ufn;
      h_formula_view_pos =pos}) ->
          let perm_str = string_of_cperm perm in
          let params = CP.create_view_arg_list_from_pos_map svs_orig svs anns in
          fmt_open_hbox ();
	  if (!Globals.texify) then
	    begin
	      (* fmt_string "\seppred{";pr_spec_var sv;fmt_string ("}{"^c^"}{"); pr_list_of_spec_var svs; fmt_string "}"; *)
	      fmt_string "\seppred{";pr_spec_var sv;fmt_string ("}{"^c^"}{"); pr_list_of_view_arg params; fmt_string "}";
	    end
	  else
	    begin
              (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
              (* pr_formula_label_opt pid;  *)
              pr_spec_var sv; 
              fmt_string "::"; (* to distinguish pred from data *)
              pr_angle (c^perm_str) pr_view_arg params;
	      pr_imm imm;
	      pr_derv dr;
              (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
              if (!Globals.print_derv) then
                begin
                  if origs!=[] then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
	          fmt_string ("["^(string_of_int ufn)^"]");
		  if original then fmt_string "[Orig]"
	          else fmt_string "[Derv]";
 	          if lhs_case then fmt_string "[LHSCase]"
                end;
              pr_remaining_branches ann; 
              pr_prunning_conditions ann pcond;
	    end;
          fmt_close()
    | ThreadNode ({h_formula_thread_node =sv;
      h_formula_thread_name = c;
      h_formula_thread_delayed = dl;
      h_formula_thread_resource = rsr;
	  h_formula_thread_derv = dr;
      h_formula_thread_perm = perm; (*LDK*)
      h_formula_thread_origins = origs;
      h_formula_thread_original = original;
      h_formula_thread_pos = pos;
      h_formula_thread_label = pid;}) ->
        let perm_str = string_of_cperm perm in
        let dl_str = string_of_pure_formula dl in
        let rsr_str = string_of_formula rsr in
        let arg_str = (dl_str^" --> "^rsr_str) in
	    if (!Globals.texify) then
	      begin
	          fmt_string "\sepnode{";pr_spec_var sv; fmt_string ("}{"^c^"}{"); fmt_string arg_str ;fmt_string "}";
	      end
	    else
	      begin
              pr_spec_var sv; fmt_string "::";
              pr_sharp_angle (c^perm_str) fmt_string [arg_str];
	          pr_derv dr;
              (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
              if !print_derv then
                begin
                    if origs!=[] then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
	                if original then fmt_string "[Orig]"
	                else fmt_string "[Derv]"
                end;
	      end;
	    fmt_close();
    | HRel (r, args, l) -> 
		if (!Globals.texify) then
		begin 
			  fmt_string ("\seppred{"^(string_of_spec_var r) ^ "}{");pr_formula_exp_list "," args;fmt_string "}"
		  end
		else
		begin
		fmt_string ((string_of_spec_var r) ^ "(");
          (match args with
	    | [] -> ()
	    | arg_first::arg_rest -> let _ = pr_formula_exp arg_first in 
	      let _ = List.map (fun x -> fmt_string (","); pr_formula_exp x) arg_rest in fmt_string ")");
		end
    | HTrue -> fmt_string "htrue"
    | HFalse -> fmt_string "hfalse"
    | HEmp -> fmt_string "emp"
    | Hole m -> fmt_string ("Hole[" ^ (string_of_int m) ^ "]")

and pr_hrel_formula hf=
  match hf with
    | (HRel (r, args, l)) ->
        fmt_string ((string_of_spec_var r) ^ "(");
        (match args with
	      | [] -> ()
	      | arg_first::arg_rest -> let _ = pr_formula_exp arg_first in 
		                           let _ = List.map (fun x -> fmt_string (","); pr_formula_exp x) arg_rest in fmt_string ")")
    | _ -> report_error no_pos "Cprinter.pr_hrel_formula: can not happen"


and prtt_pr_h_formula h = 
  let f_b e =  pr_bracket h_formula_wo_paren prtt_pr_h_formula e 
  in
  match h with
    | Star ({h_formula_star_h1 = h1; h_formula_star_h2 = h2; h_formula_star_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_star_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_star_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_star f_b args
    | Phase ({h_formula_phase_rd = h1; h_formula_phase_rw = h2; h_formula_phase_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_phase_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_phase_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          fmt_string "("; pr_list_op op_phase f_b args; fmt_string ")" 
    | Conj ({h_formula_conj_h1 = h1; h_formula_conj_h2 = h2; h_formula_conj_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_conjsep_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_conjsep_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_conjsep_short f_b args
    | ConjConj ({h_formula_conjconj_h1 = h1; h_formula_conjconj_h2 = h2; h_formula_conjconj_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_conjconj_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_conjconj_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_conjconj_short f_b args
    | ConjStar ({h_formula_conjstar_h1 = h1; h_formula_conjstar_h2 = h2; h_formula_conjstar_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_conjstar_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_conjstar_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_conjstar_short f_b args
    | StarMinus ({h_formula_starminus_h1 = h1; h_formula_starminus_h2 = h2; h_formula_starminus_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_starminus_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_starminus_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_starminus_short f_b args
    | DataNode ({h_formula_data_node = sv;
      h_formula_data_name = c;
	  h_formula_data_derv = dr;
	  h_formula_data_imm = imm;
      h_formula_data_arguments = svs;
		h_formula_data_holes = hs; (* An Hoa *)
      h_formula_data_perm = perm; (*LDK*)
      h_formula_data_origins = origs;
      h_formula_data_original = original;
      h_formula_data_pos = pos;
      h_formula_data_remaining_branches = ann;
      h_formula_data_label = pid})->
			(** [Internal] Replace the specvars at positions of holes with '-' **)
        (*TO CHECK: this may hide some potential errors*)
        let perm_str = string_of_cperm perm in
			let rec replace_holes svl hs n = 
				if hs = [] then svl
				else let sv = List.hd svl in
						match sv with
							| CP.SpecVar (t,vn,vp) -> 
								if (List.hd hs = n) then
									CP.SpecVar (t,"-",vp) :: (replace_holes (List.tl svl) (List.tl hs) (n+1))
								else
									sv :: (replace_holes (List.tl svl) hs (n+1))
			in
			let svs = replace_holes svs hs 0 in
          fmt_open_hbox ();
		  if !Globals.texify then
			begin
			  fmt_string "\sepnode{";pr_spec_var sv; fmt_string ("}{"^c^"}{"); pr_list_of_spec_var svs ;fmt_string "}";
			end
		  else
		    begin
			          (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
          (* pr_formula_label_opt pid; *)
			(* An Hoa : Replace the spec-vars at holes with the symbol '-' *)
			  pr_spec_var sv; fmt_string "::";
			  pr_angle (c^perm_str) pr_spec_var svs ;
			  pr_imm imm;
			  pr_derv dr;
			  if (hs!=[]) then (fmt_string "("; fmt_string (pr_list string_of_int hs); fmt_string ")");
			  (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
			  if origs!=[] && !print_derv then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
			  (* if original then fmt_string "[Orig]" *)
			  (* else fmt_string "[Derv]"; *)
			  pr_remaining_branches ann;
			end;
          fmt_close();
    | ThreadNode ({h_formula_thread_node =sv;
      h_formula_thread_name = c;
      h_formula_thread_delayed = dl;
      h_formula_thread_resource = rsr;
	  h_formula_thread_derv = dr;
      h_formula_thread_perm = perm; (*LDK*)
      h_formula_thread_origins = origs;
      h_formula_thread_original = original;
      h_formula_thread_pos = pos;
      h_formula_thread_label = pid;}) ->
        let perm_str = string_of_cperm perm in
        let dl_str = string_of_pure_formula dl in
        let rsr_str = string_of_formula rsr in
        let arg_str = (dl_str^" --> "^rsr_str) in
        fmt_open_hbox ();
		if !Globals.texify then
		  begin
			  fmt_string "\sepnode{";pr_spec_var sv; fmt_string ("}{"^c^"}{"); fmt_string arg_str ;fmt_string "}";
		  end
		else
		  begin
			  (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
              (* pr_formula_label_opt pid; *)
			  (* An Hoa : Replace the spec-vars at holes with the symbol '-' *)
			  pr_spec_var sv; fmt_string "::";
              pr_sharp_angle (c^perm_str) fmt_string [arg_str];
			  pr_derv dr;
			  (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
			  if origs!=[] && !print_derv then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
		  (* if original then fmt_string "[Orig]" *)
		  (* else fmt_string "[Derv]"; *)
		  end;
        fmt_close();
    | ViewNode ({h_formula_view_node = sv; 
      h_formula_view_name = c; 
	  h_formula_view_derv = dr;
	  h_formula_view_imm = imm;
      h_formula_view_perm = perm; (*LDK*)
      h_formula_view_arguments = svs; 
      h_formula_view_args_orig = svs_orig;  
      h_formula_view_annot_arg = anns;  
      h_formula_view_origins = origs;
      h_formula_view_original = original;
      h_formula_view_lhs_case = lhs_case;
      h_formula_view_label = pid;
      h_formula_view_remaining_branches = ann;
      h_formula_view_pruning_conditions = pcond;
      h_formula_view_pos =pos}) ->
        let perm_str = string_of_cperm perm in
        let params = CP.create_view_arg_list_from_pos_map svs_orig svs anns in
        fmt_open_hbox ();
        (* (if pid==None then fmt_string "N
           N " else fmt_string "SS "); *)
        (* pr_formula_label_opt pid;  *)
	if (!Globals.texify) then 
	  begin
	    (* fmt_string "\seppred{";pr_spec_var sv;fmt_string ("}{"^c^"}{"); pr_list_of_spec_var svs; fmt_string "}"; *)
	    fmt_string "\seppred{";pr_spec_var sv;fmt_string ("}{"^c^"}{"); pr_list_of_view_arg params; fmt_string "}";
	  end
	else
          begin
	    pr_spec_var sv; 
	    fmt_string "::"; 
	    pr_angle (c^perm_str) pr_view_arg params;
	    pr_imm imm;
	    pr_derv dr;
	    (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
	    if origs!=[] && !print_derv then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
	    (* if original then fmt_string "[Orig]" *)
	    (* else fmt_string "[Derv]"; *)
	    if lhs_case  && !print_derv then fmt_string "[LHSCase]";
	    pr_remaining_branches ann; 
	    pr_prunning_conditions ann pcond;
	  end;
	fmt_close()
    | HRel (r, args, l) -> 
	  if (!Globals.texify) then
	    begin 
	      fmt_string ("\seppred{"^(string_of_spec_var r) ^ "}{");pr_formula_exp_list "," args;fmt_string "}"
	    end
	  else
	    begin
	      fmt_string ((string_of_spec_var r) ^ "(");
	      (match args with
		| [] -> ()
		| arg_first::arg_rest -> let _ = pr_formula_exp arg_first in 
		  let _ = List.map (fun x -> fmt_string (","); pr_formula_exp x) arg_rest in fmt_string ")");
	    end
    | HTrue -> fmt_string "htrue"
    | HFalse -> fmt_string "hfalse"
    | HEmp -> fmt_string (texify "\emp" "emp")
    | Hole m -> fmt_string ("Hole[" ^ (string_of_int m) ^ "]")

and prtt_pr_h_formula_inst prog h = 
  let f_b e =  pr_bracket h_formula_wo_paren (prtt_pr_h_formula_inst prog) e 
  in
  match h with
    | Star ({h_formula_star_h1 = h1; h_formula_star_h2 = h2; h_formula_star_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_star_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_star_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_star f_b args
    | Phase ({h_formula_phase_rd = h1; h_formula_phase_rw = h2; h_formula_phase_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_phase_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_phase_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          fmt_string "("; pr_list_op op_phase f_b args; fmt_string ")" 
    | Conj ({h_formula_conj_h1 = h1; h_formula_conj_h2 = h2; h_formula_conj_pos = pos}) -> 
	      let arg1 = bin_op_to_list op_conjsep_short h_formula_assoc_op h1 in
          let arg2 = bin_op_to_list op_conjsep_short h_formula_assoc_op h2 in
          let args = arg1@arg2 in
          pr_list_op op_conjsep_short f_b args
    | DataNode ({h_formula_data_node = sv;
      h_formula_data_name = c;
	  h_formula_data_derv = dr;
	  h_formula_data_imm = imm;
      h_formula_data_arguments = svs;
		h_formula_data_holes = hs; (* An Hoa *)
      h_formula_data_perm = perm; (*LDK*)
      h_formula_data_origins = origs;
      h_formula_data_original = original;
      h_formula_data_pos = pos;
      h_formula_data_remaining_branches = ann;
      h_formula_data_label = pid})->
	  (** [Internal] Replace the specvars at positions of holes with '-' **)
          (*TO CHECK: this may hide some potential errors*)
          let perm_str = string_of_cperm perm in
	  let rec replace_holes svl hs n = 
	    if hs = [] then svl
	    else let sv = List.hd svl in
	    match sv with
	      | CP.SpecVar (t,vn,vp) -> 
		    if (List.hd hs = n) then
		      CP.SpecVar (t,"-",vp) :: (replace_holes (List.tl svl) (List.tl hs) (n+1))
		    else
		      sv :: (replace_holes (List.tl svl) hs (n+1))
	  in
	  let svs = replace_holes svs hs 0 in
          fmt_open_hbox ();
		   if !Globals.texify then
			begin
			  fmt_string "\sepnode{";pr_spec_var sv; fmt_string ("}{"^c^"}{"); pr_list_of_spec_var svs ;fmt_string "}";
			end
			else 
			begin
			  (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
			  (* pr_formula_label_opt pid; *)
				(* An Hoa : Replace the spec-vars at holes with the symbol '-' *)
			  pr_spec_var sv; fmt_string "::";
			  pr_angle (c^perm_str) pr_spec_var svs ;
			  pr_imm imm;
			  pr_derv dr;
			  if (hs!=[]) then (fmt_string "("; fmt_string (pr_list string_of_int hs); fmt_string ")");
			  (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
			  if origs!=[] && !print_derv then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
			  (* if original then fmt_string "[Orig]" *)
			  (* else fmt_string "[Derv]"; *)
			  pr_remaining_branches ann;
		  end;
          fmt_close();
    | ThreadNode ({h_formula_thread_node =sv;
                   h_formula_thread_name = c;
                   h_formula_thread_delayed = dl;
                   h_formula_thread_resource = rsr;
	               h_formula_thread_derv = dr;
                   h_formula_thread_perm = perm; (*LDK*)
                   h_formula_thread_origins = origs;
                   h_formula_thread_original = original;
                   h_formula_thread_pos = pos;
                   h_formula_thread_label = pid;}) ->
        let perm_str = string_of_cperm perm in
        let dl_str = string_of_pure_formula dl in
        let rsr_str = string_of_formula rsr in
        let arg_str = (dl_str^" --> "^rsr_str) in
        fmt_open_hbox ();
		if !Globals.texify then
		  begin
			  fmt_string "\sepnode{";pr_spec_var sv; fmt_string ("}{"^c^"}{"); fmt_string arg_str ;fmt_string "}";
		  end
		else 
		  begin
			  (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
			  (* pr_formula_label_opt pid; *)
			  (* An Hoa : Replace the spec-vars at holes with the symbol '-' *)
			  pr_spec_var sv; fmt_string "::";
              pr_sharp_angle (c^perm_str) fmt_string [arg_str];
			  pr_derv dr;
			  (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
			  if origs!=[] && !print_derv then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
		  (* if original then fmt_string "[Orig]" *)
		  (* else fmt_string "[Derv]"; *)
		  end;
        fmt_close();
    | ViewNode ({h_formula_view_node = sv; 
      h_formula_view_name = c; 
	  h_formula_view_derv = dr;
	  h_formula_view_imm = imm;
      h_formula_view_perm = perm; (*LDK*)
      h_formula_view_arguments = svs; 
      h_formula_view_args_orig = svs_orig;  
      h_formula_view_annot_arg = anns;  
      h_formula_view_origins = origs;
      h_formula_view_original = original;
      h_formula_view_lhs_case = lhs_case;
      h_formula_view_label = pid;
      h_formula_view_remaining_branches = ann;
      h_formula_view_pruning_conditions = pcond;
      h_formula_view_pos =pos}) ->
        let perm_str = string_of_cperm perm in
        let params = CP.create_view_arg_list_from_pos_map svs_orig svs anns in
          fmt_open_hbox ();
		    if (!Globals.texify) then 
			  begin
			  (* fmt_string "\seppred{";pr_spec_var sv;fmt_string ("}{"^c^"}{");pr_list_of_spec_var svs;fmt_string "}"; *)
			  fmt_string "\seppred{";pr_spec_var sv;fmt_string ("}{"^c^"}{");pr_list_of_view_arg params;fmt_string "}";
			  end
		  else
          begin
				 (* (if pid==None then fmt_string "N
		N " else fmt_string "SS "); *)
				  (* pr_formula_label_opt pid;  *)
				  pr_spec_var sv; 
				  fmt_string "::"; 
				  pr_angle (c^perm_str) pr_view_arg params;
				  pr_imm imm;
				  pr_derv dr;
				  (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
				  if origs!=[] && !print_derv then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
				  (* if original then fmt_string "[Orig]" *)
				  (* else fmt_string "[Derv]"; *)
			  if lhs_case && !print_derv then fmt_string "[LHSCase]";
				 pr_remaining_branches ann; 
				  pr_prunning_conditions ann pcond;
		  end;
          fmt_close()
    | HRel (r, args, l) ->
          let hp_name= CP.name_of_spec_var r in
          let hprel = Cast.look_up_hp_def_raw prog.Cast.prog_hp_decls hp_name in
          let ss = List.combine args hprel.Cast.hp_vars_inst in
          let args_inst = List.map (fun (sv,(_,i)) -> (sv,i)) ss in
		  if (!Globals.texify) then
		  begin
		  fmt_string ("\seppred{"^(string_of_spec_var r) ^ "}{");pr_formula_exp_w_ins_list args_inst;fmt_string "}";
		  end
		  else
		  begin
			  fmt_string ((string_of_spec_var r) ^ "(");
			  (match args_inst with
			| [] -> ()
			| arg_first::arg_rest -> let _ = pr_formula_exp_w_ins arg_first in 
			  let _ = List.map (fun x -> fmt_string (","); pr_formula_exp_w_ins x) arg_rest in fmt_string ")")
		  end
    | HTrue -> fmt_string "htrue"
    | HFalse -> fmt_string "hfalse"
    | HEmp -> fmt_string (texify "\emp" "emp")
    | Hole m -> fmt_string ("Hole[" ^ (string_of_int m) ^ "]")
    | StarMinus _ | ConjStar _ | ConjConj _  -> Error.report_no_pattern ()

and pr_h_formula_for_spec h = 
  let f_b e =  pr_bracket h_formula_wo_paren pr_h_formula_for_spec e in
  match h with
  | Star ({h_formula_star_h1 = h1; h_formula_star_h2 = h2; h_formula_star_pos = pos}) -> 
    let arg1 = bin_op_to_list op_star_short h_formula_assoc_op h1 in
    let arg2 = bin_op_to_list op_star_short h_formula_assoc_op h2 in
    let args = arg1@arg2 in
    pr_list_op op_star f_b args
  | Phase ({h_formula_phase_rd = h1; h_formula_phase_rw = h2; h_formula_phase_pos = pos}) -> 
    let arg1 = bin_op_to_list op_phase_short h_formula_assoc_op h1 in
    let arg2 = bin_op_to_list op_phase_short h_formula_assoc_op h2 in
    let args = arg1@arg2 in
    fmt_string "("; pr_list_op op_phase f_b args; fmt_string ")" 
  | Conj ({h_formula_conj_h1 = h1; h_formula_conj_h2 = h2; h_formula_conj_pos = pos}) -> 
    let arg1 = bin_op_to_list op_conj_short h_formula_assoc_op h1 in
    let arg2 = bin_op_to_list op_conj_short h_formula_assoc_op h2 in
    let args = arg1@arg2 in
    pr_list_op op_conj f_b args
  | DataNode ({h_formula_data_node = sv;
    h_formula_data_name = c;
    h_formula_data_derv = dr;
    h_formula_data_imm = imm;
    h_formula_data_arguments = svs;
    h_formula_data_holes = hs; (* An Hoa *)
    h_formula_data_perm = perm; (*LDK*)
    h_formula_data_origins = origs;
    h_formula_data_original = original;
    h_formula_data_pos = pos;
    h_formula_data_remaining_branches = ann;
    h_formula_data_label = pid})->
    (** [Internal] Replace the specvars at positions of holes with '-' **)
    (*TO CHECK: this may hide some potential errors*)
    let perm_str = string_of_cperm perm in
    let rec replace_holes svl hs n = 
      if hs = [] then svl
      else let sv = List.hd svl in
    match sv with
      | CP.SpecVar (t,vn,vp) -> 
        if (List.hd hs = n) then
          CP.SpecVar (t,"-",vp) :: (replace_holes (List.tl svl) (List.tl hs) (n+1))
        else
          sv :: (replace_holes (List.tl svl) hs (n+1))
    in
    let svs = replace_holes svs hs 0 in
    fmt_open_hbox ();
    (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
    (* pr_formula_label_opt pid; *)
    (* An Hoa : Replace the spec-vars at holes with the symbol '-' *)
    pr_spec_var sv; fmt_string "::";
    pr_angle (c^perm_str) pr_spec_var svs ;
    pr_imm imm;
    pr_derv dr;
    if (hs!=[]) then (fmt_string "("; fmt_string (pr_list string_of_int hs); fmt_string ")");
    (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
    if origs!=[] then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
    if (!print_derv) then
      (if original then fmt_string "[Orig]" else fmt_string "[Derv]");
    (match ann with | None -> () | Some _ -> fmt_string "[]");
    fmt_close();
    | ThreadNode ({h_formula_thread_node =sv;
      h_formula_thread_name = c;
      h_formula_thread_delayed = dl;
      h_formula_thread_resource = rsr;
	  h_formula_thread_derv = dr;
      h_formula_thread_perm = perm; (*LDK*)
      h_formula_thread_origins = origs;
      h_formula_thread_original = original;
      h_formula_thread_pos = pos;
      h_formula_thread_label = pid;}) ->
    let perm_str = string_of_cperm perm in
    let dl_str = string_of_pure_formula dl in
    let rsr_str = string_of_formula rsr in
    let arg_str = (dl_str^" --> "^rsr_str) in
    fmt_open_hbox ();
    (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
    (* pr_formula_label_opt pid; *)
    (* An Hoa : Replace the spec-vars at holes with the symbol '-' *)
    pr_spec_var sv; fmt_string "::";
    pr_sharp_angle (c^perm_str) fmt_string [arg_str];
    pr_derv dr;
    (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
    if origs!=[] then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
    if (!print_derv) then
      (if original then fmt_string "[Orig]" else fmt_string "[Derv]");
    fmt_close();
  | ViewNode ({h_formula_view_node = sv; 
    h_formula_view_name = c; 
    h_formula_view_derv = dr;
    h_formula_view_imm = imm;
    h_formula_view_perm = perm; (*LDK*)
    h_formula_view_arguments = svs; 
    h_formula_view_args_orig = svs_orig;  
    h_formula_view_annot_arg = anns;  
    h_formula_view_origins = origs;
    h_formula_view_original = original;
    h_formula_view_lhs_case = lhs_case;
    h_formula_view_label = pid;
    h_formula_view_remaining_branches = ann;
    h_formula_view_pruning_conditions = pcond;
    h_formula_view_pos =pos}) ->
    let perm_str = string_of_cperm perm in
    let params = CP.create_view_arg_list_from_pos_map svs_orig svs anns in
    fmt_open_hbox ();
    (* (if pid==None then fmt_string "NN " else fmt_string "SS "); *)
    (* pr_formula_label_opt pid;  *)
    pr_spec_var sv; 
    fmt_string "::"; 
    (* if svs = [] then fmt_string (c^"<>") else pr_angle (c^perm_str) pr_spec_var svs; *)
    if svs_orig = [] then fmt_string (c^"<>") else pr_angle (c^perm_str) pr_view_arg params;
(*    pr_imm imm;*)
    pr_derv dr;
    (* For example, #O[lem_29][Derv] means origins=[lem_29], and the heap node is derived*)
    if origs!=[] then pr_seq "#O" pr_ident origs; (* origins of lemma coercion.*)
    pr_prunning_conditions ann pcond;
    fmt_close()
  | HRel a ->  (pr_hrel_formula (HRel a))
  | HTrue -> fmt_bool true
  | HFalse -> fmt_bool false
  | HEmp -> fmt_string "emp"
  | Hole m -> fmt_string ("Hole[" ^ (string_of_int m) ^ "]")
  | StarMinus _ | ConjStar _ | ConjConj _  -> Error.report_no_pattern ()

and string_of_memoised_list l : string  = poly_string_of_pr pr_memoise_group l

(* string of a slicing label *)
and string_of_slicing_label sl : string =  poly_string_of_pr  pr_slicing_label sl
  
(** convert b_formula to a string via pr_b_formula *)
and string_of_b_formula (e:P.b_formula) : string =  poly_string_of_pr  pr_b_formula e
and string_of_p_formula (e:P.p_formula) : string =   string_of_b_formula (e,None)

and printer_of_b_formula (crt_fmt: Format.formatter) (e:P.b_formula) : unit =
  poly_printer_of_pr crt_fmt pr_b_formula e

(** convert mem_formula  to a string via pr_mem_formula *)
and string_of_mem_formula (e:Cformula.mem_formula) : string =  poly_string_of_pr  pr_mem_formula e

(** convert pure_formula  to a string via pr_pure_formula *)
and string_of_pure_formula (e:P.formula) : string =  poly_string_of_pr  pr_pure_formula e

and string_of_pure_formula_list_noparen l = match l with 
  | [] -> ""
  | h::[] -> string_of_pure_formula h 
  | h::t -> (string_of_pure_formula h) ^ " ;" ^ (string_of_pure_formula_list_noparen t)

and string_of_pure_formula_list l = "["^(string_of_pure_formula_list_noparen l)^"]"

and printer_of_pure_formula (crt_fmt: Format.formatter) (e:P.formula) : unit =
  poly_printer_of_pr crt_fmt pr_pure_formula e

(** convert h_formula  to a string via pr_h_formula *)
and string_of_h_formula (e:h_formula) : string =  poly_string_of_pr  pr_h_formula e

and string_of_h_formula_for_spec (e:h_formula): string = poly_string_of_pr pr_h_formula_for_spec e

and printer_of_h_formula (crt_fmt: Format.formatter) (e:h_formula) : unit =
  poly_printer_of_pr crt_fmt pr_h_formula e

and pr_formula_branches l =
   pr_seq_option " & " (fun (l, f) -> fmt_string ("\"" ^ l ^ "\" : "); 
   pr_pure_formula f) l

and string_of_formula_branches l = poly_string_of_pr pr_formula_branches l

and pr_pure_formula_branches (f, l) =
 (pr_bracket pure_formula_wo_paren pr_pure_formula f); 
   pr_seq_option " & " (fun (l, f) -> fmt_string ("\"" ^ l ^ "\" : "); 
   pr_pure_formula f) l

and pr_memo_pure_formula f = pr_bracket pure_memoised_wo_paren pr_memoise_group f

and pr_memo_pure_formula_branches (f, l) =
  (pr_bracket pure_memoised_wo_paren pr_memoise_group f); 
  pr_seq_option " & " (fun (l, f) -> fmt_string ("\"" ^ l ^ "\" : "); 
      pr_pure_formula f) l

and pr_mix_formula f = match f with
  | MCP.MemoF f -> pr_memo_pure_formula f
  | MCP.OnePF f -> pr_pure_formula f

and string_of_flow_formula f c = 
  "{"^f^","^string_of_flow c.formula_flow_interval^"="^(exlist # get_closest c.formula_flow_interval)^(match c.formula_flow_link with | None -> "" | Some e -> ","^e)^"}"

(* let rec string_of_nflow n = (exlist # get_closest n) *)
and string_of_dflow n = (exlist # get_closest n)

(* let rec string_of_dflow n = (exlist # get_closest n) *)

and string_of_sharp_flow sf = match sf with
  | Sharp_ct ff -> "#"^(string_of_flow_formula "" ff)
  | Sharp_id id -> "#"^id

and pr_one_formula (f:one_formula) = 
  let h,p,th,df,lb,pos = split_one_formula f in
  fmt_string (" <thread="); (pr_spec_var th); fmt_string ("> ");
  fmt_string (" <delayed:"); (pr_mix_formula df); fmt_string ("> ");
  fmt_string (" <ref:"); fmt_string (string_of_spec_var_list f.formula_ref_vars); fmt_string ("> ");
  pr_h_formula h ; pr_cut_after "&" ; pr_mix_formula p

and string_of_one_formula f = poly_string_of_pr  pr_one_formula f

and pr_one_formula_wrap e = (wrap_box ("H",1) pr_one_formula) e

and pr_one_formula_list (ls:one_formula list) =
  if (ls==[]) then fmt_string ("[]")
  else
  (* let pr_conj ls = *)
  (*   if (List.length ls == 1) then pr_one_formula (List.hd ls) *)
  (*   else pr_list_op_vbox "AND" pr_one_formula_wrap ls *)
  (* in fmt_cut(); pr_conj ls *)
  
    fmt_cut();pr_list_op_none "AND\n" pr_one_formula_wrap ls

    (* pr_list_op_vbox "AND " pr_one_formula_wrap ls *)
   (* pr_seq_vbox "" (wrap_box ("H",1) pr_conj) ls *)
  (* match ls with *)
  (*   | [] -> () *)
  (*   | f::fs -> *)
  (*       pr_one_formula_wrap f; *)
  (*       if (fs==[]) then () *)
  (*       else *)
  (*         fmt_string ("\nAND "); pr_one_formula_list fs *)

and string_of_one_formula_list ls = poly_string_of_pr  pr_one_formula_list ls

and pr_formula_base e =
  match e with
    | ({formula_base_heap = h;
	  formula_base_pure = p;
	  formula_base_type = t;
	  formula_base_flow = fl;
	  formula_base_and = a;
      formula_base_label = lbl;
	  formula_base_pos = pos}) ->
          (match lbl with | None -> fmt_string ( (* "<NoLabel>" *)"" ) | Some l -> fmt_string ("(* lbl: *){"^(string_of_int (fst l))^"}->"));
          pr_h_formula h ; 
          (if not(MP.isConstMTrue p) then 
            (pr_cut_after "&" ; pr_mix_formula p))
          ;pr_cut_after  "&" ;  fmt_string (string_of_flow_formula "FLOW" fl)
        (* ; fmt_string (" LOC: " ^ (string_of_loc pos))*)
          ;if (a==[]) then ()
          else
            fmt_string ("\nAND "); pr_one_formula_list a

and prtt_pr_formula_base e =
  match e with
    | ({formula_base_heap = h;
	  formula_base_pure = p;
	  formula_base_type = t;
	  formula_base_flow = fl;
	  formula_base_and = a;
      formula_base_label = lbl;
	  formula_base_pos = pos}) ->
          (match lbl with | None -> fmt_string (  (* "<NoLabel> "*)"" ) | Some l -> fmt_string ("(* lbl: *){"^(string_of_int (fst l))^"}->"));
          prtt_pr_h_formula h ; 
          (if not(MP.isConstMTrue p) then 
            (pr_cut_after "&" ; pr_mix_formula p))
          ;()
          (* pr_cut_after  "&"; *) (*;  fmt_string (string_of_flow_formula "FLOW" fl) *)
        (* ; fmt_string (" LOC: " ^ (string_of_loc pos))*)
          (* if (a==[]) then () *)
          (* else *)
          (*   fmt_string ("\nAND "); pr_one_formula_list a *)

and prtt_pr_formula_base_inst prog e =
  match e with
    | ({formula_base_heap = h;
      formula_base_pure = p;
      formula_base_type = t;
      formula_base_flow = fl;
      formula_base_and = a;
      formula_base_label = lbl;
      formula_base_pos = pos}) ->
          (match lbl with | None -> fmt_string  ( (* "(\* <NoLabel> *\)" *) "" ) | Some l -> fmt_string ("(* lbl: *){"^(string_of_int (fst l))^"}->"));
          prtt_pr_h_formula_inst prog h ; 
          (if not( MP.isTrivMTerm p) then 
            (pr_cut_after "&" ; pr_mix_formula p))
          (* pr_cut_after "&" ; pr_mix_formula p;() *)

and pr_formula e =
  let f_b e =  pr_bracket formula_wo_paren pr_formula e in
  match e with
    | Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos}) ->
	      let arg1 = bin_op_to_list op_f_or_short formula_assoc_op f1 in
          let arg2 = bin_op_to_list op_f_or_short formula_assoc_op f2 in
          let args = arg1@arg2 in
	      pr_list_vbox_wrap "or " f_b args
    | Base e -> pr_formula_base e
    | Exists ({formula_exists_qvars = svs;
	  formula_exists_heap = h;
	  formula_exists_pure = p;
	  formula_exists_type = t;
	  formula_exists_flow = fl;
	  formula_exists_and = a;
      formula_exists_label = lbl;
	  formula_exists_pos = pos}) ->
          (match lbl with | None -> fmt_string ((* "lbl: None" *)""); | Some l -> fmt_string ("(* lbl: *){"^(string_of_int (fst l))^"}->"));
          fmt_string "(exists "; pr_list_of_spec_var svs; fmt_string ": ";
          pr_h_formula h; 
          (if not(MP.isConstMTrue p) then 
            (pr_cut_after "&" ; pr_mix_formula p))
          ; pr_cut_after  "&" ; 
          fmt_string ((string_of_flow_formula "FLOW" fl) ^  ")")
          (*;fmt_string (" LOC: " ^ (string_of_loc pos))*)
          ;if (a==[]) then ()
          else
            fmt_string ("\nAND "); pr_one_formula_list a

and prtt_pr_formula e =
  let f_b e =  pr_bracket formula_wo_paren prtt_pr_formula e in
  match e with
    | Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos}) ->
	      let arg1 = bin_op_to_list op_f_or_short formula_assoc_op f1 in
          let arg2 = bin_op_to_list op_f_or_short formula_assoc_op f2 in
          let args = arg1@arg2 in
	      pr_list_vbox_wrap "or " f_b args
    | Base e -> prtt_pr_formula_base e
    | Exists ({formula_exists_qvars = svs;
	  formula_exists_heap = h;
	  formula_exists_pure = p;
	  formula_exists_type = t;
	  formula_exists_flow = fl;
	  formula_exists_and = a;
      formula_exists_label = lbl;
	  formula_exists_pos = pos}) ->
          (match lbl with | None -> fmt_string ((* "lbl: None" *)""); | Some l -> fmt_string ("(* lbl: *){"^(string_of_int (fst l))^"}->"));
          fmt_string "EXISTS("; pr_list_of_spec_var svs; fmt_string ": ";
          prtt_pr_h_formula h; pr_cut_after "&" ;
          pr_mix_formula p; pr_cut_after  ")";
          (* fmt_string ((string_of_flow_formula "FLOW" fl)  ^  ")") *)
          (*;fmt_string (" LOC: " ^ (string_of_loc pos))*)
          if (a==[]) then ()
          else
            fmt_string ("\nAND "); pr_one_formula_list a

and prtt_pr_formula_inst prog e =
  let f_b e =  pr_bracket formula_wo_paren (prtt_pr_formula_inst prog) e in
  match e with
    | Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos}) ->
	      let arg1 = bin_op_to_list op_f_or_short formula_assoc_op f1 in
          let arg2 = bin_op_to_list op_f_or_short formula_assoc_op f2 in
          let args = arg1@arg2 in
	      pr_list_vbox_wrap "or " f_b args
    | Base e -> prtt_pr_formula_base_inst prog e
    | Exists ({formula_exists_qvars = svs;
	  formula_exists_heap = h;
	  formula_exists_pure = p;
	  formula_exists_type = t;
	  formula_exists_flow = fl;
	  formula_exists_and = a;
      formula_exists_label = lbl;
	  formula_exists_pos = pos}) ->
          (match lbl with | None -> fmt_string ((* "lbl: None" *)""); | Some l -> fmt_string ("(* lbl: *){"^(string_of_int (fst l))^"}->"));
          fmt_string "EXISTS("; pr_list_of_spec_var svs; fmt_string ": ";
          prtt_pr_h_formula_inst prog h; pr_cut_after "&" ;
          pr_mix_formula p; pr_cut_after  "&";
          (* fmt_string ((string_of_flow_formula "FLOW" fl) ^  ")") *)
          (*;fmt_string (" LOC: " ^ (string_of_loc pos))*)
          if (a==[]) then ()
          else
            fmt_string ("\nAND "); pr_one_formula_list a

and pr_formula_for_spec e =
  let print_fun = fun fml -> 
    let h,p,_,_,_ = Cformula.split_components fml in
    (pr_h_formula_for_spec h);
    fmt_string " & ";
    (pr_mix_formula p)
  in
  let disjs = Cformula.list_of_disjs e in
  pr_list_op_none " ||" (print_fun) disjs

and pr_formula_wrap e = (wrap_box ("H",1) pr_formula) e

and pr_formula_guard ((e,g):formula_guard)=
  let s1 = (prtt_pr_formula e) in
  match g with
    | None -> s1
    | Some f -> s1 ; fmt_string "|#|" ; (prtt_pr_formula f)

and pr_formula_guard_list (es: formula_guard list)=
  pr_seq "" pr_formula_guard es

and string_of_formula (e:formula) : string =  poly_string_of_pr  pr_formula e

let string_of_hrel_formula hrel: string = poly_string_of_pr pr_hrel_formula hrel

let prtt_string_of_formula_guard ((e,g):formula_guard) : string 
      =  poly_string_of_pr  prtt_pr_formula e

let prtt_string_of_formula (e:formula) : string =  poly_string_of_pr  prtt_pr_formula e

let prtt_string_of_formula_guard ((e,g):formula_guard) : string =
  let s1 = (poly_string_of_pr  prtt_pr_formula e) in
  match g with
    | None -> s1
    | Some f -> s1 ^ "|#|" ^ (poly_string_of_pr  prtt_pr_formula f)

let prtt_string_of_formula_guard_list ( es:formula_guard list) : string =
  poly_string_of_pr pr_formula_guard_list es

let prtt_string_of_formula_inst prog (e:formula) : string =  poly_string_of_pr (prtt_pr_formula_inst prog) e

let prtt_string_of_formula_base fb: string =  poly_string_of_pr  prtt_pr_formula_base fb

let prtt_string_of_h_formula (e:h_formula) : string =  poly_string_of_pr  prtt_pr_h_formula e

let prtt_string_of_h_formula_opt (eo:h_formula option) : string =
  match eo with
    | None -> ""
    | Some e -> poly_string_of_pr prtt_pr_h_formula e

let prtt_string_of_formula_opt (eo:formula option) : string =
  match eo with
    | None -> ""
    | Some e -> poly_string_of_pr prtt_pr_formula e

let rec string_of_formula_list_noparen l = match l with 
  | [] -> ""
  | h::[] -> string_of_formula h 
  | h::t -> (string_of_formula h) ^ " ;" ^ (string_of_formula_list_noparen t)
;;

let string_of_formula_list l = "["^(string_of_formula_list_noparen l)^"]" ;;


let string_of_formula_base (e:formula_base) : string =  poly_string_of_pr  pr_formula_base e

let printer_of_formula (fmt: Format.formatter) (e:formula) : unit
    = poly_printer_of_pr fmt pr_formula e

(*let pr_list_formula (e:list_formula) =  pr_seq "" pr_formula e*)    

let pr_list_formula (e:list_formula) = pr_list_op_none " " (wrap_box ("B",0) pr_formula) e

let string_of_list_formula (e:list_formula) : string =  poly_string_of_pr  pr_list_formula e

let rec pr_numbered_list_formula (count:int) (e:list_formula)  =
  match e with
    | [] -> ()
    | x::xs -> 
          begin
            fmt_open_hbox ();
            fmt_string ("<" ^ (string_of_int count) ^ ">");
            pr_formula_wrap x;
            fmt_print_newline ();
            pr_numbered_list_formula (count+1) xs ;
            fmt_close ()
        end

let pr_es_trace (trace:string list) : unit =
  if (trace==[]) then fmt_string "empty" else
  let s = List.fold_left (fun str x -> x ^ " ==> " ^ str) "" trace in
  fmt_string s

let pr_hp_rel hp_rel = 
  let pr2 = prtt_string_of_formula in
  let pr3 = (pr_triple CP.print_rel_cat pr2 pr2) in
  fmt_string (pr3 hp_rel)

let string_of_hp_rel_def hp_rel =
  (* let print_g guard= *)
  (*   (match guard with *)
  (*     | None -> "" *)
  (*           (\* fmt_string " NONE " *\) *)
  (*     | Some hf ->  *)
  (*           begin *)
  (*             " |#| " ^ (prtt_string_of_formula hf) *)
  (*           end *)
  (*    ) *)
  (* in *)
 let str_of_hp_rel (* (r,f1, g, f2) *) def =
   ( (CP.print_rel_cat def.def_cat)^ ": " ^(string_of_h_formula def.def_lhs) ^ " ::= "  ^(prtt_string_of_formula_guard_list def.def_rhs)) in
  (str_of_hp_rel hp_rel)

let string_of_hp_rel_def_short hp_rel =
 let str_of_hp_rel def = ((string_of_h_formula def.def_lhs)
     (* ^ (match guard with *)
     (*   | None -> "" *)
     (*   | Some hf -> begin *)
     (*       " |#| " ^ (prtt_string_of_formula hf) *)
     (*     end *)
     (* ) *)
 ^ " ::= "  ^(prtt_string_of_formula_guard_list def.def_rhs)) in
  (str_of_hp_rel hp_rel)

let string_of_hp_decl hpdecl =
  let name = hpdecl.Cast.hp_name in
  let pr_arg arg i =
    let t = CP.type_of_spec_var arg in
    let arg_name = string_of_spec_var arg in
    let arg_name = if(String.compare arg_name "res" == 0) then fresh_name () else arg_name in
    (CP.name_of_type t) ^  (if not !print_ann then "" else if i=NI then "@NI" else "") ^ " " ^ arg_name
  in
  let decl_kind = if hpdecl.hp_is_pre then "HeapPred " else "PostPred " in
  let pr_inst (sv, i) = (pr_arg sv i) in
  let args = pr_lst ", " pr_inst hpdecl.Cast.hp_vars_inst in
  let parts = if hpdecl.Cast.hp_part_vars = [] then "" else "#" ^((pr_list (pr_list string_of_int)) hpdecl.Cast.hp_part_vars) in
  decl_kind ^ name ^ "(" ^ args ^parts ^").\n"


let string_of_rel_decl reldecl =
  let name = reldecl.Cast.rel_name in
  let pr_arg arg =
    let t = CP.type_of_spec_var arg in
    let arg_name = string_of_spec_var arg in
    let arg_name = if(String.compare arg_name "res" == 0) then fresh_name () else arg_name in
    (CP.name_of_type t)  ^ " " ^ arg_name
  in
  let decl_kind = " relation " in
  let args = pr_lst ", " pr_arg reldecl.Cast.rel_vars in
  decl_kind ^ name ^ "(" ^ args ^ ").\n"

let string_of_hp_rels (e) : string =
  (* CP.print_only_lhs_rhs e *)
  poly_string_of_pr pr_hp_rel e

let pr_hprel_lhs_rhs (lhs,rhs) =
  (* fmt_string (CP.print_only_lhs_rhs rel) *)
  fmt_open_box 1;
  fmt_string "(";
  prtt_pr_formula lhs;
  fmt_string ")";
  fmt_string " --> ";
  prtt_pr_formula rhs;
  fmt_close()

let pr_hprel hpa=
  fmt_open_box 1;
  fmt_string (CP.print_rel_cat hpa.hprel_kind);
  (pr_seq "" (fun s -> fmt_int s)) hpa.hprel_path;
  pr_seq " unknown svl: " pr_spec_var hpa.unk_svl;
  fmt_string "; ";
  let hps = List.map (fun (hp,_) -> hp) hpa.unk_hps in
  pr_seq " unknown hps: " pr_spec_var hps;
  fmt_string "; ";
  pr_seq " predefined: " pr_spec_var hpa.predef_svl;
  fmt_string "; ";
  prtt_pr_formula hpa.hprel_lhs;
  let _ = match hpa.hprel_guard with
    | None -> ()
    | Some hf -> 
          begin
          fmt_string " |#| ";
          prtt_pr_formula hf
          end
  in
  fmt_string " --> ";
  prtt_pr_formula hpa.hprel_rhs;
  fmt_close()

let skip_cond_path_trace l = Gen.is_empty l || not(!Globals.cond_path_trace)

let pr_hprel_short hpa=
  fmt_open_box 1;
  (* fmt_string "hprel(1)"; *)
  pr_wrap_test_nocut "" skip_cond_path_trace (fun p -> fmt_string ((pr_list_round_sep ";" (fun s -> string_of_int s)) p)) hpa.hprel_path;
  (* fmt_string (CP.print_rel_cat hpa.hprel_kind); *)
  prtt_pr_formula hpa.hprel_lhs;
  let _ = match hpa.hprel_guard with
    | None -> ()
    | Some hf -> 
          begin
            fmt_string " |#| ";
            prtt_pr_formula hf
          end
  in
  fmt_string " --> ";
  prtt_pr_formula hpa.hprel_rhs;
  fmt_close()

let pr_hprel_short_inst cprog hpa=
  fmt_open_box 1;
  (* fmt_string "hprel(2)"; *)
  (* fmt_string (CP.print_rel_cat hpa.hprel_kind); *)
  if not(!Globals.is_sleek_running) then
    begin
      fmt_string ("// "^(Others.string_of_proving_kind hpa.hprel_proving_kind));
      fmt_print_newline()
    end;
  pr_wrap_test_nocut "" Gen.is_empty (* skip_cond_path_trace *) 
      (fun p -> fmt_string ((pr_list_round_sep ";" (fun s -> string_of_int s)) p)) hpa.hprel_path;
  prtt_pr_formula_inst cprog hpa.hprel_lhs;
  let _ = match hpa.hprel_guard with
    | None -> ()
          (* fmt_string " NONE " *)
    | Some hf -> 
          begin
            fmt_string " |#| ";
            prtt_pr_formula_inst cprog hf
          end
  in
  fmt_string " --> ";
  prtt_pr_formula_inst cprog hpa.hprel_rhs;
  fmt_close()

let pr_path_of (path, off)=
   (* fmt_string "PATH format"; *)
   pr_wrap_test_nocut "" skip_cond_path_trace  (fun l -> fmt_string (pr_list_round_sep ";" string_of_int l)) path
  ; (match off with
     | None -> fmt_string " NONE"
     | Some f -> fmt_string (prtt_string_of_formula f))

let pr_hprel_def hpd=
  fmt_open_box 1;
  (* fmt_string "hprel(3)"; *)
  (* fmt_string (CP.print_rel_cat hpd.hprel_def_kind); *)
  (* fmt_string "\n"; *)
  (pr_h_formula hpd.hprel_def_hrel);
  let _ = match hpd.hprel_def_guard with
    | None -> ()
          (* fmt_string " NONE " *)
    | Some hf -> 
          begin
            fmt_string " |#| ";
            prtt_pr_formula hf
          end
  in
  fmt_string " ::= ";
  fmt_cut () ;
   (* fmt_string (String.concat " \/ " (List.map pr_path_of hpd.hprel_def_body)); *)
  (pr_list_op_none " \/ " pr_path_of hpd.hprel_def_body);
  fmt_string " LIB FORM:\n";
  (pr_h_formula hpd.hprel_def_hrel);
  fmt_string " ::= ";
  fmt_cut () ;
  fmt_string ( match hpd.hprel_def_body_lib with
    | None -> " NONE"
    | Some f -> prtt_string_of_formula f);
  fmt_close()

let pr_hprel_def_short hpd=
  fmt_open_box 1;
  (* fmt_string "hprel(4)"; *)
  (* fmt_string (CP.print_rel_cat hpd.hprel_def_kind); *)
  (* fmt_string "\n"; *)
  (pr_h_formula hpd.hprel_def_hrel);
  let _ = match hpd.hprel_def_guard with
    | None -> ()
          (* fmt_string " NONE " *)
    | Some hf -> 
          begin
            fmt_string " |#| ";
            prtt_pr_formula hf
          end
  in
  fmt_string " ::=";
  (* no cut here please *)
  (* fmt_cut(); *)
  match hpd.hprel_def_body_lib with
    | None -> (pr_list_op_none " \/ " pr_path_of) hpd.hprel_def_body;
    | Some f -> prtt_pr_formula f;
   (* fmt_string (String.concat " OR " (List.map pr_path_of hpd.hprel_def_body)); *)
  (* fmt_string " LIB FORM:\n"; *)
  (* (pr_h_formula hpd.hprel_def_hrel); *)
  (* fmt_string " ::="; *)
  (* fmt_string ( match hpd.hprel_def_body_lib with *)
  (*   | None -> "UNKNOWN" *)
  (*   | Some f -> prtt_string_of_formula f); *)
  fmt_close()

let pr_hprel_def_lib hpd=
  fmt_open_box 1;
  (* fmt_string "hprel(5)"; *)
  (* fmt_string (CP.print_rel_cat hpd.hprel_def_kind); *)
  (* fmt_string "\n"; *)
  (pr_h_formula hpd.hprel_def_hrel);
  let _ = match hpd.hprel_def_guard with
    | None -> ()
          (* fmt_string " NONE " *)
    | Some hf -> 
          begin
            fmt_string " |#| ";
            prtt_pr_formula hf
          end
  in
  fmt_string " ::= ";
  fmt_cut() ;
  fmt_string (match hpd.hprel_def_body_lib with
    | None -> "NONE"
    | Some f -> prtt_string_of_formula f);
  fmt_close()

let pr_pair_path_def (path, (hf,body))=
  fmt_open_box 1;
    pr_wrap_test_nocut "relDefn " skip_cond_path_trace  (fun l -> fmt_string (pr_list_round_sep ";" string_of_int l)) path;
    fmt_string ((prtt_string_of_h_formula hf) ^ "<->" ^ (prtt_string_of_formula body));
  fmt_close()

let pr_pair_path_dang (path, hp)=
  fmt_open_box 1;
  fmt_string ("Declare_Unknown " ^ (pr_list_round string_of_int path) ^ "[" ^ (string_of_spec_var hp) ^ "]");
  fmt_close()

let string_of_hprel hp = poly_string_of_pr pr_hprel hp

let string_of_hprel_short hp = poly_string_of_pr pr_hprel_short hp

let string_of_hprel_short_inst prog hp =
  poly_string_of_pr (pr_hprel_short_inst prog) hp

let string_of_hprel_def hp = poly_string_of_pr pr_hprel_def hp

let string_of_pair_path_def pair = poly_string_of_pr pr_pair_path_def pair

let string_of_pair_path_dang pair = poly_string_of_pr pr_pair_path_dang pair

let string_of_hprel_def_short hp = poly_string_of_pr pr_hprel_def_short hp

let string_of_hprel_def_lib hp = poly_string_of_pr pr_hprel_def_lib hp

let pr_par_def (f1,f2,f3) = 
  (* fmt_string (CP.print_only_lhs_rhs rel) *)
  fmt_open_box 1;
  fmt_string "(";
  pr_formula f1;
  fmt_string ")";
  fmt_string " --> ";
  pr_formula f2;
  fmt_string " --> ";
  pr_formula f3;
  fmt_close()

let string_of_hprel_lhs_rhs e = poly_string_of_pr pr_hprel_lhs_rhs e
let string_of_par_def e = poly_string_of_pr pr_par_def e

let pr_lhs_rhs ((cat,lhs,rhs) as rel) = 
  fmt_string (CP.print_lhs_rhs rel)
  (* fmt_open_box 1; *)
  (* pr_pure_formula lhs; *)
  (* fmt_string "-->"; *)
  (* pr_pure_formula rhs; *)
  (* fmt_close() *)

let string_of_lhs_rhs (e) : string =  
  (* CP.print_only_lhs_rhs e *)
  poly_string_of_pr  pr_lhs_rhs e

let pr_only_lhs_rhs (lhs,rhs) = 
  (* fmt_string (CP.print_only_lhs_rhs rel) *)
  fmt_open_box 1;
  fmt_string "(";
  pr_pure_formula lhs;
  fmt_string ")";
  fmt_string " --> ";
  pr_pure_formula rhs;
  fmt_close()

let string_of_only_lhs_rhs (e) : string =  poly_string_of_pr  pr_only_lhs_rhs e

let pr_infer_state_short is =
  fmt_open_box 1;
  fmt_string (string_of_spec_var_list (List.map fst is.is_link_hpargs));
  fmt_string (pr_list_round string_of_int is.is_cond_path);
  fmt_string (pr_list_ln string_of_hprel_short is.is_constrs);
  fmt_string (pr_list_ln string_of_hprel_short is.is_all_constrs);
  fmt_string (pr_list_ln string_of_hp_rel_def is.is_hp_defs);
  fmt_close()

let string_of_infer_state_short is: string =  poly_string_of_pr  pr_infer_state_short is

let rec pr_numbered_list_formula_trace_ho (e:(context * (formula*formula_trace)) list) (count:int) f =
  match e with
    | [] -> ()
    | (ctx,(a,b))::xs -> 
          begin
          let lh = collect_pre_heap ctx in
          let lp = collect_pre_pure ctx in
          let lrel = collect_rel ctx in
          let hprel = collect_hp_rel ctx in
          let term_err = collect_term_err ctx in
          fmt_open_vbox 0;
          pr_wrap (fun _ -> fmt_string ("<" ^ (string_of_int count) ^ ">"); pr_formula a) ();
          pr_wrap_test "" Gen.is_empty (pr_seq "" fmt_string) term_err;
          pr_wrap_test "inferred heap: " Gen.is_empty  (pr_seq "" pr_h_formula) (lh); 
          pr_wrap_test "inferred pure: " Gen.is_empty  (pr_seq "" pr_pure_formula) (lp); 
          pr_wrap_test "inferred rel: " Gen.is_empty  (pr_seq "" pr_lhs_rhs) (lrel); 
          pr_wrap_test "inferred hprel: " Gen.is_empty  (pr_seq "" pr_hprel_short) (hprel); 
          f b;
          fmt_print_newline ();
          fmt_close_box ();
          pr_numbered_list_formula_trace_ho xs (count+1) f;
          end

let rec pr_numbered_list_formula_trace_ho_inst cprog (e:(context * (formula*formula_trace)) list) (count:int) f =
  match e with
    | [] -> ()
    | (ctx,(a,b))::xs -> 
          begin
          let lh = collect_pre_heap ctx in
          let lp = collect_pre_pure ctx in
          let lrel = collect_rel ctx in
          let hprel = collect_hp_rel ctx in
          let term_err = collect_term_err ctx in
          fmt_open_vbox 0;
          pr_wrap (fun _ -> fmt_string ("<" ^ (string_of_int count) ^ ">"); pr_formula a) ();
          pr_wrap_test "" Gen.is_empty (pr_seq "" fmt_string) term_err;
          pr_wrap_test "inferred heap: " Gen.is_empty  (pr_seq "" pr_h_formula) (lh); 
          pr_wrap_test "inferred pure: " Gen.is_empty  (pr_seq "" pr_pure_formula) (lp); 
          pr_wrap_test "inferred rel: " Gen.is_empty  (pr_seq "" pr_lhs_rhs) (lrel); 
          pr_wrap_test "inferred hprel: " Gen.is_empty  (pr_seq "" (pr_hprel_short_inst cprog)) (hprel); 
          f b;
          fmt_print_newline ();
          fmt_close_box ();
          pr_numbered_list_formula_trace_ho_inst cprog xs (count+1) f;
        end

let pr_numbered_list_formula_trace (e:(context * (formula*formula_trace)) list) (count:int) =
  let f b = begin
            fmt_string "\n";
            fmt_string "[[";
            pr_es_trace b;
            fmt_string "]]"
  end in
  (* let f b = () in *)
  pr_numbered_list_formula_trace_ho (e) (count:int) f

let pr_numbered_list_formula_trace_inst cprog (e:(context * (formula*formula_trace)) list) (count:int) =
  let f b = begin
            fmt_string "\n";
            fmt_string "[[";
            pr_es_trace b;
            fmt_string "]]"
  end in
  (* let f b = () in *)
  (pr_numbered_list_formula_trace_ho_inst cprog) (e) (count:int) f

let pr_numbered_list_formula_no_trace (e:(context * (formula*formula_trace)) list) (count:int) =
  let f b = () in
  pr_numbered_list_formula_trace_ho e (count:int) f 

let string_of_numbered_list_formula (e:list_formula) : string =  
   poly_string_of_pr (pr_numbered_list_formula 1) e

let string_of_numbered_list_formula_trace (e: (context * (formula*formula_trace)) list) : string =  
  poly_string_of_pr (pr_numbered_list_formula_trace e) 1
  (* pr_numbered_list_formula_trace e 1 *)

let string_of_numbered_list_formula_trace_inst prog (e: (context * (formula*formula_trace)) list) : string =  
  poly_string_of_pr (pr_numbered_list_formula_trace_inst prog e) 1

let string_of_numbered_list_formula_no_trace (e: (context * (formula*formula_trace)) list) : string =  
  poly_string_of_pr (pr_numbered_list_formula_no_trace e) 1
  (* pr_numbered_list_formula_no_trace e 1 *)

let string_of_list_f (f:'a->string) (e:'a list) : string =  
  "["^(String.concat "," (List.map f e))^"]"

let printer_of_list_formula (fmt: Format.formatter) (e:list_formula) : unit = 
  poly_printer_of_pr fmt pr_list_formula e

let string_of_pure_formula_branches (f, l) : string =  
  poly_string_of_pr  pr_pure_formula_branches (f, l)

let string_of_memo_pure_formula_branches (f, l) : string =
  poly_string_of_pr  pr_memo_pure_formula_branches (f, l)

let string_of_memo_pure_formula (f: memo_pure) : string = 
  poly_string_of_pr  pr_memo_pure_formula f

let string_of_memoised_group g =
  poly_string_of_pr pr_memoise_group [g]

let string_of_mix_formula (f: MP.mix_formula) : string = 
  poly_string_of_pr pr_mix_formula f

let rec string_of_mix_formula_list_noparen l = match l with 
  | [] -> ""
  | h::[] -> string_of_mix_formula h 
  | h::t -> (string_of_mix_formula h) ^ " ;" ^ (string_of_mix_formula_list_noparen t)
;;

let string_of_mix_formula_list l = "["^(string_of_mix_formula_list_noparen l)^"]" ;;

let pr_case_guard c = 
  fmt_string "{";
  pr_seq "\n" (fun (c1,c2)-> pr_b_formula c1 ;fmt_string "->"; pr_seq_nocut "," pr_formula_label c2) c;
  fmt_string "}"

let string_of_case_guard c = poly_string_of_pr pr_case_guard c
  
(* pretty printing for a spec_var list *)
let rec string_of_spec_var_list_noparen l = match l with 
  | [] -> ""
  | h::[] -> string_of_spec_var h 
  | h::t -> (string_of_spec_var h) ^ "," ^ (string_of_spec_var_list_noparen t)
;;

let string_of_spec_var_list l = "["^(string_of_spec_var_list_noparen l)^"]" ;;

let string_of_typed_spec_var_list l = "["^(Gen.Basic.pr_list string_of_typed_spec_var l)^"]" ;;

let rec pr_struc_formula  (e:struc_formula) = match e with
    | ECase { formula_case_branches  =  case_list ; formula_case_pos = _} ->
		  fmt_string "ECase ";
         (* fmt_string (string_of_pos p.start_pos);*)
          pr_args  (Some("V",1)) (Some "A") "case " "{" "}" ";"
              (fun (c1,c2) -> wrap_box ("B",0) (pr_op_adhoc (fun () -> pr_pure_formula c1) " -> " )
                  (fun () -> pr_struc_formula c2)) case_list
    | EBase { formula_struc_implicit_inst = ii; formula_struc_explicit_inst = ei; formula_struc_exists = ee; formula_struc_base = fb;
	  formula_struc_continuation = cont; formula_struc_pos = _ } ->
		  fmt_string "EBase ";
          (* fmt_string (string_of_pos p.start_pos);*)
          fmt_open_vbox 2;
          wrap_box ("B",0) (fun fb ->
			  if not(Gen.is_empty(ee@ii@ei)) then
			    begin
				  fmt_string "exists ";
				  pr_seq "(Expl)" pr_spec_var ei;
				  pr_seq "(Impl)" pr_spec_var ii;
				  pr_seq "(ex)" pr_spec_var ee;
			    end;
			  pr_formula fb) fb;
          (match cont with 
			| None -> ()
			| Some l -> 
	        begin
	          fmt_cut();
	          wrap_box ("B",0) pr_struc_formula l;
            end);
          fmt_close();
    | EAssume {
			formula_assume_vars = x;
			formula_assume_simpl = b;
			formula_assume_lbl = (y1,y2);
			formula_assume_ensures_type = t;
			formula_assume_struc = s;}->
          wrap_box ("V",2)
              (fun b ->
                let assume_str = match t with
                                 | None -> "EAssume "
                                 | Some true -> "EAssume_exact "
                                 | Some false -> "EAssume_inexact " in
	              fmt_string assume_str;
	              pr_formula_label (y1,y2);
	              if not(Gen.is_empty(x)) then pr_seq_nocut "ref " pr_spec_var x;
	              fmt_cut();
	              wrap_box ("B",0) pr_formula b;
				  fmt_cut();
				  if !print_assume_struc then 
				  (fmt_string "struct:";
				  wrap_box ("B",0) pr_struc_formula s)
				  else ()) b
    | EInfer {
      formula_inf_post = postf;
      formula_inf_xpost = postxf;
      formula_inf_vars = lvars;
      formula_inf_continuation = cont;} ->
          let ps =if (lvars==[] && postf) then "@post " else "" in
      fmt_open_vbox 2;
      fmt_string ("EInfer "^ps^string_of_spec_var_list lvars);
      fmt_cut();
      wrap_box ("B",0) pr_struc_formula cont;
      fmt_close();
	| EList b ->  if b==[] then fmt_string "[]" else pr_list_op_none "|| " (wrap_box ("B",0) (pr_pair_aux pr_spec_label_def_opt pr_struc_formula)) b
	(*| EOr b -> 
	      let arg1 = bin_op_to_list op_f_or_short struc_formula_assoc_op b.formula_struc_or_f1 in
          let arg2 = bin_op_to_list op_f_or_short struc_formula_assoc_op b.formula_struc_or_f2 in
		  let f_b e =  pr_bracket struc_formula_wo_paren pr_struc_formula e in
	      pr_list_vbox_wrap "eor " f_b (arg1@arg2)*)
	
let rec pr_struc_formula_for_spec (e:struc_formula) = 
  let res = match e with
  | ECase {formula_case_branches = case_list} ->
    pr_args (Some("V",1)) (Some "A") "case " "{" "}" "" 
    (
      fun (c1,c2) -> wrap_box ("B",0) (pr_op_adhoc (fun () -> pr_pure_formula c1) " -> " )
        (fun () -> pr_struc_formula_for_spec c2; fmt_string ";")
    ) case_list
  | EBase {formula_struc_implicit_inst = ii; formula_struc_explicit_inst = ei;
    formula_struc_exists = ee; formula_struc_base = fb; formula_struc_continuation = cont} ->
        fmt_string "requires ";
        pr_formula_for_spec fb;
        (match cont with 
      | None -> ()
      | Some l -> pr_struc_formula_for_spec l;
    );
  | EAssume  {
			formula_assume_vars = x;
			formula_assume_simpl = b;
			formula_assume_lbl = (y1,y2);
			formula_assume_ensures_type = t;
			formula_assume_struc = s;}->
    let ensures_str = match t with
                     | None -> "\n ensures "
                     | Some true -> "\n ensures_exact "
                     | Some false -> "\n ensures_inexact " in
    fmt_string ensures_str;
    pr_formula_for_spec b;
    fmt_string ";";
	if !print_assume_struc then 
	  (fmt_string "struct:";
	   wrap_box ("B",0) pr_struc_formula_for_spec s)
	 else ()
  | EInfer b -> fmt_string ("infer" ^ (string_of_spec_var_list b.formula_inf_vars)) ;
        pr_struc_formula_for_spec b.formula_inf_continuation
            (* report_error no_pos "Do not expect EInfer at this level" *)
  | EList b -> if b==[] then fmt_string "" else pr_list_op_none "|| " (fun (l,c) -> pr_struc_formula_for_spec c) b
  (*| EOr b ->
    let arg1 = bin_op_to_list op_f_or_short struc_formula_assoc_op b.formula_struc_or_f1 in
    let arg2 = bin_op_to_list op_f_or_short struc_formula_assoc_op b.formula_struc_or_f2 in
    let f_b e = pr_bracket struc_formula_wo_paren pr_struc_formula_for_spec e in
    pr_list_vbox_wrap "eor " f_b (arg1@arg2) *)
  in
  res

let rec pr_struc_formula_for_spec_inst prog (e:struc_formula) =
  let pr_helper = pr_struc_formula_for_spec_inst prog in
  let res = match e with
  | ECase {formula_case_branches = case_list} ->
    pr_args (Some("V",1)) (Some "A") "case " "{" "}" "" 
    (
      fun (c1,c2) -> wrap_box ("B",0) (pr_op_adhoc (fun () -> pr_pure_formula c1) " -> " )
        (fun () -> pr_helper c2; fmt_string ";")
    ) case_list
  | EBase {formula_struc_implicit_inst = ii; formula_struc_explicit_inst = ei;
    formula_struc_exists = ee; formula_struc_base = fb; formula_struc_continuation = cont} ->
        let _ = if isTrivTerm fb then () else begin
          fmt_string "requires ";
          prtt_pr_formula_inst prog fb;
          ()
        end
        in
    (match cont with 
      | None -> ()
      | Some l -> pr_helper l;
    );
  | EAssume  {
			formula_assume_vars = x;
			formula_assume_simpl = b;
			formula_assume_lbl = (y1,y2);
			formula_assume_ensures_type = t;
			formula_assume_struc = s;}->
    let ensures_str = match t with
                     | None -> "\n ensures "
                     | Some true -> "\n ensures_exact "
                     | Some false -> "\n ensures_inexact " in
    fmt_string ensures_str;
    prtt_pr_formula_inst prog b;
    fmt_string ";";
	if !print_assume_struc then 
	  (fmt_string "struct:";
	   wrap_box ("B",0) pr_helper s)
	 else ()
  | EInfer b-> fmt_string ("infer" ^ (string_of_spec_var_list b.formula_inf_vars)) ;
        pr_helper b.formula_inf_continuation
  | EList b -> if b==[] then fmt_string "" else pr_list_op_none "|| " (fun (l,c) -> pr_helper c) b
  in
  res

(*let string_of_ext_formula (e:ext_formula) : string =  poly_string_of_pr  pr_ext_formula e

let printer_of_ext_formula (fmt: Format.formatter) (e:ext_formula) : unit =
  poly_printer_of_pr fmt pr_ext_formula e*)

let string_of_struc_formula (e:struc_formula) : string =  poly_string_of_pr  pr_struc_formula e

let string_of_struc_formula_for_spec (e:struc_formula): string = poly_string_of_pr pr_struc_formula_for_spec e

let string_of_struc_formula_for_spec_inst prog (e:struc_formula): string = poly_string_of_pr (pr_struc_formula_for_spec_inst prog) e

let printer_of_struc_formula (fmt: Format.formatter) (e:struc_formula) : unit =
  poly_printer_of_pr fmt pr_struc_formula e

let string_of_prior_steps pt =
  (String.concat "\n " (List.rev pt))


let pr_path_trace  (pt:((int * 'a) * int) list) =
  pr_seq "" (fun (c1,c3)-> fmt_string "("; (pr_op_adhoc (fun () -> pr_formula_label c1)  "," (fun () -> fmt_int c3)); fmt_string ")") pt  
let string_of_path_trace  (pt : path_trace) = poly_string_of_pr  pr_path_trace pt
let printer_of_path_trace (fmt: Format.formatter) (pt : path_trace) =  poly_printer_of_pr fmt pr_path_trace pt


let summary_list_path_trace l =  String.concat "; " (List.map  (fun (lbl,_) -> string_of_path_trace lbl) l)

let summary_partial_context (l1,l2) =  "PC("^string_of_int (List.length l1) ^", "^ string_of_int (List.length l2)(* ^" "^(summary_list_path_trace l2) *)^")"

let summary_failesc_context (l1,l2,l3) =
  let len_l2 = List.fold_left (fun  n (_,l) -> n+(List.length l)) 0 l2 
    (* compute number of escaped state for all blocks *)
  in 
	"FEC("^string_of_int (List.length l1) ^", "^ string_of_int (len_l2) ^", "^ string_of_int (List.length l3) 
	^" "^(summary_list_path_trace l3)
    ^")"

let summary_list_partial_context lc =  "["^(String.concat " " (List.map summary_partial_context lc))^"]"

let summary_list_failesc_context lc = "["^(String.concat " " (List.map summary_failesc_context lc))^"]"

let string_of_pos p = " "^(string_of_int p.start_pos.Lexing.pos_lnum)^":"^
				(string_of_int (p.start_pos.Lexing.pos_cnum - p.start_pos.Lexing.pos_bol));;

  (* if String.length(hdr)>7 then *)
  (*   ( fmt_string hdr;  fmt_cut (); fmt_string "  "; wrap_box ("B",2) f  x) *)
  (* else  (wrap_box ("B",0) (fun x -> fmt_string hdr; f x)  x) *)



let pr_estate (es : entail_state) =
  fmt_open_vbox 0;
  pr_vwrap_nocut "es_formula: " pr_formula  es.es_formula; 
  pr_wrap_test "es_pure: " MCP.isConstMTrue pr_mix_formula es.es_pure;
  pr_wrap_test "es_orig_ante: " Gen.is_None (pr_opt pr_formula) es.es_orig_ante; 
  (*pr_vwrap "es_orig_conseq: " pr_struc_formula es.es_orig_conseq;  *)
  if (!Debug.devel_debug_print_orig_conseq == true) then pr_vwrap "es_orig_conseq: " pr_struc_formula es.es_orig_conseq  else ();
  pr_wrap_test "es_heap: " is_empty_heap pr_h_formula es.es_heap;
  pr_wrap_test "es_history: " Gen.is_empty (pr_seq "" pr_h_formula) es.es_history;
  (*pr_wrap_test "es_prior_steps: "  Gen.is_empty (fun x -> fmt_string (string_of_prior_steps x)) es.es_prior_steps;*)
  (* pr_wrap_test "es_ante_evars: " Gen.is_empty (pr_seq "" pr_spec_var) es.es_ante_evars; *)
  pr_wrap_test "es_ivars: "  Gen.is_empty (pr_seq "" pr_spec_var) es.es_ivars;
  (* pr_wrap_test "es_expl_vars: " Gen.is_empty (pr_seq "" pr_spec_var) es.es_expl_vars; *)
  pr_wrap_test "es_evars: " Gen.is_empty (pr_seq "" pr_spec_var) es.es_evars;
  pr_wrap_test "es_ante_evars: " Gen.is_empty (pr_seq "" pr_spec_var) es.es_ante_evars;
  pr_wrap_test "es_gen_expl_vars: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_gen_expl_vars;
  pr_wrap_test "es_gen_impl_vars: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_gen_impl_vars; 
  pr_wrap_test "es_rhs_eqset: " Gen.is_empty  (pr_seq "" (pr_pair_aux pr_spec_var pr_spec_var)) (es.es_rhs_eqset); 
  pr_wrap_test "es_subst (from): " Gen.is_empty  (pr_seq "" pr_spec_var) (fst es.es_subst); 
  pr_wrap_test "es_subst (to): " Gen.is_empty  (pr_seq "" pr_spec_var) (snd es.es_subst); 
  pr_wrap_test "es_aux_conseq: "  CP.isConstTrue (pr_pure_formula) es.es_aux_conseq; 
  (* pr_wrap_test "es_imm_pure_stk: " Gen.is_empty  (pr_seq "" pr_mix_formula) es.es_imm_pure_stk; *)
  pr_wrap_test "es_must_error: "  Gen.is_None (pr_opt (fun (s,_) -> fmt_string s)) (es.es_must_error); 
  (* pr_wrap_test "es_success_pts: " Gen.is_empty (pr_seq "" (fun (c1,c2)-> fmt_string "(";(pr_op pr_formula_label c1 "," c2);fmt_string ")")) es.es_success_pts; *)
  (* pr_wrap_test "es_residue_pts: " Gen.is_empty (pr_seq "" pr_formula_label) es.es_residue_pts; *)
  (* pr_wrap_test "es_path_label: " Gen.is_empty pr_path_trace es.es_path_label; *)
  pr_wrap_test "es_cond_path: " Gen.is_empty (pr_seq "" (fun s -> fmt_int s)) es.es_cond_path;
  pr_wrap_test "es_var_measures 1: " Gen.is_None (pr_opt (fun (t_ann, l1, l2) ->
    fmt_string (string_of_term_ann t_ann);
    pr_seq "" pr_formula_exp l1; pr_set pr_formula_exp l2;
  )) es.es_var_measures;
  pr_wrap_test "es_var_stack: " Gen.is_empty (pr_seq "" (fun s -> fmt_string s)) es.es_var_stack;
  pr_wrap_test "es_term_err: " Gen.is_None (pr_opt (fun msg -> fmt_string msg)) (es.es_term_err);
  (*
  pr_vwrap "es_var_label: " (fun l -> fmt_string (match l with
                                                    | None -> "None"
                                                    | Some i -> string_of_int i)) es.es_var_label;
  *)
  if es.es_trace!=[] then
    pr_vwrap "es_trace: " pr_es_trace es.es_trace;
  if es.es_is_normalizing then
    pr_vwrap "es_is_normalizing: " fmt_bool es.es_is_normalizing;
  (*
  pr_vwrap "es_var_ctx_lhs: " pr_pure_formula es.es_var_ctx_lhs;
  pr_vwrap "es_var_ctx_rhs: " pr_pure_formula es.es_var_ctx_rhs;
  pr_vwrap "es_var_loc: " (fun pos -> fmt_string (string_of_pos pos)) es.es_var_loc;
  *)
  pr_wrap_test "es_infer_vars: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_infer_vars;
  (* pr_wrap_test "es_infer_vars_rel: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_infer_vars_rel; *)
  pr_vwrap "es_infer_vars_rel: "   (pr_seq "" pr_spec_var) es.es_infer_vars_rel;
  pr_wrap_test "es_infer_vars_hp_rel: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_infer_vars_hp_rel;
(*  pr_vwrap "es_infer_label:  " pr_formula es.es_infer_label;*)
  pr_wrap_test "es_infer_heap: " Gen.is_empty  (pr_seq "" pr_h_formula) es.es_infer_heap; 
  pr_wrap_test "es_infer_pure: " Gen.is_empty  (pr_seq "" pr_pure_formula) es.es_infer_pure; 
  pr_wrap_test "es_infer_hp_rel: " Gen.is_empty  (pr_seq "" pr_hprel_short) es.es_infer_hp_rel; 
   pr_wrap_test "es_infer_rel: " Gen.is_empty  (pr_seq "" pr_lhs_rhs) es.es_infer_rel; 
  (* pr_wrap_test "es_infer_pures: " Gen.is_empty  (pr_seq "" pr_pure_formula) es.es_infer_pures;  *)
  (* pr_wrap_test "es_infer_invs: " Gen.is_empty  (pr_seq "" pr_pure_formula) es.es_infer_invs;  *)
   if (es.es_var_zero_perm!=[]) then
     pr_wrap_test "es_var_zero_perm: " (fun _ -> false) (pr_seq "" pr_spec_var) es.es_var_zero_perm; (*always print*)
  (* pr_vwrap "es_infer_invs:  " pr_list_pure_formula es.es_infer_invs; *)
  pr_wrap_test "es_unsat_flag: " (fun x-> x) (fun c-> fmt_string (string_of_bool c)) es.es_unsat_flag;  
  (* pr_wrap_test "es_proof_traces: " Gen.is_empty  (pr_seq "" (pr_pair_aux pr_formula pr_formula)) es.es_proof_traces; *)
  fmt_close ()

let pr_estate_infer_hp (es : entail_state) =
  fmt_open_vbox 0;
  pr_vwrap_nocut "es_formula: " pr_formula  es.es_formula; 
  pr_wrap_test "es_infer_vars: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_infer_vars;
  pr_wrap_test "es_infer_vars_rel: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_infer_vars_rel;
  pr_wrap_test "es_infer_vars_hp_rel: " Gen.is_empty  (pr_seq "" pr_spec_var) es.es_infer_vars_hp_rel;
(*  pr_vwrap "es_infer_label:  " pr_formula es.es_infer_label;*)
  pr_wrap_test "es_infer_heap: " Gen.is_empty  (pr_seq "" pr_h_formula) es.es_infer_heap; 
  pr_wrap_test "es_infer_pure: " Gen.is_empty  (pr_seq "" pr_pure_formula) es.es_infer_pure; 
  pr_wrap_test "es_infer_hp_rel: " Gen.is_empty  (pr_seq "" pr_hprel_short) es.es_infer_hp_rel; 
   pr_wrap_test "es_infer_rel: " Gen.is_empty  (pr_seq "" pr_lhs_rhs) es.es_infer_rel; 
  fmt_close ()

let string_of_estate (es : entail_state) : string =  poly_string_of_pr  pr_estate es
let string_of_estate_infer_hp (es : entail_state) : string =  poly_string_of_pr  pr_estate_infer_hp es
let printer_of_estate (fmt: Format.formatter) (es: entail_state) : unit = poly_printer_of_pr fmt pr_estate es

let string_of_entail_state  =  string_of_estate
let string_of_entail_state_infer_hp  =  string_of_estate_infer_hp

and string_of_failure_kind e_kind=
match e_kind with
  | Failure_May _ -> "MAY"
  | Failure_Must _ -> "MUST"
  | Failure_Bot _ -> "Bot"
  | Failure_Valid -> "Valid"

and string_of_failure_kind_full e_kind=
match e_kind with
  | Failure_May s -> "MAY:" ^s
  | Failure_Must s -> "MUST"^s
  | Failure_Bot _ -> "Bot"
  | Failure_Valid -> "Valid"

let string_of_list_loc ls = String.concat ";" (List.map string_of_loc ls)

let string_of_list_int ls = String.concat ";" (List.map string_of_int ls)

let string_of_fail_explaining fe=
  fmt_open_vbox 1;
  pr_vwrap "fe_kind: " fmt_string (string_of_failure_kind fe.fe_kind);
  pr_vwrap "fe_name: " fmt_string (fe.fe_name);
  pr_vwrap "fe_locs: " fmt_string (string_of_list_int(*_loc*) fe.fe_locs);
(*  fe_sugg = struc_formula *)
  fmt_close ()

let pr_fail_estate (es:fail_context) =
  fmt_open_vbox 1; fmt_string "{";
  (*pr_wrap_test "es_prior_steps: "  Gen.is_empty (fun x -> fmt_string (string_of_prior_steps x)) es.fc_prior_steps;*)
  (* pr_wrap_test_nocut "fc_prior_steps: " Gen.is_empty (fun x -> fmt_string (string_of_prior_steps x)) es.fc_prior_steps; *)(* prior steps in reverse order *)
  pr_vwrap "fc_message: "  fmt_string es.fc_message;
  pr_vwrap "fc_current_lhs_flow: " fmt_string (string_of_flow_formula "FLOW"
                                                   (flow_formula_of_formula es.fc_current_lhs.es_formula)) ;
   (*pr_vwrap "fc_current_lhs: " pr_estate es.fc_current_lhs;  (* LHS context with success points *)*)
(*   pr_vwrap "fc_orig_conseq: " pr_struc_formula es.fc_orig_conseq; (* RHS conseq at the point of failure *)*)
(*   pr_vwrap "fc_current_conseq: " pr_formula es.fc_current_conseq; *)
   (*pr_wrap_test "fc_failure_pts: "Gen.is_empty (pr_seq "" pr_formula_label) es.fc_failure_pts; *)  (* failure points in conseq *)
  fmt_string "}"; 
  fmt_close ()
  
let string_of_fail_estate (es:fail_context) : string =  poly_string_of_pr  pr_fail_estate es
let printer_of_fail_estate (fmt: Format.formatter) (es: fail_context) : unit =
  poly_printer_of_pr fmt pr_fail_estate es

let ctx_assoc_op (e:context) : (string * context list) option = 
  match e with
    | OCtx (e1,e2) -> Some ("|",[e1;e2])
    | _ -> None

let rec pr_context (ctx: context) =
  let f_b e =  match e with
    | Ctx es ->  wrap_box ("B",1) pr_estate es
    | _ -> failwith "cannot be an OCtx"
  in match ctx with
    | Ctx es -> f_b ctx
    | OCtx (c1, c2) -> 
          let args = bin_op_to_list "|" ctx_assoc_op ctx in
          pr_list_op_vbox "CtxOR" f_b args

let string_of_context (ctx: context): string =  poly_string_of_pr  pr_context ctx
let printer_of_context (fmt: Format.formatter) (ctx: context) : unit = poly_printer_of_pr fmt pr_context ctx

let pr_context_list ctx =  pr_seq "" pr_context ctx    
let string_of_context_list ctx : string =  poly_string_of_pr  pr_context_list ctx
let printer_of_context_list (fmt: Format.formatter) (ctx: context list) : unit =  poly_printer_of_pr fmt pr_context_list ctx  

let rec pr_fail_type_x (e:fail_type) =
  fmt_string (" Fail-type printing suppressed : due to looping bug e.g. bug_qsort.ss ")

(* infinite loop with list_open_args for some examples, e.g. bug_qsort.ss *)
let rec pr_fail_type (e:fail_type) =
  let f_b e =  pr_bracket ft_wo_paren pr_fail_type e in
  match e with
    | Trivial_Reason (fe,ft) ->
          fmt_string (" Trivial fail : "^ (string_of_failure_kind_full fe.fe_kind));
          (* print trace *)
          fmt_string "\n"; fmt_string "[["; pr_es_trace ft; fmt_string "]]"
    | Basic_Reason (br,fe,ft) -> 
          (string_of_fail_explaining fe);
          if fe.fe_kind=Failure_Valid then fmt_string ("Failure_Valid") 
          else (pr_fail_estate br);
          (* print trace *)
          fmt_string "\n"; fmt_string "[["; pr_es_trace ft; fmt_string "]]"
    | ContinuationErr (br,ft) ->
          fmt_string ("ContinuationErr "); pr_fail_estate br;
          (* print trace *)
          fmt_string "\n"; fmt_string "[["; pr_es_trace ft; fmt_string "]]"
    | Or_Reason _ ->
          let args = bin_op_to_list op_or_short ft_assoc_op e in
          if ((List.length args) < 2) then fmt_string ("Illegal pr_fail_type OR_Reason")
          else pr_list_vbox_wrap "FAIL_OR " f_b args
    | Union_Reason _ ->
          let args = bin_op_to_list op_union_short ft_assoc_op e in
          if ((List.length args) < 2) then fmt_string ("Illegal pr_fail_type UNION_Reason")
          else pr_list_vbox_wrap "FAIL_UNION " f_b args
    | Or_Continuation _ -> fmt_string (" Or_Continuation ");
          let args = bin_op_to_list op_or_short ft_assoc_op e in
          if ((List.length args) < 2) then fmt_string ("Illegal pr_fail_type OR_Continuation")
          else  pr_list_vbox_wrap "CONT_OR " f_b args
    | And_Reason _ ->
          let args = bin_op_to_list op_and_short ft_assoc_op e in
          if ((List.length args) < 2) then fmt_string ("Illegal pr_fail_type AND_Reason")
          else pr_list_vbox_wrap "FAIL_AND " f_b args

let string_of_fail_type (e:fail_type) : string =  poly_string_of_pr  pr_fail_type e

let printer_of_fail_type (fmt: Format.formatter) (e:fail_type) : unit =
  poly_printer_of_pr fmt pr_fail_type e

let pr_list_context (ctx:list_context) =
  match ctx with
    | FailCtx ft -> fmt_cut ();fmt_string "MaybeErr Context: "; 
        (* (match ft with *)
        (*     | Basic_Reason (_, fe) -> (string_of_fail_explaining fe) (\*useful: MUST - OK*\) *)
        (*     (\* TODO : to output must errors first *\) *)
        (*     (\* | And_Reason (_, _, fe) -> (string_of_fail_explaining fe) *\) *)
        (*     | _ -> fmt_string ""); *)
        pr_fail_type ft; fmt_cut ()
    | SuccCtx sc -> let str = 
        if (get_must_error_from_ctx sc)==None then "Good Context: "
        else "Error Context: " in
      fmt_cut (); fmt_string str; fmt_int (List.length sc); pr_context_list sc; fmt_cut ()

let pr_context_short (ctx : context) = 
  let rec f xs = match xs with
    | Ctx e -> [(e.es_formula,e.es_heap,e.es_infer_vars@e.es_infer_vars_rel,e.es_infer_heap,e.es_infer_pure,e.es_infer_rel,
      e.es_var_measures,e. es_var_zero_perm,e.es_trace,e.es_cond_path, e.es_proof_traces, e.es_ante_evars(* , e.es_subst_ref *))]
    | OCtx (x1,x2) -> (f x1) @ (f x2) in
  let pr (f,eh,(* ac, *)iv,ih,ip,ir,vm,vperms,trace,ecp, ptraces,evars(* , vars_ref *)) =
    fmt_open_vbox 0;
    let f1 = f
      (* if !Globals.print_en_tidy *)
      (* then Cformula.shorten_formula f *)
      (* else f *)
    in pr_formula_wrap f1;
    pr_wrap_test "es_heap: " (fun _ -> false)  (pr_h_formula) eh;
    pr_wrap_test "es_var_zero_perm: " Gen.is_empty  (pr_seq "" pr_spec_var) vperms;
    pr_wrap_test "es_infer_vars/rel: " Gen.is_empty  (pr_seq "" pr_spec_var) iv;
    (*pr_wrap (fun _ -> fmt_string "es_aux_conseq: "; pr_pure_formula ac) ();*)
    pr_wrap_test "es_infer_heap: " Gen.is_empty  (pr_seq "" pr_h_formula) ih; 
    pr_wrap_test "es_infer_pure: " Gen.is_empty  (pr_seq "" pr_pure_formula) ip;
    pr_wrap_test "es_infer_rel: " Gen.is_empty  (pr_seq "" pr_lhs_rhs) ir;  
    pr_wrap_opt "es_var_measures 2: " pr_var_measures vm;
    (* pr_vwrap "es_trace: " pr_es_trace trace; *)
    (* pr_wrap_test "es_subst_ref: " Gen.is_empty  (pr_seq "a" (pr_pair_aux pr_spec_var pr_spec_var)) vars_ref;  *)
    pr_wrap_test "es_cond_path: " Gen.is_empty (pr_seq "" (fun s -> fmt_int s)) ecp;
    pr_wrap_test "es_proof_traces: " Gen.is_empty (pr_seq "" (pr_pair_aux pr_formula pr_formula)) ptraces;
	pr_wrap_test "es_ante_evars: " Gen.is_empty (pr_seq "" pr_spec_var) evars;
    fmt_string "\n";
    fmt_close_box();
  in 
  let pr_disj ls = 
    if (List.length ls == 1) then pr (List.hd ls)
    else pr_seq "or" pr ls in
  (pr_disj (f ctx))

let pr_formula_vperm (f,vp) =
  fmt_open_vbox 1;
  pr_formula_wrap f;
  pr_wrap_test "@zero: " Gen.is_empty  (pr_seq "" pr_spec_var) vp;
  fmt_close_box ()

let pr_formula_vperm_wrap t =
    (wrap_box ("H",1) pr_formula_vperm) t

let pr_context_list_short (ctx : context list) = 
  let rec f xs = match xs with
    | Ctx e -> [(e.es_formula,e.es_infer_vars@e.es_infer_vars_rel,e.es_infer_heap,e.es_infer_pure,e.es_infer_rel,e.es_var_zero_perm)]
    | OCtx (x1,x2) -> (f x1) @ (f x2) in
  let pr (f,(* ac, *)iv,ih,ip,ir,vperms) =
    fmt_open_vbox 0;
    pr_formula_wrap f;
    pr_wrap_test "es_var_zero_perm: " Gen.is_empty  (pr_seq "" pr_spec_var) vperms;
    pr_wrap_test "es_infer_vars/rel: " Gen.is_empty  (pr_seq "" pr_spec_var) iv;
    (*pr_wrap (fun _ -> fmt_string "es_aux_conseq: "; pr_pure_formula ac) ();*)
    pr_wrap_test "es_infer_heap: " Gen.is_empty  (pr_seq "" pr_h_formula) ih; 
    pr_wrap_test "es_infer_pure: " Gen.is_empty  (pr_seq "" pr_pure_formula) ip;
    pr_wrap_test "es_infer_rel: " Gen.is_empty  (pr_seq "" pr_lhs_rhs) ir;
    fmt_close_box();
  in 
  let lls = List.map f ctx in
  let pr_disj ls = 
    if (List.length ls == 1) then pr (List.hd ls)
    else pr_seq "or" pr ls 
  in
   pr_seq_vbox "" (wrap_box ("H",1) pr_disj) lls
    
let pr_list_context_short (ctx:list_context) =
  match ctx with
    | FailCtx ft -> (fmt_string "failctx"; pr_fail_type ft)
    | SuccCtx sc -> (fmt_int (List.length sc); pr_context_list_short sc)
    
let pr_entail_state_short e =
  fmt_open_vbox 1;
  pr_formula_wrap e.es_formula;
  pr_wrap_test "es_heap:" (fun _ -> false)  (pr_h_formula) e.es_heap;
  pr_wrap_test "@zero:" Gen.is_empty  (pr_seq "" pr_spec_var) e.es_var_zero_perm;
  pr_wrap_test "es_infer_vars: " Gen.is_empty  (pr_seq "" pr_spec_var) e.es_infer_vars;
  pr_wrap_test "es_infer_vars_rel: " Gen.is_empty  (pr_seq "" pr_spec_var) e.es_infer_vars_rel;
  (* pr_wrap_test "es_ante_vars: " Gen.is_empty (pr_seq "" pr_spec_var) e.es_ante_evars;*)
  (* pr_vwrap "es_pure: " pr_mix_formula_branches e.es_pure; *)
  (* pr_vwrap "es_infer_label:  " pr_formula es.es_infer_label;*)
  pr_wrap_test "es_infer_heap: " Gen.is_empty  (pr_seq "" pr_h_formula) e.es_infer_heap; 
  pr_wrap_test "es_infer_pure: " Gen.is_empty  (pr_seq "" pr_pure_formula) e.es_infer_pure;
  pr_wrap_test "es_infer_rel: " Gen.is_empty  (pr_seq "" pr_lhs_rhs) e.es_infer_rel; 
  (* pr_wrap_test "es_subst_ref: " Gen.is_empty  (pr_seq "a" (pr_pair_aux pr_spec_var pr_spec_var)) e.es_subst_ref;  *)
  pr_wrap_test "es_cond_path: " Gen.is_empty (pr_seq "" (fun s -> fmt_int s)) e.es_cond_path;
  pr_wrap_opt "es_var_measures 3: " pr_var_measures e.es_var_measures;
  (* fmt_cut(); *)
  fmt_close_box()

let pr_list_context (ctx:list_context) =
  match ctx with
    | FailCtx ft -> fmt_cut ();fmt_string "MaybeErr Context: "; 
        (* (match ft with *)
        (*     | Basic_Reason (_, fe) -> (string_of_fail_explaining fe) (\*useful: MUST - OK*\) *)
        (*     (\* TODO : to output must errors first *\) *)
        (*     (\* | And_Reason (_, _, fe) -> (string_of_fail_explaining fe) *\) *)
        (*     | _ -> fmt_string ""); *)
        pr_fail_type ft; fmt_cut ()
    | SuccCtx sc -> let str = 
        if (get_must_error_from_ctx sc)==None then "Good Context: "
        else "Error Context: " in
      fmt_cut (); fmt_string str; fmt_string "length= ";fmt_int (List.length sc);fmt_string " "; pr_context_list sc;
      fmt_string (string_of_numbered_list_formula_trace (CF.list_formula_trace_of_list_context ctx));
      fmt_cut ()

let string_of_context_short (ctx:context): string =  poly_string_of_pr pr_context_short ctx

let string_of_list_context_short (ctx:list_context): string =  poly_string_of_pr pr_list_context_short ctx

let string_of_context_list_short (ctx:context list): string 
      =  poly_string_of_pr pr_context_list_short ctx

let string_of_list_context (ctx:list_context): string 
      (* =  poly_string_of_pr pr_list_context_short ctx *)
      =  poly_string_of_pr pr_list_context ctx

let string_of_list_context_list (ctxl:list_context list): string 
      =  List.fold_right (fun lctx str -> (string_of_list_context lctx) ^ str ^"\n") ctxl ""

let string_of_entail_state_short (e:entail_state):string = poly_string_of_pr pr_entail_state_short e

let printer_of_list_context (fmt: Format.formatter) (ctx: list_context) : unit =
  poly_printer_of_pr fmt pr_list_context ctx 

let pr_esc_stack_lvl ((i,s),e) = 
  if (e==[]) 
  then
    begin
      (* fmt_open_hbox (); *)
      (* fmt_string ("Try-Block:"^(string_of_int i)^":"^s^":"); *)
      (* fmt_close_box() *)
      ()
    end
  else
    begin
      fmt_open_vbox 0;
      pr_vwrap_naive ("Try-Block:"^(string_of_int i)^":"^s^":")
          (pr_seq_vbox "" (fun (lbl,fs)-> pr_vwrap_nocut "Path: " pr_path_trace lbl;
		      pr_vwrap "State:" pr_context_short fs)) e;
      fmt_close_box ()
    end

let string_of_esc_stack_lvl e  = poly_string_of_pr pr_esc_stack_lvl e

(* should this include must failures? *)
let pr_failed_states e = match e with
  | [] -> ()
  | _ ->   pr_vwrap_naive_nocut "Failed States:"
      (pr_seq_vbox "" (fun (lbl,fs)-> pr_vwrap_nocut "Label: " pr_path_trace lbl;
		  pr_vwrap "State:" pr_fail_type fs)) e

let pr_successful_states e = match e with
  | [] -> ()
  | _ ->   
  pr_vwrap_naive "Successful States:"
      (pr_seq_vbox "" (fun (lbl,fs)-> pr_vwrap_nocut "Label: " pr_path_trace lbl;
		  pr_vwrap "State:" pr_context_short fs)) e

let is_empty_esc_state e =
  List.for_all (fun (_,lst) -> lst==[]) e

let pr_esc_stack e = 
  if is_empty_esc_state e then ()
  else
    begin
    fmt_open_vbox 0;
    pr_vwrap_naive_nocut "Escaped States:"
    (pr_seq_vbox "" pr_esc_stack_lvl) e;
    fmt_close_box ()
    end

let string_of_esc_stack e = poly_string_of_pr pr_esc_stack e

let pr_failesc_context ((l1,l2,l3): failesc_context) =
  fmt_open_vbox 0;
  pr_failed_states l1;
  pr_esc_stack l2;
  pr_successful_states l3;
  fmt_close_box ()

let pr_failesc_context_short ((l1,l2,l3): failesc_context) =
  fmt_open_vbox 0;
  pr_successful_states l3;
  fmt_close_box ()

let pr_partial_context ((l1,l2): partial_context) =
  fmt_open_vbox 0;
  pr_vwrap_naive_nocut "Failed States:"
      (pr_seq_vbox "" (fun (lbl,fs)-> pr_vwrap_nocut "Label: " pr_path_trace lbl;
    	  pr_vwrap "State:" pr_fail_type fs)) l1;
  pr_vwrap_naive "Successful States:"
      (pr_seq_vbox "" (fun (lbl,fs)-> pr_vwrap_nocut "Label: " pr_path_trace lbl;
    	  pr_vwrap "State:" pr_context fs)) l2;
  fmt_close_box ()

let pr_partial_context_short ((l1,l2): partial_context) =
  fmt_open_vbox 0;
  pr_vwrap_naive "Successful States:"
      (pr_seq_vbox "" (fun (lbl,fs)-> pr_vwrap_nocut "Label: " pr_path_trace lbl;
    	  pr_vwrap "State:" pr_context_short fs)) l2;
  fmt_close_box ()

(* let pr_partial_context ((l1,l2): partial_context) = *)
(*   fmt_open_vbox 0; *)
(*   fmt_string "Failed States: "; *)
(*   pr_seq "" (fun (lbl,fs)-> fmt_cut (); fmt_string " Lbl : "; pr_path_trace lbl; fmt_cut (); *)
(* 	       fmt_string " State: "; pr_fail_type fs) l1; *)
(*   fmt_cut (); *)
(*   fmt_string "Succesful States: "; *)
(*    pr_seq "" (fun (lbl,fs)-> fmt_cut (); fmt_string " Lbl : "; pr_path_trace lbl; fmt_cut (); *)
(* 	       fmt_string " State: "; pr_context fs) l2; *)
(*   fmt_close_box () *)


let string_of_partial_context (ctx:partial_context): string =  poly_string_of_pr pr_partial_context ctx

let string_of_partial_context_short (ctx:partial_context): string =  poly_string_of_pr pr_partial_context_short ctx

let printer_of_partial_context (fmt: Format.formatter) (ctx: partial_context) : unit =  poly_printer_of_pr fmt pr_partial_context ctx 

let string_of_failesc_context (ctx:failesc_context): string =  poly_string_of_pr pr_failesc_context ctx

let printer_of_failesc_context (fmt: Format.formatter) (ctx: failesc_context) : unit =
  poly_printer_of_pr fmt pr_failesc_context ctx 

let pr_list_failesc_context (lc : list_failesc_context) =
   fmt_string ("List of Failesc Context: "^(summary_list_failesc_context lc));
   fmt_cut (); pr_list_none pr_failesc_context lc

let pr_list_failesc_context_short (lc : list_failesc_context) =
   (* fmt_string ("List of Failesc Context: "^(summary_list_failesc_context lc)); *)
   fmt_cut (); pr_list_none pr_failesc_context_short lc

let pr_list_partial_context (lc : list_partial_context) =
    (* fmt_string ("XXXX "^(string_of_int (List.length lc)));  *)
   fmt_string ("List of Partial Context: " ^(summary_list_partial_context lc) );
   fmt_cut (); pr_list_none pr_partial_context lc

let pr_list_partial_context_short (lc : list_partial_context) =
    (* fmt_string ("XXXX "^(string_of_int (List.length lc)));  *)
   (* fmt_string ("List of Partial Context: " ^(summary_list_partial_context lc) ); *)
   fmt_cut (); pr_list_none pr_partial_context_short lc

(* let pr_list_partial_context_short (lc : list_partial_context) = *)
(*     (\* fmt_string ("XXXX "^(string_of_int (List.length lc)));  *\) *)
(*    (\* fmt_string ("List of Partial Context: " ^(summary_list_partial_context lc) ); *\) *)
(*    fmt_cut (); pr_list_none pr_partial_context_short lc *)

let string_of_list_partial_context (lc: list_partial_context) =  poly_string_of_pr pr_list_partial_context lc

let string_of_list_partial_context_short (lc: list_partial_context) =  poly_string_of_pr pr_list_partial_context_short lc

let string_of_list_failesc_context (lc: list_failesc_context) =  poly_string_of_pr pr_list_failesc_context lc

let string_of_list_failesc_context_short (lc: list_failesc_context) =  poly_string_of_pr pr_list_failesc_context_short lc

let printer_of_list_partial_context (fmt: Format.formatter) (ctx: list_partial_context) : unit =
  poly_printer_of_pr fmt pr_list_partial_context ctx 


let pr_list_list_partial_context (lc:list_partial_context list) =
  fmt_string ("List List of Partial Context: " ^ string_of_int(List.length lc));
  pr_list_none pr_list_partial_context lc

let string_of_list_list_partial_context (lc:list_partial_context list) =
  poly_string_of_pr pr_list_list_partial_context lc

let printer_of_list_list_partial_context (fmt: Format.formatter) (ctx: list_partial_context list) : unit =
  poly_printer_of_pr fmt pr_list_list_partial_context ctx

let pr_mater_prop (x:mater_property) : unit = 
    fmt_string "(";
    pr_spec_var x.mater_var;
    fmt_string ",";
    (match x.mater_full_flag with
      | true -> fmt_string "full"
      | false -> fmt_string "partial");
    fmt_string ",";
    pr_seq "" fmt_string x.mater_target_view;
    fmt_string ")"
      
let string_of_mater_property p : string = poly_string_of_pr pr_mater_prop p
      
let pr_mater_prop_list (l: mater_property list) : unit =  pr_seq "" pr_mater_prop l

let string_of_mater_prop_list l : string = poly_string_of_pr pr_mater_prop_list l

let pr_prune_invariants l = (fun c-> pr_seq "," (fun (c1,(ba,c2))-> 
      let s = String.concat "," (List.map (fun d-> string_of_int_label d "") c1) in
      let b = string_of_spec_var_list ba in
      let d = String.concat ";" (List.map string_of_b_formula c2) in
      fmt_string ("{"^s^"} -> {"^b^"} ["^d^"]")) c) l

let string_of_prune_invariants p : string = poly_string_of_pr pr_prune_invariants p

let string_of_prune_conditions p : string = pr_list (pr_pair string_of_b_formula (pr_list Globals.string_of_formula_label)) p

let pr_view_base_case bc = 
    (match bc with
	  | None -> ()
      | Some (s1,s2) -> pr_vwrap "base case: " (fun () -> pr_pure_formula s1;fmt_string "->"; pr_mix_formula s2) () )

let pr_barrier_decl v = 
	fmt_open_vbox 1;
    wrap_box ("B",0) (fun ()-> fmt_string ("barrier "^v.barrier_name ^"["^(string_of_int v.barrier_thc)^"]<"^
	(String.concat "," (List.map string_of_spec_var v.barrier_shared_vars))^"> = ")) ();
	fmt_cut (); wrap_box ("B",0) pr_struc_formula v.barrier_def; 
	pr_vwrap  "transitions:" 
	(pr_seq "\n" (fun (f,t,sp)-> pr_int f; fmt_string "->";pr_int t; fmt_string " :"; pr_seq "\n" pr_struc_formula sp)) v.barrier_tr_list;
	
	pr_vwrap  "prune branches: " (fun c-> pr_seq "," pr_formula_label_br c) v.barrier_prune_branches;
	pr_vwrap  "prune conditions: " pr_case_guard v.barrier_prune_conditions;
	pr_vwrap  "prune perm conditions: " (fun c-> fmt_string "{"; pr_seq "\n" (fun (c1,c2)-> fmt_string (Tree_shares.Ts.string_of c1) ;fmt_string "->"; pr_seq_nocut "," pr_formula_label c2) c; fmt_string "}") v.barrier_prune_conditions_perm;
	pr_vwrap  "prune state conditions: " (fun c-> fmt_string "{"; pr_seq "\n" (fun (c1,c2)-> fmt_string (string_of_int c1) ;fmt_string "->"; pr_seq_nocut "," pr_formula_label c2) c; fmt_string "}") v.barrier_prune_conditions_state;
	pr_vwrap  "prune baga conditions: " (fun c-> fmt_string (String.concat "," (List.map (fun (bl,(lbl,_))-> "("^(string_of_spec_var_list bl)^")-"^(string_of_int lbl)) c))) v.barrier_prune_conditions_baga;
	pr_vwrap  ("prune invs:"^( string_of_int(List.length v.barrier_prune_invariants) )^":") pr_prune_invariants v.barrier_prune_invariants;
	fmt_close_box ()
	  
(* pretty printing for a view *)
let pr_view_decl v =
  pr_mem:=false;
  let f bc =
    match bc with
	  | None -> ()
      | Some (s1,s2) -> pr_vwrap "base case: " (fun () -> pr_pure_formula s1;fmt_string "->"; pr_mix_formula s2) ()
  in
  fmt_open_vbox 1;
  let s = match v.view_kind with 
    | View_NORM -> " "
    | View_PRIM -> "_prim "
    | View_EXTN -> "_extn "
    | View_SPEC -> "_spec "
    | View_DERV -> "_derv "
  in
  wrap_box ("B",0) (fun ()-> pr_angle  ("view"^s^v.view_name ^ "[" ^ (String.concat "," (List.map string_of_typed_spec_var v.view_prop_extns) ^ "]")) 
      pr_typed_spec_var v.view_vars; fmt_string "= ") ();
   pr_vwrap  "view_domains: "  fmt_string (String.concat ";" (List.map (fun (v,p1,p2) ->
     "(" ^ v ^ "," ^ (string_of_int p1) ^ "," ^ (string_of_int p2) ^ ")" ) v.view_domains));
  (* wrap_box ("B",0) (fun ()-> pr_angle  ("view"^s^v.view_name) pr_typed_spec_var_lbl  *)
  (*     (List.combine v.view_labels v.view_vars); fmt_string "= ") (); *)
  wrap_box ("B",0) (fun ()-> pr_angle  ("view"^s^v.view_name) pr_typed_view_arg_lbl 
      (CP.combine_labels_w_view_arg v.view_labels  (List.map fst v.view_params_orig)); fmt_string "= ") ();
  fmt_cut (); wrap_box ("B",0) pr_struc_formula v.view_formula; 
  pr_vwrap  "view vars: "  pr_list_of_spec_var v.view_vars;
  (* pr_vwrap  "ann vars: "  pr_list_of_annot_arg (List.map fst v.view_ann_params); *)
  pr_vwrap  "ann vars (0 - not a posn): "  pr_list_of_annot_arg_posn v.view_ann_params;
  pr_vwrap  "cont vars: "  pr_list_of_spec_var v.view_cont_vars;
  pr_vwrap  "inv: "  pr_mix_formula v.view_user_inv;
  pr_vwrap  "inv_lock: "  (pr_opt pr_formula) v.view_inv_lock;
  pr_vwrap  "unstructured formula: "  (pr_list_op_none "|| " (wrap_box ("B",0) (fun (c,_)-> pr_formula c))) v.view_un_struc_formula;
  pr_vwrap  "xform: " pr_mix_formula v.view_x_formula;
  pr_vwrap  "is_recursive?: " fmt_string (string_of_bool v.view_is_rec);
  pr_vwrap  "is_primitive?: " fmt_string (string_of_bool v.view_is_prim);
  pr_vwrap  "same_xpure?: " fmt_string 
      (if v.view_xpure_flag then "YES" else "NO");
  pr_vwrap  "view_data_name: " fmt_string v.view_data_name;
  pr_vwrap  "self preds: " fmt_string (Gen.Basic.pr_list (fun x -> x) v.view_pt_by_self);
  pr_vwrap  "materialized vars: " pr_mater_prop_list v.view_materialized_vars;
  pr_vwrap  "addr vars: " pr_list_of_spec_var v.view_addr_vars;
  pr_vwrap  "uni_vars: " fmt_string (string_of_spec_var_list v.view_uni_vars);
  pr_vwrap  "bag of addr: " pr_list_of_spec_var v.view_baga;
  (match v.view_raw_base_case with 
    | None -> ()
    | Some s -> pr_vwrap  "raw base case: " pr_formula s);  
  f v.view_base_case;
  pr_vwrap  "view_complex_inv: " (pr_opt pr_mix_formula) v.view_complex_inv;
  pr_vwrap  "prune branches: " (fun c-> pr_seq "," pr_formula_label_br c) v.view_prune_branches;
  pr_vwrap  "prune conditions: " pr_case_guard v.view_prune_conditions;
  pr_vwrap  "prune baga conditions: " 
    (fun c-> fmt_string 
        (String.concat "," (List.map (fun (bl,(lbl,_))-> "("^(string_of_spec_var_list bl)^")-"^(string_of_int lbl)) c))) v.view_prune_conditions_baga;
  let i = string_of_int(List.length v.view_prune_invariants) in
  pr_vwrap  ("prune invs:"^i^":") (* (fun c-> pr_seq "," (fun (c1,(ba,c2))->  *)
      (* let s = String.concat "," (List.map (fun d-> string_of_int_label d "") c1) in *)
      (* let b = string_of_spec_var_list ba in *)
      (* let d = String.concat ";" (List.map string_of_b_formula c2) in *)
      (* fmt_string ("{"^s^"} -> {"^b^"} ["^d^"]")) c) *) pr_prune_invariants v.view_prune_invariants;
  fmt_close_box ();
  pr_mem:=true


let pr_view_decl_short v =
  pr_mem:=false;
  (* let f bc = *)
  (*   match bc with *)
  (*         | None -> () *)
  (*     | Some (s1,s2) -> pr_vwrap "base case: " (fun () -> pr_pure_formula s1;fmt_string "->"; pr_mix_formula s2) () *)
  (* in *)
  fmt_open_vbox 1;
  (* wrap_box ("B",0) (fun ()-> pr_angle  ("view"^v.view_name) pr_typed_spec_var_lbl  *)
  (*     (List.combine v.view_labels v.view_vars); fmt_string "= ") (); *)
  wrap_box ("B",0) (fun ()-> pr_angle  ("view"^v.view_name) pr_typed_view_arg_lbl 
      (List.combine v.view_labels (List.map fst v.view_params_orig)); fmt_string "= ") ();
  fmt_cut (); wrap_box ("B",0) pr_struc_formula v.view_formula; 
  pr_vwrap  "cont vars: "  pr_list_of_spec_var v.view_cont_vars;
  pr_vwrap  "inv: "  pr_mix_formula v.view_user_inv;
  pr_vwrap  "unstructured formula: "  (pr_list_op_none "|| " (wrap_box ("B",0) (fun (c,_)-> pr_formula c))) v.view_un_struc_formula;
  pr_vwrap  "xform: " pr_mix_formula v.view_x_formula;
  pr_vwrap  "is_recursive?: " fmt_string (string_of_bool v.view_is_rec);
  pr_vwrap  "view_data_name: " fmt_string v.view_data_name;
  fmt_close_box ();
  pr_mem:=true

let pr_prune_invs inv_lst = 
  "prune invs: " ^ (String.concat "," (List.map 
      (fun c-> (fun (c1,c2)-> 
          let s = String.concat "," (List.map (fun d-> string_of_int_label d "") c1) in
          let d = String.concat ";" (List.map string_of_b_formula c2) in
          ("{"^s^"} -> ["^d^"]")) c) inv_lst))

let string_of_prune_invs inv_lst : string = pr_prune_invs inv_lst

let string_of_view_base_case (bc:(P.formula *MP.mix_formula) option): string =  poly_string_of_pr pr_view_base_case bc

let string_of_view_decl (v: Cast.view_decl): string =  poly_string_of_pr pr_view_decl v

let string_of_view_decl_short (v: Cast.view_decl): string =  poly_string_of_pr pr_view_decl_short v

let string_of_barrier_decl (v: Cast.barrier_decl): string = poly_string_of_pr pr_barrier_decl v

let printer_of_view_decl (fmt: Format.formatter) (v: Cast.view_decl) : unit =
  poly_printer_of_pr fmt pr_view_decl v 


(* function to print a list of strings *) 
let rec string_of_ident_list l c = match l with 
  | [] -> ""
  | h::[] -> h 
  | h::t -> h ^ c ^ (string_of_ident_list t c)
;;

let str_ident_list l = string_of_ident_list l "," ;;
let str_ident_list l = "["^(string_of_ident_list l ",")^"]" ;;

let string_of_constraint_relation m = match m with
  | Cpure.Unknown -> " ?  "
  | Cpure.Subsumed -> " <  "
  | Cpure.Subsuming -> " >  "
  | Cpure.Equal -> " =  "
  | Cpure.Contradicting -> "!= "

(* pretty printing for a list of pure formulae *)
let rec string_of_formula_exp_list l = match l with 
  | [] -> ""
  | h::[] -> string_of_formula_exp h
  | h::t -> (string_of_formula_exp h) ^ ", " ^ (string_of_formula_exp_list t)
;;
 

(* pretty printing for a cformula *)
(*NOT DONE*)

let string_of_flow_store l = (String.concat " " (List.map (fun h-> (h.formula_store_name^"= "^
	(let rr = h.formula_store_value.formula_flow_interval in
	(string_of_flow rr))^" ")) l))


let rec string_of_t_formula = function
(* commented on 09.06.08
 | TypeExact ({t_formula_sub_type_var = v;
				t_formula_sub_type_type = c}) -> 
	  (string_of_spec_var v) ^ " = " ^ c
  | TypeSub ({t_formula_sub_type_var = v;
			  t_formula_sub_type_type = c}) -> 
	  (string_of_spec_var v) ^ " <: " ^ c
  | TypeSuper ({t_formula_sub_type_var = v;
				t_formula_sub_type_type = c}) -> 
	  (string_of_spec_var v) ^ " > " ^ c*)
  | TypeAnd ({t_formula_and_f1 = f1;
			  t_formula_and_f2 = f2}) -> 
	  (string_of_t_formula f1) ^ " & " ^ (string_of_t_formula f2)
  | TypeTrue -> "TypeTrue"
  | TypeFalse -> "TypeFalse"
  | TypeEmpty -> "TypeEmpty"

(* function to print a list of type F.formula * F.formula *)
let rec string_of_formulae_list l = match l with 
  | [] -> ""
  | (f1, f2)::[] -> "\nrequires " ^ (string_of_formula f1) ^ "\nensures " ^ (string_of_formula f2)  
  | (f1, f2)::t -> "\nrequires " ^ (string_of_formula f1) ^ "\nensures " ^ (string_of_formula f2) ^ (string_of_formulae_list t)
;;




(*
let rec string_of_spec = function
	| SCase {scase_branches= br;} ->
		 (List.fold_left (fun a (c1,c2)->a^"\n"^(string_of_pure_formula c1)^"-> "^
		( List.fold_left  (fun a c -> a ^"\n "^(string_of_spec c )) "" c2)) "case { " br)^"}\n"
	| SRequires 	{
			srequires_implicit_inst = ii;
			srequires_explicit_inst = ei;
			srequires_base = fb;
			srequires_continuation = cont;
			}	 ->
				let l2 = List.fold_left (fun a c -> a^ " " ^(string_of_spec_var c)) "" ei in
				let l1 = List.fold_left (fun a c -> a^ " " ^(string_of_spec_var c)) "" ii in
				let b = string_of_formula fb in				
				"requires ["^l1^"]["^l2^"]"^b^" "^((List.fold_left (fun a d -> a^"\n"^(string_of_spec d)) "{" cont)^"}")
	| SEnsure{ sensures_base = fb } -> ("ensures "^(string_of_formula fb))
;;


let string_of_specs d =  List.fold_left  (fun a c -> a ^" "^(string_of_spec c )) "" d 
;;*)


(* functions to decide if an expression needs parenthesis *)
(* let need_parenthesis e = match e with  *)
(*   | BConst _ | Bind _ | FConst _ | IConst _ | Unit _ | Var _ -> false  *)
(*   | _ -> true *)
(* ;; *)

let string_of_sharp st = match st with
	| Sharp_ct t -> string_of_flow_formula "" t
	| Sharp_id  f -> "flow_var "^f

let string_of_read_only ro = match ro with
  | true -> "read"
  | false -> "write" (*write is conservative*)

(* pretty printing for expressions *)
let rec string_of_exp = function 
  | Label l-> "LABEL! "^( (string_of_int_label_opt (fst  l.exp_label_path_id) (","^((string_of_int (snd l.exp_label_path_id))^": "^(string_of_exp l.exp_label_exp)))))
  | Java ({exp_java_code = code}) -> code
  | CheckRef _ -> ""
  | Assert ({exp_assert_asserted_formula = f1o; exp_assert_assumed_formula = f2o; exp_assert_pos = l; exp_assert_type = t; exp_assert_path_id = pid}) -> 
      let s = ( 
        let str1 = match (f1o, t) with
          | None, _ -> ""
          | Some f1, None -> "assert " ^(string_of_control_path_id pid (":"^(string_of_struc_formula f1)))
          | Some f1, Some true -> "assert_exact " ^(string_of_control_path_id pid (":"^(string_of_struc_formula f1)))
          | Some f1, Some false -> "assert_inexact " ^(string_of_control_path_id pid (":"^(string_of_struc_formula f1))) in
        let str2 = match f2o with
          | None -> ""
          | Some f2 -> "assume " ^ (string_of_formula f2) in
        str1 ^ " " ^ str2
      ) in
      string_of_formula_label pid s 
(*| ArrayAt ({exp_arrayat_type = _; exp_arrayat_array_base = a; exp_arrayat_index = i; exp_arrayat_pos = l}) -> 
    a ^ "[" ^ (string_of_exp i) ^ "]" (* An Hoa *) *)
(*| ArrayMod ({exp_arraymod_lhs = a; exp_arraymod_rhs = r; exp_arraymod_pos = l}) -> 
    (string_of_exp (ArrayAt a)) ^ " = " ^ (string_of_exp r) (* An Hoa *)*)
  | Assign ({exp_assign_lhs = id; exp_assign_rhs = e; exp_assign_pos = l}) -> 
        id ^ " = " ^ (string_of_exp e)
  | BConst ({exp_bconst_val = b; exp_bconst_pos = l}) -> 
        string_of_bool b 
  | Bind ({exp_bind_type = _; 
	exp_bind_bound_var = (_, id); 
	exp_bind_fields = idl;
    exp_bind_read_only = ro;
	exp_bind_body = e;
	exp_bind_path_id = pid;
	exp_bind_pos = l}) -> 
        string_of_control_path_id pid ("bind " ^ id ^ " to (" ^ (string_of_ident_list (snd (List.split idl)) ",") ^ ") [" ^ (string_of_read_only ro)^ "] in \n" ^ (string_of_exp e))
  | Block ({exp_block_type = _;
	exp_block_body = e;
	exp_block_local_vars = _;
	exp_block_pos = _}) -> "{" ^ (string_of_exp e) ^ "}"
  | Barrier b -> "barrier "^(string_of_ident (snd b.exp_barrier_recv))
  | ICall ({exp_icall_type = _;
	exp_icall_receiver = r;
	exp_icall_method_name = id;
	exp_icall_arguments = idl;
	exp_icall_path_id = pid;
	exp_icall_pos = l;
	exp_icall_is_rec = is_rec}) -> 
        string_of_control_path_id_opt pid (r ^ "." ^ id ^ "(" ^ (string_of_ident_list idl ",") ^ ")" ^ (if (is_rec) then " rec" else ""))
  | Cast ({exp_cast_target_type = t;
	exp_cast_body = body}) -> begin
      "(" ^ (string_of_typ t) ^ " )" ^ string_of_exp body
    end
  | Catch b->   
        let c = b.exp_catch_flow_type in
	    "\n catch "^(string_of_flow c)^"="^(exlist # get_closest c)^ 
	        (match b.exp_catch_flow_var with 
	          | Some c -> (" @"^c^" ")
	          | _ -> " ")^
	        (match b.exp_catch_var with 
	          | Some (a,b) -> ((string_of_typ a)^":"^b^" ")
	          | _ -> " ")^") \n\t"^(string_of_exp b.exp_catch_body)
  | Cond ({exp_cond_type = _;
	exp_cond_condition = id;
	exp_cond_then_arm = e1;
	exp_cond_else_arm = e2;
	exp_cond_path_id = pid;
	exp_cond_pos = l}) -> 
        string_of_control_path_id pid ("if (" ^ id ^ ") [" ^(string_of_exp e1) ^ "]\nelse [" ^ (string_of_exp e2) ^ "]\n" )
  | Debug ({exp_debug_flag = b; exp_debug_pos = l}) -> if b then "debug" else ""
  | Dprint _ -> "dprint"
  | FConst ({exp_fconst_val = f; exp_fconst_pos = l}) -> string_of_float f 
        (*| FieldRead (_, (v, _), (f, _), _) -> v ^ "." ^ f*)
        (*| FieldWrite ((v, _), (f, _), r, _) -> v ^ "." ^ f ^ " = " ^ r*)
  | IConst ({exp_iconst_val = i; exp_iconst_pos = l}) -> string_of_int i 
  | New ({exp_new_class_name = id;
	exp_new_arguments = idl;
	exp_new_pos = l}) -> 
        "new " ^ id ^ "(" ^ (string_of_ident_list (snd (List.split idl)) ",") ^ ")"
  | Null l -> "null"
  | EmptyArray b -> "Empty Array" (* An Hoa *)
  | Print (i, l)-> "print " ^ (string_of_int i) 
  | Sharp ({exp_sharp_flow_type = st;
	exp_sharp_val = eo;
	exp_sharp_path_id =pid;
	exp_sharp_pos = l}) ->begin
      string_of_control_path_id_opt pid (
	      match st with
	        | Sharp_ct f ->  
                  if (Cformula.equal_flow_interval f.formula_flow_interval !ret_flow_int) 
                  then
	                (match eo with 
		              |Sharp_var e -> "ret# " ^ (snd e)
		              | _ -> "ret#")
	              else  (match eo with 
		            | Sharp_var e -> "throw " ^ (snd e)^":"^(string_of_sharp st)
		            | Sharp_flow e -> "throw " ^ e ^":"^(string_of_sharp st)
		            | _ -> "throw "^(string_of_sharp st))
	        | _ -> (match eo with 
		        | Sharp_var e -> "throw " ^ (snd e)
		        | Sharp_flow e -> "throw " ^ e ^":" ^(string_of_sharp st)
		        | _ -> "throw "^(string_of_sharp st)))end 
  | SCall ({exp_scall_type = _;
	exp_scall_method_name = id;
	exp_scall_lock = lock;
	exp_scall_arguments = idl;
	exp_scall_path_id = pid;
	exp_scall_pos = l;
	exp_scall_is_rec = is_rec}) ->
      let lock_info = match lock with |None -> "" | Some id -> ("[" ^ id ^ "]") in
        string_of_control_path_id_opt pid (id ^ lock_info ^ "(" ^ (string_of_ident_list idl ",") ^ ")" ^ (if (is_rec) then " rec" else ""))
  | Seq ({exp_seq_type = _;
	exp_seq_exp1 = e1;
	exp_seq_exp2 = e2;
	exp_seq_pos = l}) -> 
        "("^(string_of_exp e1) ^ ";\n" ^ (string_of_exp e2)^")"
  | This _ -> "this"
  | Time (b,s,_) -> ("Time "^(string_of_bool b)^" "^s)
  | Var ({exp_var_type = _;
	exp_var_name = id;
	exp_var_pos = l}) -> id 
  | VarDecl ({exp_var_decl_type = t;
	exp_var_decl_name = id;
	exp_var_decl_pos = _}) -> 
        (string_of_typ t) ^" "^ id (*^ (string_of_exp e1) ^ ";\n" ^ (string_of_exp e2)*)
  | Unit l -> ""
  | While ({exp_while_condition = id;
	exp_while_body = e;
	exp_while_spec = fl;
	exp_while_path_id = pid;
	exp_while_pos = l}) -> 
        string_of_control_path_id_opt pid ("while " ^ id ^ (string_of_struc_formula fl) ^ "\n{\n" ^ (string_of_exp e) ^ "\n}\n")
  | Unfold ({exp_unfold_var = sv}) -> "unfold " ^ (string_of_spec_var sv)
  | Try b -> string_of_control_path_id b.exp_try_path_id  "try \n"^(string_of_exp b.exp_try_body)^(string_of_exp b.exp_catch_clause )
;;

let string_of_field_ann ann=
  if not !print_ann then ""
  else (* match ann with *)
    (* | VAL -> "@VAL" *)
    (* | REC -> "@REC" *)
    (* | F_NO_ANN -> "" *)
    String.concat "@" ann

(* pretty printing for one data declaration*)
let string_of_decl (t,id) = (* An Hoa : un-hard-code *)
  (string_of_typ t) ^ " " ^ (id)
;;

(* pretty printing for one data declaration*)
let string_of_data_decl ((t,id),ann) = (* An Hoa : un-hard-code *)
  (string_of_typ t) ^ " " ^ (id) ^ (string_of_field_ann ann)
;;

(* function to print a list of typed_ident *) 
let rec string_of_decl_list l c = match l with 
  | [] -> ""
  | h::[] -> "  " ^ string_of_decl h 
  | h::t -> "  " ^ (string_of_decl h) ^ c ^ (string_of_decl_list t c)
;;

(* function to print a list of typed_ident *) 
let rec string_of_data_decl_list l c = match l with 
  | [] -> ""
  | h::[] -> "  " ^ (string_of_data_decl h )
  | h::t -> "  " ^ (string_of_data_decl h)  ^ c ^ (string_of_data_decl_list t c)
;;

(* function to print a list of typed_ident *) 
(* let rec string_of_decl_list l c = match l with  *)
(*   | [] -> "" *)
(*   | h::[] -> "  " ^ string_of_decl h  *)
(*   | h::t -> "  " ^ (string_of_decl h) ^ c ^ (string_of_decl_list t c) *)
(* ;; *)

(* pretty printing for a data declaration *)
let string_of_data_decl d = "data " ^ d.data_name ^ " {\n" ^ (string_of_data_decl_list d.data_fields ";\n") ^ ";\n}"
;;

let string_of_coercion_type (t:Cast.coercion_type) = match t with
  | Iast.Left -> "==>"
  | Iast.Right -> "<=="
  | Iast.Equiv -> "<==>" ;;

let string_of_coercion_case (t:Cast.coercion_case) = match t with
  | Cast.Simple -> "Simple"
  | Cast.Complex -> "Complex"
  | Cast.Ramify -> "Ramify"
  | Cast.Normalize b-> "Normalize "^(string_of_bool b)

    (* coercion_univ_vars : P.spec_var list; (\* list of universally quantified variables. *\) *)
let string_of_coerc_opt op c = 
  let s1="Lemma \""^c.coercion_name^"\": "^(string_of_formula c.coercion_head)^(string_of_coercion_type c.coercion_type) in
  if is_short op then s1
  else let s2 = s1^(string_of_formula c.coercion_body) in
  if is_medium op then s2
  else s2
    ^"\n head match:"^c.coercion_head_view
    ^"\n body view:"^c.coercion_body_view
    ^"\n coercion_univ_vars: "^(string_of_spec_var_list c.coercion_univ_vars)
    ^"\n materialized vars: "^(string_of_mater_prop_list c.coercion_mater_vars)
    ^"\n coercion_case: "^(string_of_coercion_case c.Cast.coercion_case)
    ^"\n head_norm: "^(string_of_formula c.coercion_head_norm)
    ^"\n body_norm: "^(string_of_struc_formula c.coercion_body_norm)
    ^"\n coercion_univ_vars: "^(string_of_spec_var_list c.coercion_univ_vars)
    ^"\n coercion_case: "^(string_of_coercion_case c.Cast.coercion_case)
    ^"\n";;
  
let string_of_coerc_short c = string_of_coerc_opt 2 c;;

let string_of_coerc_med c = string_of_coerc_opt 1 c;;

let string_of_coerc_long c = string_of_coerc_opt 0 c;;

(* let string_of_coerc c = (string_of_coerc_short c) *)
(*   ^ (string_of_formula c.coercion_body) *)
(*   ;; *)

(* let string_of_coerc_long c = (string_of_coerc c) *)
(*  (\* ^"\n lhs exists:"^(string_of_formula c.coercion_head_exist) *\) *)
(*   ^"\n head match:"^c.coercion_head_view *)
(*   ^"\n body cycle:"^c.coercion_body_view *)
(*   ^"\n materialized vars: "^(string_of_mater_prop_list c.coercion_mater_vars)^"\n";; *)

let string_of_coercion c = string_of_coerc_long c ;;

let string_of_coerc c = string_of_coercion c ;;

let rec string_of_coerc_list l = match l with 
  | [] -> ""
  | h::[] -> (string_of_coerc h) 
  | h::t -> (string_of_coerc h) ^ "\n|||\n" ^ (string_of_coerc_list t)

(* pretty printing for a procedure *)
let string_of_proc_decl p = 
  let locstr = (string_of_full_loc p.proc_loc)  
  in  (string_of_typ p.proc_return) ^ " " ^ p.proc_name ^ "(" ^ (string_of_decl_list p.proc_args ",") ^ ")"
      ^ (if Gen.is_empty p.proc_by_name_params then "" 
	  else ("\n@ref " ^ (String.concat ", " (List.map string_of_spec_var p.proc_by_name_params)) ^ "\n"))
      ^ (if Gen.is_empty p.proc_by_copy_params then "" 
	  else ("\n@copy " ^ (String.concat ", " (List.map string_of_spec_var p.proc_by_copy_params)) ^ "\n"))
      ^ (if p.proc_is_recursive then " rec" else "") ^ "\n"
      ^ "static " ^ (string_of_struc_formula p.proc_static_specs) ^ "\n"
      ^ "dynamic " ^ (string_of_struc_formula p.proc_dynamic_specs) ^ "\n"
      ^ (match p.proc_body with 
        | Some e -> (string_of_exp e) ^ "\n\n"
	    | None -> "") ^ locstr^"\n"
;; 

let string_of_proc_decl i p =
  Debug.no_1_num  i "string_of_proc_decl " (fun p -> p.proc_name) (fun x -> x) string_of_proc_decl p

(* pretty printing for a list of data_decl *)
let rec string_of_data_decl_list l = match l with 
  | [] -> ""
  | h::[] -> (string_of_data_decl h) 
  | h::t -> (string_of_data_decl h) ^ "\n" ^ (string_of_data_decl_list t)
;;

(* pretty printing for a list of proc_decl *)
let rec string_of_proc_decl_list l = match l with 
  | [] -> ""
  | h::[] -> (string_of_proc_decl 1 h) 
  | h::t -> (string_of_proc_decl 2 h) ^ "\n" ^ (string_of_proc_decl_list t)
;;

let string_of_proc_decl_list l =
  Debug.no_1 " string_of_proc_decl_list" (fun _ -> "?") (fun _ -> "?") string_of_proc_decl_list l

(* pretty printing for a list of view_decl *)
let rec string_of_view_decl_list l = match l with 
  | [] -> ""
  | h::[] -> (string_of_view_decl h) 
  | h::t -> (string_of_view_decl h) ^ "\n" ^ (string_of_view_decl_list t)
;;
let rec string_of_barrier_decl_list l = match l with 
  | [] -> ""
  | h::[] -> (string_of_barrier_decl h) 
  | h::t -> (string_of_barrier_decl h) ^ "\n" ^ (string_of_barrier_decl_list t)
;;

(* An Hoa : print relations *)
let string_of_rel_decl_list rdecls = 
	String.concat "\n" (List.map (fun r -> "relation " ^ r.rel_name) rdecls)

(* An Hoa : print axioms *)
let string_of_axiom_decl_list adecls = 
	String.concat "\n" (List.map (fun a -> "axiom " ^ (string_of_pure_formula a.axiom_hypothesis) ^ " |- " ^ (string_of_pure_formula a.axiom_conclusion)) adecls)

let rec string_of_coerc_decl_list l = match l with
  | [] -> ""
  | h::[] -> string_of_coerc h
  | h::t -> (string_of_coerc h) ^ "\n" ^ (string_of_coerc_decl_list t)
;;

let string_of_prog_or_branches ((prg,br):prog_or_branches) =
  match br with 
    | None -> "None"
    | Some (mf,(i,lv)) -> ((string_of_mix_formula mf)
          ^ "\n pred:"^i
          ^ "\n to_vars:"^(Gen.Basic.pr_list string_of_spec_var lv)
      )
;;

(* pretty printing for a program written in core language *)
let string_of_program p = "\n" ^ (string_of_data_decl_list p.prog_data_decls) ^ "\n\n" ^ 
  (string_of_view_decl_list p.prog_view_decls) ^ "\n\n" ^ 
  (string_of_barrier_decl_list p.prog_barrier_decls) ^ "\n\n" ^ 
  (string_of_rel_decl_list p.prog_rel_decls) ^ "\n\n" ^ 
  (string_of_axiom_decl_list p.prog_axiom_decls) ^ "\n\n" ^ 
  (* WN_all_lemma - override usage? *)
  (string_of_coerc_decl_list (*p.prog_left_coercions*) (Lem_store.all_lemma # get_left_coercion))^"\n\n"^
  (string_of_coerc_decl_list (*p.prog_right_coercions*) (Lem_store.all_lemma # get_right_coercion))^"\n\n"^
  (* TODO: PD *)
  (*(string_of_proc_decl_list p.old_proc_decls) ^ "\n"*)
  (string_of_proc_decl_list (Cast.list_of_procs p)) ^ "\n"
;;

(* pretty printing for program written in core language separating prelude.ss program *)                                                            
let string_of_program_separate_prelude p (iprims:Iast.prog_decl)= 
   let remove_prim_procs procs=
		List.fold_left (fun a b->
			try 
			if( (BatString.starts_with b.Cast.proc_name ("is_not_null___"^"$")) 
					|| (BatString.starts_with b.Cast.proc_name ("is_null___"^"$")) )
			then a else		 	
			let _=List.find (fun c-> (BatString.starts_with b.Cast.proc_name (c.Iast.proc_name^"$")) 
																) iprims.Iast.prog_proc_decls in 
			a
			with Not_found ->
				a@[b]  
		) [] procs
	 in
	 let remove_prim_data_decls p_data_decls=
		List.fold_left (fun a b->
			(* if(b.Cast.data_name="__Exc" || b.Cast.data_name="__Error") *)
			(* then a else                                                *)
			try 
			let _=List.find (fun c-> (b.Cast.data_name = c.Iast.data_name) 
																) iprims.Iast.prog_data_decls in 
			a
			with Not_found ->
				a@[b]  
		) [] p_data_decls
	 in
	 let remove_prim_rel_decls p_rel_decls=
		List.fold_left (fun a b->
			try 
			let _=List.find (fun c-> (b.Cast.rel_name = c.Iast.rel_name) 
																) iprims.Iast.prog_rel_decls in 
			a
			with Not_found ->
				a@[b]  
		) [] p_rel_decls
	 in
	 let remove_prim_axiom_decls p_axiom_decls=
		List.fold_left (fun a b->
			try 
			let _=List.find (fun c-> (b.Cast.axiom_id = c.Iast.axiom_id) 
																) iprims.Iast.prog_axiom_decls in 
			a
			with Not_found ->
				a@[b]  
		) [] p_axiom_decls
	 in
	 let datastr= (string_of_data_decl_list (remove_prim_data_decls p.prog_data_decls)) in
	 let viewstr=(string_of_view_decl_list p.prog_view_decls) in
	 let barrierstr=(string_of_barrier_decl_list p.prog_barrier_decls) in
	 let relstr=(string_of_rel_decl_list (remove_prim_rel_decls p.prog_rel_decls)) in
	 let axiomstr=(string_of_axiom_decl_list (remove_prim_axiom_decls p.prog_axiom_decls)) in
	 let left_coerstr=(string_of_coerc_decl_list (Lem_store.all_lemma # get_left_coercion) (*p.prog_left_coercions*)) in
	 let right_coerstr=(string_of_coerc_decl_list (Lem_store.all_lemma # get_right_coercion) (*p.prog_right_coercions*)) in
	 let procsstr=(string_of_proc_decl_list (remove_prim_procs (Cast.list_of_procs p))) in
	 (* let _=print_endline (if (procsstr<>"") then procsstr^"XUAN BACH\n" else "NULL\n") in *)
	 let datastr=if(datastr<>"") then datastr^"\n\n" else "" in
	 let viewstr=if(viewstr<>"") then viewstr^"\n\n" else "" in
	 let barrierstr=if(barrierstr<>"") then barrierstr^"\n\n" else "" in
	 let relstr=if(relstr<>"") then relstr^"\n\n" else "" in
	 let axiomstr=if(axiomstr<>"") then axiomstr^"\n\n" else "" in
	 let left_coerstr=if(left_coerstr<>"") then left_coerstr^"\n\n" else "" in
	 let right_coerstr=if(right_coerstr<>"") then right_coerstr^"\n\n" else "" in
	 let procsstr=if(procsstr <> "") then procsstr^"\n\n" else "" in
   "\n" ^ datastr
   ^ viewstr
	 ^ barrierstr
   ^ relstr
   ^ axiomstr
   ^ left_coerstr
   ^ right_coerstr
	 ^ procsstr
   ^ "\n"
;;
                                         
(*
  Created 22-Feb-2006
  Pretty printing fo the AST for the core language
*)

let string_of_label_partial_context (fs,_) : string =
  if (Gen.is_empty fs) then "" else string_of_path_trace(fst(List.hd fs))

let string_of_label_list_partial_context (cl:Cformula.list_partial_context) : string =
  if (Gen.is_empty cl) then "" else string_of_label_partial_context (List.hd cl)

let string_of_label_failesc_context (fs,_,_) : string =
  if (Gen.is_empty fs) then "" else string_of_path_trace(fst(List.hd fs))

(*let get_label_list_partial_context (cl:Cformula.list_partial_context) : string =
if (Gen.is_empty cl) then "" else get_label_partial_context (List.hd cl)
;;*)

let string_of_label_list_failesc_context (cl:Cformula.list_failesc_context) : string =
  if (Gen.is_empty cl) then "" else string_of_label_failesc_context (List.hd cl)
;;

let string_of_failure_list_failesc_context (lc: Cformula.list_failesc_context) =  
  let lc = Cformula.keep_failure_list_failesc_context lc
  in string_of_list_failesc_context lc
;;

let string_of_failure_list_partial_context (lc: Cformula.list_partial_context) =  
  let lc = Cformula.keep_failure_list_partial_context lc
  in string_of_list_partial_context lc
;;

let app_sv_print xs ys =
    (* does not seem to have redundant rhs_eq_set *)
    begin
    let pr = string_of_spec_var in
    let pr2 = Gen.Basic.pr_list (Gen.Basic.pr_pair pr pr) in
    let _ = print_string ("\n first eqn set"^(pr2 xs)) in
    let _ = print_string ("\n second eqn set:"^(pr2 ys)) in
    xs@ys 
    end
;;

(* An Hoa : formula to HTML output facility *)

(* HTML for operators *)
let html_op_add = " + " 
let html_op_sub = " - " 
let html_op_mult = " &sdot; " 
let html_op_div = " &divide; " 
let html_op_max = "<b>max</b>" 
let html_op_min = "<b>min</b>" 
let html_op_union = " &cup; " 
let html_op_intersect = " &cap; " 
let html_op_diff = " \\ " 
let html_op_lt = " &lt; " 
let html_op_lte = " &le; " 
let html_op_subann = " <: " 
let html_op_gt = " &gt; " 
let html_op_gte = " &ge; " 
let html_op_eq = " = " 
let html_op_neq = " &ne; " 
let html_op_and = " &and; "  
let html_op_or = " &or; "  
let html_op_not = " &not; "  
let html_op_star = " &lowast; "
let html_op_starminus = " -&lowast; "   
let html_op_phase = " ; "  
let html_op_conj = " U&and; "  
let html_op_conjstar = " &and;&lowast; " 
let html_op_conjconj = " &and; " 
let html_op_f_or = " <b>or</b> " 
let html_op_lappend = "<b>append</b>"
let html_op_cons = " ::: "
let html_op_in = " &isin; "
let html_op_notin = " &notin; "
let html_op_subset = " &sub; "
let html_arrow = " --> " 

(* Other characters *)
let html_exist = " &exist; "
let html_forall = " &forall; "
let html_mapsto = " &#8614; " (* |-> *)
let html_vdash = " &#8866; " (* |- character in HTML *)
let html_left_angle_bracket = "&lang;"
let html_right_angle_bracket = "&rang;"
let html_data_field_hole = "&loz;"
let html_prime = "&prime;"

let html_of_spec_var sv = match sv with
	| P.SpecVar (t,n,p) -> n ^ (match p with
		| Primed -> html_prime 
		| Unprimed -> "")

let html_of_view_arg sv = match sv with
  |P.SVArg sv   -> html_of_spec_var sv 
  |P.AnnotArg a -> string_of_annot_arg a

let html_of_spec_var_list svl = String.concat ", " (List.map html_of_spec_var svl)

let html_of_view_arg_list svl = String.concat ", " (List.map html_of_view_arg svl)

let rec html_of_formula_exp e =
	 match e with
    | P.Null l -> "<b>null</b>"
    | P.Var (x, l) -> html_of_spec_var x
    | P.Level (x, l) -> "<level>" ^ html_of_spec_var x ^ "</level>"
    | P.IConst (i, l) -> string_of_int i
    | P.FConst (f, l) -> string_of_float f
    | P.AConst (f, l) -> string_of_heap_ann f
    | P.Tsconst(f, l) -> Tree_shares.Ts.string_of f
	| P.Bptriple((vc,vt,va), l) -> "<bperm>" ^ html_of_spec_var vc ^ " " ^ html_of_spec_var vt ^ " " ^ html_of_spec_var va ^ " " ^ "</bperm>"
    | P.Add (e1, e2, l) -> 
          let args = bin_op_to_list op_add_short exp_assoc_op e in
          String.concat html_op_add (List.map html_of_formula_exp args)
    | P.Mult (e1, e2, l) -> 
          let args = bin_op_to_list op_mult_short exp_assoc_op e in
          String.concat html_op_mult (List.map html_of_formula_exp args)
    | P.Max (e1, e2, l) -> 
          let args = bin_op_to_list op_max_short exp_assoc_op e in
          html_op_max ^ "(" ^ (String.concat "," (List.map html_of_formula_exp args)) ^ ")"
    | P.Min (e1, e2, l) -> 
          let args = bin_op_to_list op_min_short exp_assoc_op e in
          html_op_min ^ "(" ^ (String.concat "," (List.map html_of_formula_exp args)) ^ ")"
    | P.TypeCast (ty, e1, l) ->
          "(" ^ (Globals.string_of_typ ty) ^ ")" ^ (html_of_formula_exp e1)
    | P.Bag (elist, l) 	-> "{" ^ (String.concat "," (List.map html_of_formula_exp elist)) ^ "}"
    | P.BagUnion (args, l) -> 
		let args = bin_op_to_list op_union_short exp_assoc_op e in
		String.concat html_op_union (List.map html_of_formula_exp args)
    | P.BagIntersect (args, l) -> 
		let args = bin_op_to_list op_intersect_short exp_assoc_op e in
		String.concat html_op_intersect (List.map html_of_formula_exp args)
    | P.Subtract (e1, e2, l) ->
		(html_of_formula_exp e1) ^ html_op_sub ^ (html_of_formula_exp e2)
    | P.Div (e1, e2, l) ->
	    (html_of_formula_exp e1) ^ html_op_div ^ (html_of_formula_exp e2)
    | P.BagDiff (e1, e2, l) -> 
		(html_of_formula_exp e1) ^ " \ " ^ (html_of_formula_exp e2)
    | P.List (elist, l) -> "[" ^ (String.concat "," (List.map html_of_formula_exp elist)) ^ "]"
    | P.ListAppend (elist, l) -> String.concat html_op_lappend (List.map html_of_formula_exp elist)
    | P.ListCons (e1, e2, l)  ->  (html_of_formula_exp e1) ^ html_op_cons ^ (html_of_formula_exp e2)
    | P.ListHead (e, l) -> "<b>head</b>(" ^ (html_of_formula_exp e) ^ ")"
    | P.ListTail (e, l) -> "<b>tail</b>(" ^ (html_of_formula_exp e) ^ ")"
    | P.ListLength (e, l) -> "<b>len</b>(" ^ (html_of_formula_exp e) ^ ")"
    | P.ListReverse (e, l)  -> "<b>rev</b>(" ^ (html_of_formula_exp e) ^ ")"
    | P.Func (a, i, l) -> (html_of_spec_var a) ^ "(" ^ (String.concat "," (List.map html_of_formula_exp i)) ^ ")"
	| P.ArrayAt (a, i, l) -> (html_of_spec_var a) ^ "[" ^ (String.concat "," (List.map html_of_formula_exp i)) ^ "]"
	| P.InfConst _ -> Error.report_no_pattern ()

let rec html_of_pure_b_formula f = match f with
    | P.XPure _ -> "<b> XPURE </b>"
    | P.BConst (b,l) -> "<b>" ^ (string_of_bool b) ^ "</b>"
    | P.BVar (x, l) -> html_of_spec_var x
    | P.Lt (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_lt ^ (html_of_formula_exp e2)
    | P.Lte (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_lte ^ (html_of_formula_exp e2)
    | P.SubAnn (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_subann ^ (html_of_formula_exp e2)
    | P.LexVar _ -> "LexVar(to be implemented)"
  (* | P.Lexvar (ls1,ls2, l)        ->  *)
  (*       let opt = if ls2==[] then "" else *)
  (*         "{"^(pr_list html_of_formula_exp ls2)^"}" *)
  (*       in "LexVar["^(pr_list html_of_formula_exp ls1)^"]"^opt *)
    | P.Gt (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_gt ^ (html_of_formula_exp e2)
    | P.Gte (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_gte ^ (html_of_formula_exp e2)
    | P.Eq (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_eq ^ (html_of_formula_exp e2)
    | P.Neq (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_neq ^ (html_of_formula_exp e2)
    | P.EqMax (e1, e2, e3, l) -> 
    	let arg2 = bin_op_to_list op_min_short exp_assoc_op e2 in
		let arg3 = bin_op_to_list op_min_short exp_assoc_op e3 in
		let args = arg2@arg3 in
			(html_of_formula_exp e1) ^ html_op_eq ^ html_op_max ^ "(" ^ (String.concat "," (List.map html_of_formula_exp args)) ^ ")"
    | P.EqMin (e1, e2, e3, l) -> 
    	let arg2 = bin_op_to_list op_min_short exp_assoc_op e2 in
		let arg3 = bin_op_to_list op_min_short exp_assoc_op e3 in
		let args = arg2@arg3 in
			(html_of_formula_exp e1) ^ html_op_eq ^ html_op_min ^ "(" ^ (String.concat "," (List.map html_of_formula_exp args)) ^ ")"
    | P.BagIn (v, e, l) -> (html_of_spec_var v) ^ html_op_in ^ (html_of_formula_exp e)
    | P.BagNotIn (v, e, l) -> (html_of_spec_var v) ^ html_op_notin ^ (html_of_formula_exp e)
    | P.BagSub (e1, e2, l) -> (html_of_formula_exp e1) ^ html_op_subset ^ (html_of_formula_exp e2)
    | P.BagMin (v1, v2, l) -> (html_of_spec_var v1) ^ html_op_eq ^ html_op_min ^ (string_of_spec_var v2) 
    | P.BagMax (v1, v2, l) -> (html_of_spec_var v1) ^ html_op_eq ^ html_op_max ^ (string_of_spec_var v2)
    | CP.VarPerm (ann,ls,l) -> (string_of_vp_ann ann) ^ (html_of_spec_var_list ls)
    | P.ListIn (e1, e2, l) ->  (html_of_formula_exp e1) ^ " <Lin> " ^ (html_of_formula_exp e2)
    | P.ListNotIn (e1, e2, l) ->  (html_of_formula_exp e1) ^ " <Lnotin> " ^ (html_of_formula_exp e2)
    | P.ListAllN (e1, e2, l) ->  (html_of_formula_exp e1) ^ " <allN> " ^ (html_of_formula_exp e2)
    | P.ListPerm (e1, e2, l) -> (html_of_formula_exp e1) ^ " <perm> " ^ (html_of_formula_exp e2)
	| P.RelForm (r, args, l) -> (html_of_spec_var r) ^ "(" ^ (String.concat "," (List.map html_of_formula_exp args)) ^ ")"

let rec html_of_pure_formula f =
	match f with
    | P.BForm ((bf,_),_) -> html_of_pure_b_formula bf
    | P.And (f1, f2, l) -> 
		let arg1 = bin_op_to_list op_and_short pure_formula_assoc_op f1 in
		let arg2 = bin_op_to_list op_and_short pure_formula_assoc_op f2 in
		let args = arg1@arg2 in
			"(" ^ (String.concat html_op_and (List.map html_of_pure_formula args)) ^ ")"
	| P.AndList b -> if b==[] then "[]" else String.concat " && " (List.map (fun c-> html_of_pure_formula (snd c))b)
    | P.Or (f1, f2, lbl,l) -> 
		let arg1 = bin_op_to_list op_or_short pure_formula_assoc_op f1 in
		let arg2 = bin_op_to_list op_or_short pure_formula_assoc_op f2 in
		let args = arg1@arg2 in
			"(" ^ (String.concat html_op_or (List.map html_of_pure_formula args)) ^ ")"
    | P.Not (f1, lbl, l) -> html_op_not ^ (html_of_pure_formula f1)
    | P.Forall (x, f1,lbl, l) ->
    	html_forall ^ (html_of_spec_var x) ^ " " ^ (html_of_pure_formula f1)
    | P.Exists (x, f1, lbl, l) ->
    	html_exist ^ (html_of_spec_var x) ^ " " ^ (html_of_pure_formula f1)

let rec html_of_h_formula h = match h with
	| Star ({h_formula_star_h1 = h1;
			h_formula_star_h2 = h2;
			h_formula_star_pos = pos}) -> 
		let arg1 = bin_op_to_list op_star_short h_formula_assoc_op h1 in
		let arg2 = bin_op_to_list op_star_short h_formula_assoc_op h2 in
		let args = arg1@arg2 in
			String.concat html_op_star (List.map html_of_h_formula args)
	| StarMinus ({h_formula_starminus_h1 = h1;
			h_formula_starminus_h2 = h2;
			h_formula_starminus_pos = pos}) -> 
		let arg1 = bin_op_to_list op_starminus_short h_formula_assoc_op h2 in
		let arg2 = bin_op_to_list op_starminus_short h_formula_assoc_op h1 in
		let args = arg1@arg2 in
			String.concat html_op_starminus (List.map html_of_h_formula args)			
	| Phase ({h_formula_phase_rd = h1;
			h_formula_phase_rw = h2;
			h_formula_phase_pos = pos}) -> 
		let arg1 = bin_op_to_list op_phase_short h_formula_assoc_op h1 in
		let arg2 = bin_op_to_list op_phase_short h_formula_assoc_op h2 in
		let args = arg1@arg2 in
			String.concat html_op_phase (List.map html_of_h_formula args)
	| Conj ({h_formula_conj_h1 = h1;
			h_formula_conj_h2 = h2;
			h_formula_conj_pos = pos}) -> 
		let arg1 = bin_op_to_list op_conj_short h_formula_assoc_op h1 in
		let arg2 = bin_op_to_list op_conj_short h_formula_assoc_op h2 in
		let args = arg1@arg2 in
			String.concat html_op_conj (List.map html_of_h_formula args)
	| ConjStar ({h_formula_conjstar_h1 = h1;
			h_formula_conjstar_h2 = h2;
			h_formula_conjstar_pos = pos}) -> 
		let arg1 = bin_op_to_list op_conjstar_short h_formula_assoc_op h1 in
		let arg2 = bin_op_to_list op_conjstar_short h_formula_assoc_op h2 in
		let args = arg1@arg2 in
			String.concat html_op_conjstar (List.map html_of_h_formula args)
	| ConjConj ({h_formula_conjconj_h1 = h1;
			h_formula_conjconj_h2 = h2;
			h_formula_conjconj_pos = pos}) -> 
		let arg1 = bin_op_to_list op_conjconj_short h_formula_assoc_op h1 in
		let arg2 = bin_op_to_list op_conjconj_short h_formula_assoc_op h2 in
		let args = arg1@arg2 in
			String.concat html_op_conjconj (List.map html_of_h_formula args)						
	| DataNode ({h_formula_data_node = sv;
				h_formula_data_name = c;
                h_formula_data_derv = dr;
				h_formula_data_imm = imm;
                h_formula_data_param_imm = ann_param; (* (andreeac) add param ann to html printer *)
				h_formula_data_arguments = svs;
				h_formula_data_holes = hs; 
				h_formula_data_pos = pos;
				h_formula_data_remaining_branches = ann;
				h_formula_data_label = pid})->
			let html_svs,_ = List.fold_left (fun (l,n) sv ->
				let nsv = if (List.mem n hs) then html_data_field_hole else html_of_spec_var sv in (nsv::l,n+1)) ([],0) svs in
			let html_svs = List.rev html_svs in
				(html_of_spec_var sv) ^ html_mapsto ^ c ^  html_left_angle_bracket ^ (String.concat "," html_svs) ^ html_right_angle_bracket 
    | ThreadNode ({h_formula_thread_node =sv;
      h_formula_thread_name = c;
      h_formula_thread_delayed = dl;
      h_formula_thread_resource = rsr;
	  h_formula_thread_derv = dr;
      h_formula_thread_perm = perm; (*LDK*)
      h_formula_thread_origins = origs;
      h_formula_thread_original = original;
      h_formula_thread_pos = pos;
      h_formula_thread_label = pid;}) ->
			let html_delayed = html_of_pure_formula dl in
            let html_rsr = html_of_formula rsr in
			(html_of_spec_var sv) ^ html_mapsto ^ c ^  html_left_angle_bracket ^ html_delayed ^ html_arrow ^ html_rsr ^ html_right_angle_bracket 
	| ViewNode ({h_formula_view_node = sv; 
				h_formula_view_name = c; 
				h_formula_view_derv = dr;
				h_formula_view_imm = imm;
				h_formula_view_arguments = svs; 
                                h_formula_view_args_orig = svs_orig;  
				h_formula_view_origins = origs;
                                h_formula_view_annot_arg = anns;  
				h_formula_view_original = original;
				h_formula_view_lhs_case = lhs_case;
				h_formula_view_label = pid;
				h_formula_view_remaining_branches = ann;
				h_formula_view_pruning_conditions = pcond;
				h_formula_view_pos =pos}) ->
	      (* (html_of_spec_var sv) ^ html_mapsto ^ c ^ html_left_angle_bracket ^ (html_of_spec_var_list svs) ^ html_right_angle_bracket *)
              let params = CP.create_view_arg_list_from_pos_map svs_orig svs anns in
	      (html_of_spec_var sv) ^ html_mapsto ^ c ^ html_left_angle_bracket ^ (html_of_view_arg_list params) ^ html_right_angle_bracket
  | HTrue -> "<b>htrue</b>"
  | HFalse -> "<b>hfalse</b>"
  | HEmp -> "<b>emp</b>"
  | HRel (r, args, l) -> (* "<b>HRel</b>" ^ *) (string_of_spec_var r) ^ "(" ^ (match args with
      | [] -> ""
      | arg_first::arg_rest -> List.fold_left (fun a x -> a ^ "," ^ (html_of_formula_exp x)) (html_of_formula_exp arg_first) arg_rest) ^ ")"
  | Hole m -> "<b>Hole</b>[" ^ (string_of_int m) ^ "]"

and html_of_formula e = match e with
	| Or ({formula_or_f1 = f1;
			formula_or_f2 = f2;
			formula_or_pos = pos}) ->
		let arg1 = bin_op_to_list op_f_or_short formula_assoc_op f1 in
		let arg2 = bin_op_to_list op_f_or_short formula_assoc_op f2 in
		let args = arg1@arg2 in
			String.concat " <b>or</b>\n" (List.map html_of_formula args)
	| Base ({formula_base_heap = h;
			formula_base_pure = p;
			formula_base_type = t;
			formula_base_flow = fl;
			formula_base_label = lbl;
			formula_base_pos = pos}) ->
		(html_of_h_formula h) ^ html_op_and ^ (html_of_pure_formula (MP.pure_of_mix p))
	| Exists ({formula_exists_qvars = svs;
			formula_exists_heap = h;
			formula_exists_pure = p;
			formula_exists_type = t;
			formula_exists_flow = fl;
			formula_exists_label = lbl;
			formula_exists_pos = pos}) ->
		html_exist ^ (html_of_spec_var_list svs) ^ " : " ^ (html_of_h_formula h) ^ html_op_and ^ (html_of_pure_formula (MP.pure_of_mix p))

let rec html_of_struc_formula f = match f with
	| ECase { 
					formula_case_branches = case_list;} ->
		"ECase " ^ (String.concat " &oplus; " (List.map (fun (case_guard,case_fml) -> (html_of_pure_formula case_guard) ^ " ==> " ^ (html_of_struc_formula case_fml)) case_list))
	| EBase { formula_struc_implicit_inst = ii;
					formula_struc_explicit_inst = ei;
					formula_struc_exists = ee;
					formula_struc_base = fb;
					formula_struc_continuation = cont;} ->
		"EBase " ^ (if not (Gen.is_empty(ee@ii@ei)) then "exists " ^ "(Expl)" ^ (html_of_spec_var_list ei) ^ "(Impl)" ^ (html_of_spec_var_list ii) ^ "(ex)" ^ 
		(html_of_spec_var_list ee)	else "") ^ (html_of_formula fb) ^ (match cont with | None -> "" | Some l -> html_of_struc_formula l)
	| EAssume {
			formula_assume_vars = x;
			formula_assume_simpl = b;
			formula_assume_lbl = (y1,y2);
			formula_assume_ensures_type = t;
			formula_assume_struc = s;}->
    let assume_str = match t with
                     | None -> "EAssume "
                     | Some true -> "EAssume_exact "
                     | Some false -> "EAssume_inexact " in
		assume_str ^ (if not (Gen.is_empty(x)) then "ref " ^ (html_of_spec_var_list x) else "") ^ (html_of_formula b)
	| EInfer _ -> ""
	| EList b -> if b==[] then "[]" else String.concat "|| " (List.map (fun c-> html_of_struc_formula (snd c))b)
    
	

let html_of_estate es = "{ " ^ html_of_formula es.es_formula ^ " }"

let html_of_context ctx = 
  let args = bin_op_to_list "|" ctx_assoc_op ctx in
  let args = List.fold_left (fun a x -> 
      match x with 
        | Ctx es -> es::a
        | _ -> a) [] args in
  String.concat "<br /><br /><b>OR</b> " (List.map html_of_estate args)

(* TODO implement *)
let html_of_fail_type f = ""

let html_of_failesc_context (fs,es,ss) =
	let htmlfs = if fs = [] then "&empty;" else "{" ^ (String.concat " , " (List.map html_of_fail_type fs)) ^ "}" in
	let htmlss = if ss = [] then "&empty;" else "{" ^ (String.concat "<br /><br /><b>OR</b> " (List.map (fun (pt, c) -> html_of_context c) ss)) ^ "}" in
		"[Failed state : " ^ htmlfs ^ "<br />\n" ^ "Successful states : " ^ htmlss ^ "]"

let html_of_list_failesc_context lctx = String.concat "<br /><br /><b>AND</b> " (List.map html_of_failesc_context lctx)

let html_of_partial_context (fs,ss) =
	html_of_failesc_context (fs,[],ss)

let html_of_list_partial_context lctx = String.concat "<br /><br /><b>AND</b> " (List.map html_of_partial_context lctx)
;;

let pr_html_path_of (path, off)=
   (* fmt_string "PATH format"; *)
   pr_wrap_test_nocut "" skip_cond_path_trace  (fun l -> fmt_string (pr_list_round_sep ";" string_of_int l)) path
  ; (match off with
     | None -> fmt_string " NONE"
     | Some f -> fmt_string (html_of_formula f))

let pr_html_hprel_def_short hpd =
  fmt_open_box 1;
  (fmt_string (html_of_h_formula hpd.hprel_def_hrel));
  let _ = match hpd.hprel_def_guard with
    | None -> ()
    | Some hf -> 
          begin
            fmt_string " |#| ";
            fmt_string (html_of_formula hf)
          end
  in
  fmt_string " ::=";
  match hpd.hprel_def_body_lib with
    | None -> (pr_list_op_none " \/ " pr_html_path_of) hpd.hprel_def_body;
    | Some f -> fmt_string (html_of_formula f);
  fmt_close()

let pr_html_hprel_short_inst cprog hpa=
  fmt_open_box 1;
  if not(!Globals.is_sleek_running) then
    begin
      fmt_string ("// "^(Others.string_of_proving_kind hpa.hprel_proving_kind));
      fmt_print_newline()
    end;
  pr_wrap_test_nocut "" Gen.is_empty (* skip_cond_path_trace *) 
      (fun p -> fmt_string ((pr_list_round_sep ";" (fun s -> string_of_int s)) p)) hpa.hprel_path;
  (* prtt_pr_formula_inst cprog hpa.hprel_lhs; *)
  fmt_string (html_of_formula hpa.hprel_lhs);
  let _ = match hpa.hprel_guard with
    | None -> ()
          (* fmt_string " NONE " *)
    | Some hf -> 
          begin
            fmt_string " |#| ";
            (* prtt_pr_formula_inst cprog hf *)
            fmt_string (html_of_formula hf)
          end
  in
  fmt_string " --> ";
  (* prtt_pr_formula_inst cprog hpa.hprel_rhs; *)
  fmt_string (html_of_formula hpa.hprel_rhs);
  fmt_close()

let string_of_html_hprel_short_inst prog hp =
  poly_string_of_pr (pr_html_hprel_short_inst prog) hp

let string_of_html_hprel_def_short hp =
  poly_string_of_pr pr_html_hprel_def_short hp;;

Slicing.print_mp_f := string_of_memo_pure_formula ;;
Mcpure_D.print_mp_f := string_of_memo_pure_formula ;;
Mcpure_D.print_mg_f := string_of_memoised_group ;;
Mcpure.print_mp_f := string_of_memo_pure_formula ;;
Mcpure.print_mg_f := string_of_memoised_group ;;
Mcpure.print_mc_f := string_of_memoise_constraint ;;
Mcpure.print_sv_f := string_of_spec_var ;; 
Mcpure.print_sv_l_f := string_of_spec_var_list;;
Mcpure.print_bf_f := string_of_b_formula ;;
Mcpure.print_p_f_f := string_of_pure_formula ;;
Cpure.print_exp := string_of_formula_exp;;
(* Mcpure.print_exp_f := string_of_formula_exp;; *)
Mcpure.print_mix_f := string_of_mix_formula;;
(*Tpdispatcher.print_pure := string_of_pure_formula ;;*)
Cpure.print_b_formula := string_of_b_formula;;
Cpure.print_p_formula := string_of_p_formula;;
Cpure.print_formula := string_of_pure_formula;;
(*Cpure.print_formula_br := string_of_formula_branches;;*)
Cpure.print_svl := string_of_spec_var_list;;
Cpure.print_sv := string_of_spec_var;;
Cpure.print_annot_arg := string_of_annot_arg;;
Cformula.print_mem_formula := string_of_mem_formula;;
Cformula.print_imm := string_of_imm;;
Cformula.print_formula := string_of_formula;;
Cformula.print_formula_type := string_of_formula_type;;
Cformula.print_one_formula := string_of_one_formula;;
Cformula.print_formula_base := string_of_formula_base;;
Cformula.print_pure_f := string_of_pure_formula;;
Cformula.print_h_formula := string_of_h_formula;;
Cformula.print_h_formula_for_spec := string_of_h_formula_for_spec;;
(* Cformula.print_mix_formula := string_of_mix_formula;; *)
Cformula.print_svl := string_of_spec_var_list;;
Cformula.print_sv := string_of_spec_var;;
Cformula.print_ident_list := str_ident_list;;
Cformula.print_struc_formula :=string_of_struc_formula;;
Cformula.print_context_list_short := string_of_context_list_short;;
Cformula.print_list_context_short := string_of_list_context_short;;
Cformula.print_list_context := string_of_list_context;;
Cformula.print_list_partial_context := string_of_list_partial_context;;
Cformula.print_list_failesc_context := string_of_list_failesc_context;;
Cformula.print_failure_kind_full := string_of_failure_kind_full;;
Cformula.print_fail_type := string_of_fail_type;;
Cformula.print_hprel_def_short := string_of_hprel_def_short;;
(* Cformula.print_nflow := string_of_nflow;; *)
Cformula.print_flow := string_of_flow;;
Cformula.print_context_short := string_of_context_short;;
Cformula.print_context := string_of_context;;
Cformula.print_entail_state := string_of_entail_state(* _short *);;
Cformula.print_entail_state_short := string_of_entail_state_short;;
(* Cformula.print_formula_br := string_of_formula_branches;; *)
Redlog.print_formula := string_of_pure_formula;;
Cvc3.print_pure := string_of_pure_formula;;
Cformula.print_formula :=string_of_formula;;
Cformula.print_mix_f := string_of_mix_formula;;
Cformula.print_struc_formula :=string_of_struc_formula;;
Cformula.print_flow_formula := string_of_flow_formula "FLOW";;
Cformula.print_esc_stack := string_of_esc_stack;;
Cformula.print_failesc_context := string_of_failesc_context;;
Cformula.print_path_trace := string_of_path_trace;;
Cformula.print_fail_type := string_of_fail_type;;
Cformula.print_list_int := string_of_list_int;;
Cast.print_mix_formula := string_of_mix_formula;;
Cast.print_b_formula := string_of_b_formula;;
Cast.print_h_formula := string_of_h_formula;;
Cast.print_exp := string_of_formula_exp;;
Cast.print_prog_exp := string_of_exp;;
Cast.print_formula := string_of_formula;;
Cast.print_pure_formula := string_of_pure_formula;;
(* Cast.print_pure_formula := string_of_pure_formula;; *)
Cast.print_struc_formula := string_of_struc_formula;;
Cast.print_svl := string_of_spec_var_list;;
Cast.print_sv := string_of_spec_var;;
Cast.print_mater_prop := string_of_mater_property;;
Cast.print_mater_prop_list := string_of_mater_prop_list;;
Cast.print_view_decl := string_of_view_decl;
Cast.print_view_decl_short := string_of_view_decl_short;
Cast.print_hp_decl := string_of_hp_decl;
Cast.print_mater_prop_list := string_of_mater_prop_list;;
Cast.print_coercion := string_of_coerc_long;;
print_coerc_decl_list := string_of_coerc_decl_list;;
Omega.print_pure := string_of_pure_formula;;
Omega.print_exp := string_of_formula_exp;
Smtsolver.print_pure := string_of_pure_formula;;
Smtsolver.print_ty_sv := string_of_typed_spec_var;;
Coq.print_p_f_f := string_of_pure_formula ;;
Redlog.print_b_formula := string_of_b_formula;;
Redlog.print_exp := string_of_formula_exp;;
Redlog.print_formula := string_of_pure_formula;;
Redlog.print_svl := string_of_spec_var_list;;
Redlog.print_sv := string_of_spec_var;;
Mathematica.print_b_formula := string_of_b_formula;;
Mathematica.print_exp := string_of_formula_exp;;
Mathematica.print_formula := string_of_pure_formula;;
Mathematica.print_svl := string_of_spec_var_list;;
Mathematica.print_sv := string_of_spec_var;;
Perm.print_sv := string_of_spec_var;;
Perm.print_exp := string_of_formula_exp;;
Lem_store.lem_pr:= string_of_coerc_long;;
Lem_store.lem_pr_med:= string_of_coerc_med;;

