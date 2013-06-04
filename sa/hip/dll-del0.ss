data node2 {
	int val;
	node2 prev;
	node2 next;
}

dll<p> == self = null 
  or self::node2<_ ,p , q> * q::dll<self> // = q1
	inv true;

HeapPred G1(node2 a).
HeapPred H1(node2 a).

void delete(node2 x)
  /* infer[n] */

/*
  requires x::node2<_,p,q>*q::dll<x> & q!=null
  ensures x::node2<_,p,r>*r::dll<x> ;
*/

  infer[H1,G1]
  requires H1(x)
  ensures  G1(x);
{
  bool l = x.next.next==null;
  if (l) {
    // dprint;
    x.next = null;
    }
  else
    delete(x.next);
}


/*

[ H1(x) ::= x::node2<v,p,n'>@M * HP_796(p,n')&true,

 HP_796(p,n')::= HP_594(p) * n'::node2<v1',p4,n4>@M * HP_605(p4)&n4=null
 or HP_594(p) * n'::node2<v1',p2,n2>@M * HP_605(p2)	   & n2!=null
 or HP_594(p) * n'::node2<v1',p1',n1'>@M * HP_605(p1') & n1'=null
 or HP_594(p) * n'::node2<v1',p1',n1'>@M * HP_605(p1') & n1'!=null
 or HP_594(p) * n'::node2<v,p3,n3>@M * HP_796(p3,n3)
 or HP_594(p) & n'=null
 ]




[ G1(x_637) ::= x_637::node2<val_26_568,prev_26_569,next_28_544'>@M * HP_638(prev_26_569,next_28_544')&true,
 H1(x_643) ::= 
    x_643::node2<val_26_533',prev_26_534',next_26_535'>@M *HP_559(prev_26_534') *
         next_26_535'::node2<val_26_537',prev_26_634,next_26_633>@M *  HP_570(prev_26_634)&next_26_633=null
 or x_643::node2<val_26_533',prev_26_534',next_26_535'>@M * HP_559(prev_26_534') *
         next_26_535'::node2<val_26_537',prev_26_634,next_26_633>@M * HP_570(prev_26_634)&next_26_633!=null
 or next_26_535'::node2<val_26_537',prev_26_634,next_26_633>@M * HP_570(prev_26_634) *
          x_643::node2<val_26_533',prev_26_534',next_26_535'>@M * HP_559(prev_26_534')&true
 or HP_638(prev_26_569,next_28_544')&true
 ,
 HP_638(prev_26_569,next_28_544') ::= 
 HP_559(prev_26_569) * next_28_544'::node2<val_26_568,prev_26_639,next_28_640>@M * HP_638(prev_26_639,next_28_640)&true
 or HP_559(prev_26_569)&next_28_544'=null
 ]
*************************************



*/