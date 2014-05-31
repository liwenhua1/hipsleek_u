(set-logic QF_S)

(declare-sort node 0)
(declare-fun val () (Field node int))
(declare-fun next () (Field node node))

(declare-fun ll ((?in node))
Space (tospace
(or
(= ?in nil)
(and 
(tobool (ssep 
(pto ?in (sref (ref val ?Anon_12) (ref next ?q) ))
(ll ?q)
) )
))))

(declare-fun lseg ((?in node) (?p node))
Space (tospace
(or
(= ?in ?p)
(exists ((?p_21 node)) (tobool (ssep (pto ?in (sref (ref val ?Anon_13) (ref next ?q) )) (lseg ?q ?p_21)))
)))









(declare-fun xprm () node)
(declare-fun yprm () TVar[77])
(declare-fun y () TVar[77])
(declare-fun x () node)
(declare-fun v_node_15_981prm () node)
(declare-fun Anon_1013 () int)
(declare-fun q_1014 () node)


(assert 
(and 
(distinct x nil)
(= y' y)
(= x' x)
(= v_node_15_981' q_1014)
(= v_node_15_981' nil)
(tobool (ssep 
(pto xprm (sref (ref val Anon_1013) (ref next q_1014) ))
(ll q_1014)
emp
) )
)
)

(assert (not 
(and 
(distinct x nil)
(= y' y)
(= x' x)
(= v_node_15_981' q_1014)
(= v_node_15_981' nil)
(tobool (ssep 
(pto xprm (sref (ref val Anon_1013) (ref next q_1014) ))
(ll q_1014)
emp
) )
)
))

(check-sat)