/* singly linked lists */

/* representation of a node */

data node{
	int val; 
	node next;	
}

ll<R> == R = {}
	or self::node<_,p> * p::ll<Rp> //& R = union(Rp,{self})
	inv true
	memE R->();
	//memE R->(node<@M,@M>);

lseg<R,p> == self = p //& R = {}
	or self::node<_,q> * q::lseg<Rq,p> //& R = union(Rq,{self})
	inv true
	memE R->();
	//memE R->(node<@M,@M>);

lemma x::node<_,p> -* self::ll<R>  & x in R -> self::lseg<R1,x> * p::ll<R2> & R = union(R1,R2,{x});

global node cached;
global node q;

void delete_cache(ref node cached, node q)
requires  cached::node<_,p> U* q::ll<M> & cached in M
ensures q::lseg<M1,cached> * p::ll<M2> & M = union(M1,M2,{cached}) & cached' = null; 
{
	delete(cached);
} 

void delete(ref node cached)
requires cached::node<_,_>
ensures cached' = null;
{
cached = null;
}

node add_L(node x, node y)
requires x::node<_,_> * y::ll<Ry>
ensures res::ll<R> & R = union(Ry,{x});
{
  x.next = y;
  return x;
}

node find_L(node q, int k)
requires q::ll<Rq>
ensures res::node<k,_ > * q::ll<Rq>;
requires q::ll<Rq>
ensures q::ll<Rq> & res = q;


void caching(node x, ref node cached)
requires x::node<v,_@A> * cached::node<_,_>
ensures x::node<v,_@A> * cached'::node<v,_>;
{
 cached.val = x.val;
}

void add_in(int key, ref node cached, node q) 
/*
requires cached::node<_,_> & q::ll<R> 
ensures  cached'::node<_,_> & q::ll<R>;
*/
requires cached::node<_,_> U* q::ll<R> 
ensures  cached'::node<key,_> U* q::ll<R1>;
{
  node x,tmp;
  //tmp = find_L(q,key);
  //if(tmp == q || tmp.val != key) {
    x = new node(0,null);
    x.val = key;
    caching(x,cached);
    q = add_L(x,q);
    //x.next = q;
    //dprint;
  //}
}

node find(int key, ref node cached, node q, int flag) 
/*
requires q::ll<Rq> & cached::node<_,_>
ensures  q::lseg<R1,res> * res::node<key,q2> * q2::ll<R2> & cached'::node<key,_> & Rq = union(R1,R2,{res});
*/

requires q::ll<Rq> U* cached::node<k,_> & key = k
ensures  q::ll<Rq> U* cached::node<k,_> & res = cached;

requires q::ll<Rq> U* cached::node<k,_> & key != k & flag != 1
ensures res::node<key,_> * q::ll<Rq> U* cached'::node<_,_>;

requires q::ll<Rq> U* cached::node<k,_> & key != k & flag = 1
ensures res::node<key,_> * q::ll<Rq> U* cached'::node<_,_> ;

/*
requires q::ll<Rq> & cached::node<k,_> & key != k
ensures q::ll<Rq> & cached::node<k,_> & res = q;
*/
{
  node tmp, cache;
  if(cached != null) {
    cache = cached;
    if(cache.val == key) return cache;
  }
  tmp = find_L(q,key);
  if(tmp != q) {
    if(flag==1) { caching(tmp, cached);}
    return tmp;
  }
  return tmp;
}
