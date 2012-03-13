
Processing file "ll-reverse.ss"
Parsing ll-reverse.ss ...
Parsing ../../prelude.ss ...
Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...
Checking procedure reverse$node~node... 
INF-POST-FLAG: true
REL :  A(m,n,t)
POST:  n>=0 & m>=0 & n+m=t
PRE :  0<=n & 0<=m
OLD SPECS:  EInfer [A]
   EBase exists (Expl)(Impl)[n; m](ex)xs::ll<n>@M[Orig][LHSCase] * 
         ys::ll<m>@M[Orig][LHSCase]&true&{FLOW,(20,21)=__norm}
           EBase true&MayLoop&{FLOW,(1,23)=__flow}
                   EAssume 1::ref [xs;ys]
                     EXISTS(t: ys'::ll<t>@M[Orig][LHSCase]&xs'=null & 
                     A(m,n,t)&{FLOW,(20,21)=__norm})
NEW SPECS:  EBase exists (Expl)(Impl)[n; m](ex)xs::ll<n>@M[Orig][LHSCase] * 
       ys::ll<m>@M[Orig][LHSCase]&true&{FLOW,(20,21)=__norm}
         EBase true&0<=n & 0<=m & MayLoop&{FLOW,(1,23)=__flow}
                 EAssume 1::ref [xs;ys]
                   ys'::ll<t>@M[Orig][LHSCase]&n>=0 & m>=0 & n+m=t & 
                   xs'=null & 0<=n & 0<=m&{FLOW,(20,21)=__norm}
NEW RELS: [ (t=t_573 & n_550=n-1 & m_551=m+1 & 0<=t_573 & 1<=n & 0<=m & 
  A(m_551,n_550,t_573)) --> A(m,n,t), (n=0 & t=m & 0<=m) --> A(m,n,t)]

Procedure reverse$node~node SUCCESS

Termination checking result:

Stop Omega... 142 invocations 
0 false contexts at: ()

Total verification time: 0.32 second(s)
	Time spent in main process: 0.24 second(s)
	Time spent in child processes: 0.08 second(s)