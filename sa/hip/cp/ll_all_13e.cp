HeapPred HP_574(node a).
HeapPred HP_570(node a).
HeapPred HP_1(node a).
HeapPred HP_682(node a, node b).

trav:SUCCESS[
ass [H1,G2][]:{
   H1(x)&true --> x::node<val_66_555',next_66_556'> * HP_570(next_66_556');
   H1(x)&true --> x::node<val_68_558',next_68_559'> * HP_574(next_68_559');
   HP_574(v_node_68_606)& v_node_68_606!=null --> H1(v_node_68_606);
   HP_570(res) * x::node<_,res>&true --> G2(res,x);
   HP_574(v_node_68_623) & v_node_68_623=null  --> emp&true;
   x::node<val_68_593,v_node_68_623>& res=x & v_node_68_623=null --> G2(res,x);
   G2(v_node_70_627,v_node_68_606) * x::node<val_68_595,v_node_70_627>&res=x &  v_node_68_606!=null  -->  G2(res,x)

 }

hpdefs [H1,G2][]:{
    HP_1(x) --> x=null or x::node<_,p> * HP_1(p);
    HP_682(x,_) --> emp&x=null
         or x::node<_,p> * HP_682(p,_);
    G2(res,x) --> res::node<_,p> * HP_682(p,x) & res=x;
    H1(x) --> x::node<_,p> * HP_1(p)
 }
]