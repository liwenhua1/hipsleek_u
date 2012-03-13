
Processing file "bst-del-b.ss"
Parsing bst-del-b.ss ...
Parsing ../../prelude.ss ...
Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...
Checking procedure delete$node2~int... 
dprint: bst-del-b.ss:66: ctx:  List of Failesc Context: [FEC(0, 0, 4  [(73::,0 ); (73::,0 ); (68::,0 ); (68::,0 ); (65::,0 ); (65::,0 )];  [(73::,1 ); (73::,1 ); (68::,0 ); (68::,0 ); (65::,0 ); (65::,0 )];  [(69::,0 ); (69::,0 ); (68::,1 ); (68::,1 ); (65::,0 ); (65::,0 )];  [(69::,1 ); (69::,1 ); (68::,1 ); (68::,1 ); (65::,0 ); (65::,0 )])]

Successful States:
[
 Label: [(73::,0 ); (73::,0 ); (68::,0 ); (68::,0 ); (65::,0 ); (65::,0 )]
 State:p_591::bst<sm_586,pl_588>@M[Orig] * q_592::bst<qs_589,lg_587>@M[Orig] * x'::node2<v_590,p_591,q_592>@M[Orig]&pl_588<=v_590 & v_590<=qs_589 & sm_586=sm & lg_587=lg & a'=a & x!=null & v_bool_36_532' & x!=null & v_bool_36_532' & v_590=a' & v_bool_41_528' & v_590=a' & v_bool_41_528' & q_592=null & v_bool_43_526' & q_592=null & v_bool_43_526' & x'=p_591&{FLOW,(20,21)=__norm}
       es_infer_vars/rel: [B]
       es_var_measures: MayLoop;
 Label: [(73::,1 ); (73::,1 ); (68::,0 ); (68::,0 ); (65::,0 ); (65::,0 )]
 State:EXISTS(s1_615,xright_34': p_591::bst<sm_586,pl_588>@M[Orig] * xright_34'::bst<s1_615,b>@M[Orig][LHSCase] * x'::node2<tmp_31',p_591,xright_34'>@M[Orig]&pl_588<=v_590 & v_590<=qs_589 & sm_586=sm & lg_587=lg & x'=x & a'=a & x'!=null & v_bool_36_532' & x'!=null & v_bool_36_532' & v_590=a' & v_bool_41_528' & v_590=a' & v_bool_41_528' & q_592!=null & 175::!(v_bool_43_526') & q_592!=null & !(v_bool_43_526') & s=qs_589 & b=lg_587 & qs_589<=lg_587 & s<=tmp_31' & tmp_31'<=s1_615 & s<=b&{FLOW,(20,21)=__norm})
       es_infer_vars/rel: [B]
       es_var_measures: MayLoop;
 Label: [(69::,0 ); (69::,0 ); (68::,1 ); (68::,1 ); (65::,0 ); (65::,0 )]
 State:EXISTS(s_640,l_641,xright_34': p_591::bst<sm_586,pl_588>@M[Orig] * xright_34'::bst<s_640,l_641>@M[Orig][LHSCase] * x'::node2<v_590,p_591,xright_34'>@M[Orig]&pl_588<=v_590 & v_590<=qs_589 & sm_586=sm & lg_587=lg & x'=x & a'=a & x'!=null & v_bool_36_532' & x'!=null & v_bool_36_532' & v_590!=a' & 163::!(v_bool_41_528') & v_590!=a' & !(v_bool_41_528') & v_590<a' & v_bool_60_527' & v_590<a' & v_bool_60_527' & sm_622=qs_589 & lg_623=lg_587 & qs_589<=lg_587 & sm_622<=s_640 & l_641<=lg_623 & B(sm_622,s_640,l_641,lg_623) & sm_622<=lg_623&{FLOW,(20,21)=__norm})
       es_infer_vars/rel: [B]
       es_var_measures: MayLoop;
 Label: [(69::,1 ); (69::,1 ); (68::,1 ); (68::,1 ); (65::,0 ); (65::,0 )]
 State:EXISTS(s_660,l_661,xleft_33': q_592::bst<qs_589,lg_587>@M[Orig] * xleft_33'::bst<s_660,l_661>@M[Orig][LHSCase] * x'::node2<v_590,xleft_33',q_592>@M[Orig]&pl_588<=v_590 & v_590<=qs_589 & sm_586=sm & lg_587=lg & x'=x & a'=a & x'!=null & v_bool_36_532' & x'!=null & v_bool_36_532' & v_590!=a' & 163::!(v_bool_41_528') & v_590!=a' & !(v_bool_41_528') & a'<=v_590 & 198::!(v_bool_60_527') & a'<=v_590 & !(v_bool_60_527') & sm_642=sm_586 & lg_643=pl_588 & sm_586<=pl_588 & sm_642<=s_660 & l_661<=lg_643 & B(sm_642,s_660,l_661,lg_643) & sm_642<=lg_643&{FLOW,(20,21)=__norm})
       es_infer_vars/rel: [B]
       es_var_measures: MayLoop
 ]

