//relation f_pre(int n).
//relation f_post(int n, int r).

int fact(int x)
  infer [@pre_n,x,@term,@post_n]
  requires true  
  ensures true;
{
  if (x==0) return 1;
  else return 1 + fact(x - 1);
}

/*
# fact1.ss

Need to support a mix of
infer_consts @sym and varid.
Thus, the need for twoAns type

*/