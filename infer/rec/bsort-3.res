
Processing file "bsort-3.ss"
Parsing bsort-3.ss ...
Parsing /home2/loris/hg/sl_infer/prelude.ss ...
Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...

Checking procedure bubble$node... 
!!! REL :  B(res)
!!! POST:  res
!!! PRE :  true
!!! NEW RELS:[ (res<=0) --> B(res),
 (res<=0) --> B(res),
 (res<=0) --> B(res),
 (res<=0) --> B(res),
 (B(tmp_42') & 1<=res & tmp_42') --> B(res),
 (B(tmp_42') & res<=0 & !(tmp_42')) --> B(res),
 (1<=res) --> B(res),
 (1<=res) --> B(res)]
!!! NEW ASSUME:[]
!!! NEW RANK:[]
Procedure bubble$node SUCCESS

Termination checking result:

Stop Omega... 516 invocations 
0 false contexts at: ()

Total verification time: 0.808049 second(s)
	Time spent in main process: 0.216013 second(s)
	Time spent in child processes: 0.592036 second(s)
