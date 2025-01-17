/*
  Example with simple CountDownLatch
 */

//CountDownLatch
data CDL{
}

data cell{
  int val;
}

pred_prim LatchIn{-%P@Split}<>;

pred_prim LatchOut{+%P@Split}<>;

pred_prim CNT<n:int>
inv n>=(-1);

//lemma_split "split" self::CNT<n> & a>=0 & b>=0 & n=a+b -> self::CNT<a> * self::CNT<b>;

lemma "combine" self::CNT<a> * self::CNT<b> & a,b>=0 -> self::CNT<a+b>;

/********************************************/
CDL create_latch(int n) with %P
  requires n>0
  ensures res::LatchIn{-%P}<> * res::LatchOut{+%P}<> * res::CNT<n>;
  requires n=0
  ensures res::CNT<(-1)>;

void countDown(CDL c)
  requires c::LatchIn{-%P}<> * %P * c::CNT<n> & n>0
  ensures c::CNT<n-1>;
  requires c::CNT<(-1)> 
  ensures c::CNT<(-1)>;

void await(CDL c)
  requires c::LatchOut{+%P}<> * c::CNT<0>
  ensures c::CNT<(-1)> * %P;
  requires c::CNT<(-1)>
  ensures c::CNT<(-1)> * %P;
  
void main()
  requires emp ensures emp;
{
  cell x, y;
  CDL c = create_latch(1) with x::cell<1> ;
  int r1;
  r1=0;
  x = new cell(1); 
  dprint;
  par
  {  
   // exists r1',r2'
   case c'::LatchIn{- x::cell<1>}<> * c'::CNT<(1)> -> 
      dprint;
      countDown(c);
      dprint;
      //int k = x.val;
  || 
    // exists x',y',r2'
    case c'::LatchOut{+ x::cell<1>}<> * c'::CNT<0> & @full[r1] ->
      await(c); 
      r1 = x.val; 
  }
  dprint;
}


/*
# ex4c1.ss --ann-vp

  Note that varperm @full[x] is not transferred
  into the latch.

  However @full[r1] is required at the thread which needs to update r1.



*/
