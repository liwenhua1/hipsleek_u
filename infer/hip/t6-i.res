
Processing file "t6-i.ss"
Parsing t6-i.ss ...
Parsing /home2/loris/hg/sl_infer/prelude.ss ...
Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...
Checking procedure hd$node... 
Procedure hd$node SUCCESS
Checking procedure tl$node... 
Procedure tl$node SUCCESS
Checking procedure hdtl$node... 
Inferred Heap:[ x::node<inf_Anon_527,inf_528>@L[Orig], inf_528::node<inf_533,inf_Anon_534>@L[Orig]]
Inferred Pure:[]
Pre Vars :[inf_533,inf_Anon_534,inf_Anon_527,inf_528,x]
Exists Post Vars :[Anon_12,b,Anon_11,a,v_int_27_489']
Initial Residual Post : [ true & Anon_12=inf_Anon_527 & b=inf_528 & x'=b & a=inf_533 & 
Anon_11=inf_Anon_534 & v_int_27_489'=a & res=v_int_27_489' &
{FLOW,(20,21)=__norm}]
Final Residual Post :  true & x'=inf_528 & res=inf_533 & {FLOW,(20,21)=__norm}
OLD SPECS:  EInfer [x]
   EBase true & true & {FLOW,(20,21)=__norm}
           EAssume 3::ref [x]
             true & true & {FLOW,(20,21)=__norm}
NEW SPECS:  EBase x::node<inf_Anon_527,inf_528>@L[Orig] * 
       inf_528::node<inf_533,inf_Anon_534>@L[Orig] & true &
       {FLOW,(20,21)=__norm}
         EAssume 3::ref [x]
           true & x'=inf_528 & res=inf_533 & {FLOW,(20,21)=__norm}

Procedure hdtl$node SUCCESS
Stop Omega... 41 invocations 
0 false contexts at: ()

Total verification time: 0.056002 second(s)
	Time spent in main process: 0.040002 second(s)
	Time spent in child processes: 0.016 second(s)