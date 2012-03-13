open Camlp4.PreCast
open Cpure
open Globals
open Lexing
open Gen

module H = Hashtbl
module AS = Astsimp

let loc = no_pos;;

let stab = ref (H.create 103)

let expression = Gram.Entry.mk "expression";;

let or_formula = Gram.Entry.mk "or_formula";;

let formula = Gram.Entry.mk "formula";;

let pformula = Gram.Entry.mk "pformula";;

let exp = Gram.Entry.mk "exp";;

let specvar = Gram.Entry.mk "specvar";;

let get_var var stab = if is_substr "PRI" var 
  then AS.get_spec_var_ident stab (String.sub var 3 (String.length var - 3)) Primed
  else AS.get_spec_var_ident stab var Unprimed

let change_name var name = match var with
  | SpecVar (t,id,p) -> SpecVar (t,name ^ id,p)
  (*| _ -> report_error no_pos "Error in change_name"*)

let is_node var = match var with 
  | Var (SpecVar (_,id,_), _) -> is_substr "NOD" id
  | _ -> false

let get_node var = match var with 
  | Var (SpecVar (_,id,_), _) -> String.sub id 3 (String.length id - 3)
  | _ -> report_error no_pos "Expecting node var"

let is_rec_node var = match var with 
  | Var (SpecVar (_,id,_), _) -> is_substr "RECNOD" id
  | _ -> false

let get_rec_node var = match var with 
  | Var (SpecVar (_,id,_), _) -> String.sub id 6 (String.length id - 6)
  | _ -> report_error no_pos "Expecting rec node var"

let is_int c = '0' <= c && c <= '9'

EXTEND Gram
GLOBAL: expression or_formula formula pformula exp specvar;
  expression:
  [ "expression" NONA
    [ x = LIST1 or_formula -> x ]
  ];

  or_formula:
  [ "or_formula" LEFTA
    [ x = SELF; "||"; y = SELF -> mkOr x y None loc
    | x = formula -> x ]
  ];

  formula:
  [ "formula" LEFTA
    [ x = SELF; "&&"; y = SELF -> mkAnd x y loc
    | x = pformula -> x 
    ]
  ];

  pformula:
  [ "pformula" LEFTA
    [ x = exp; "<="; y = exp -> mkTrue loc
    | x = exp; ">="; y = exp -> mkTrue loc
    | x = exp; "="; y = exp -> BForm ((Eq (x, y, loc), None), None)
    ]
  ]; 
      
  exp:
  [ "exp" LEFTA
    [ x = SELF; "+"; y = SELF -> BagUnion([x; y], loc)
    | x = specvar -> Var (x,loc)
    | "|"; x = specvar; "|" -> Var (x,loc)
    | x = INT -> IConst (int_of_string x, loc) 
    ]
  ]; 
		
  specvar:
  [ "specvar" NONA
    [ x = UIDENT -> get_var x !stab
    ]
  ]; 

END
	
let parse_fix s = Gram.parse_string expression (Loc.mk "<string>") s