INF-POST-FLAG: false
REL :  B(sm,s,l,lg)
POST:  l>=sm & lg>=l & sm=s
PRE :  sm<=lg
OLD SPECS:  EInfer [B]
   EBase exists (Expl)(Impl)[sm; lg](ex)x::bst<sm,lg>@M[Orig][LHSCase]&true&
         {FLOW,(20,21)=__norm}
           EBase true&MayLoop&{FLOW,(1,23)=__flow}
                   EAssume 2::ref [x]
                     EXISTS(s,l: x'::bst<s,l>@M[Orig][LHSCase]&sm<=s & 
                     l<=lg & B(sm,s,l,lg)&{FLOW,(20,21)=__norm})
NEW SPECS:  EBase exists (Expl)(Impl)[sm; lg](ex)x::bst<sm,lg>@M[Orig][LHSCase]&true&
       {FLOW,(20,21)=__norm}
         EBase true&sm<=lg & MayLoop&{FLOW,(1,23)=__flow}
                 EAssume 2::ref [x]
                   x'::bst<s,l>@M[Orig][LHSCase]&sm<=s & l<=lg & 
                   B(sm,s,l,lg) & sm<=lg&{FLOW,(20,21)=__norm}
NEW RELS: [ (s=sm & sm<=l & l<=lg) --> B(sm,s,l,lg), (s=sm & sm<=l & l<=lg) --> B(sm,s,l,lg), (s=sm & sm<=l & l<=lg) --> B(sm,s,l,lg), (s=sm & sm<=l & l<=lg) --> B(sm,s,l,lg), (s=sm & sm<=l & l<=lg) --> B(sm,s,l,lg), (s=sm & l=lg & sm<=lg) --> B(sm,s,l,lg), (s=sm & sm<=l & l<=lg) --> B(sm,s,l,lg), (sm=s & l=lg & s<=lg) --> B(sm,s,l,lg), (s=sm & l=l_895 & lg_623=lg & sm<=sm_622 & sm_622<=s_894 & s_894<=l_895 & 
  l_895<=lg & B(sm_622,s_894,l_895,lg_623)) --> B(sm,s,l,lg), (sm_642=sm & s=s_957 & l=lg & sm<=s_957 & s_957<=l_958 & l_958<=lg_643 & 
  lg_643<=lg & B(sm_642,s_957,l_958,lg_643)) --> B(sm,s,l,lg), (s=sm & l=lg & sm<=lg) --> B(sm,s,l,lg)]

Procedure delete$node2~int SUCCESS

Termination checking result:

Stop Omega... 633 invocations 
0 false contexts at: ()

Total verification time: 2.67 second(s)
	Time spent in main process: 1.56 second(s)
	Time spent in child processes: 1.11 second(s)