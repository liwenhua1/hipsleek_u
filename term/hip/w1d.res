
Processing file "invalid-1d.ss"
Parsing invalid-1d.ss ...
Parsing ../../prelude.ss ...
Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...
Checking procedure foo$int... 
Procedure foo$int SUCCESS

Termination checking result:
(10)->(16) (ERR: not bounded) 
(10)->(16) (ERR: not decreasing) Term[0 - x]->Term[0 - v_int_16_472']
(10)->(16) (ERR: not decreasing) Term[0 - x]->Term[0]

Stop Omega... 69 invocations 
8 false contexts at: ( (16,17)  (16,15)  (16,11)  (16,9)  (16,2)  (16,9)  (14,2)  (14,9) )

Total verification time: 0.284017 second(s)
	Time spent in main process: 0.208013 second(s)
	Time spent in child processes: 0.076004 second(s)
