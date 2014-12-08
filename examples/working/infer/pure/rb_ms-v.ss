/* red black trees */

data node {
	int val;
	int color; /*  0 for black, 1 for red */
	node left;
	node right;
}

/* view for red-black trees */
//memory safety + size
rb2<n, cl> == self = null & n=0 & cl = 0
	or self::node<v, 1, l, r> * l::rb2<nl, 0> * r::rb2<nr, 0> & cl = 1 & n = 1 + nl + nr
	or self::node<v, 0, l, r> * l::rb2<nl, _> * r::rb2<nr, _> & cl = 0 & n = 1 + nl + nr
	inv n >= 0 & 0 <= cl <= 1;

/* rotation case 3 */
node rotate_case_3(node a, node b, node c)
  requires a::rb2<na, 1> * b::rb2<nb, 0> * c::rb2<nc, 0> & a!=null
  ensures res::rb2<na + nb + nc + 2, 0>;
{
	node tmp;

	tmp = new node(0, 1, b, c);

	return new node(0, 0, a, tmp);
}


/* rotation to transform case 2 in case 3, then apply case 3 */
node case_2(node a, node b, node c, node d)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0> * d::rb2<nd, 0>
  ensures res::rb2<na + nb + nc + nd + 3, 0> & res!=null;
{
	node tmp;

	tmp = new node(0, 1, a, b);

	return rotate_case_3(tmp, c, d);
}

/* RIGHT */
/* rotation case 3 */
node rotate_case_3r(node a, node b, node c)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 1> & c!=null
  ensures res::rb2<na + nb + nc + 2, 0>;
{
	node tmp;

	tmp = new node(0, 1, a, b);

	return new node(0, 0, tmp, c);
}

/* rotation to transform case 2 in case 3, then apply case 3 */
node case_2r(node a, node b, node c, node d)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0> * d::rb2<nd, 0>
  ensures res::rb2<na + nb + nc + nd + 3, 0>;
{
	node tmp;

	tmp = new node(0, 1, c, d);

	return rotate_case_3r(a, b, tmp);
}

/* function to check if a node is red */
bool is_red(node x)
  requires x::rb2<n, cl>
  ensures x::rb2<n, cl> & cl = 1 & res
  or x::rb2<n, cl> & cl = 0 & !res;
{
	if (x == null)
		return false;
	else
		if (x.color == 0)
			return false;
		else
			return true;
}


/* function to check if a node is black */
bool is_black(node x)
  requires x::rb2<n, cl>
   ensures x::rb2<n, cl> & cl = 1 & !res
  or x::rb2<n, cl> & cl = 0 & res;
{
	if (x == null)
		return true;
	else
		if (x.color == 0)
			return true;
		else
			return false;
}

/* function for case 6 delete (simple rotation) */
node del_6(node a, node b, node c, int color)
  requires a::rb2<na , 0> * b::rb2<nb, _> * c::rb2<nc, 1> & color = 0 & c!=null or
  a::rb2<na , 0> * b::rb2<nb, _> * c::rb2<nc, 1> & color = 1 & c!=null
  ensures res::rb2<na + nb + nc + 2, 0> & color = 0 or
  res::rb2<na + nb + nc + 2, 1> & color = 1;
{
	node tmp;

	c.color = 0;
	tmp = new node(0, 0, a, b);

	return new node(0, color, tmp, c);
}

/* function for case 6 at delete (simple rotation) - when is right child */
node del_6r(node a, node b, node c, int color)
  requires a::rb2<na , 1> * b::rb2<nb, _> * c::rb2<nc, 0> & color = 0 & null!=a or
  a::rb2<na , 1> * b::rb2<nb, _> * c::rb2<nc, 0> & color = 1 & null!=a
  ensures res::rb2<na + nb + nc + 2, 0> & color = 0 or
  res::rb2<na + nb + nc + 2, 1> & color = 1;
{
	node tmp;

	a.color = 0;
	tmp = new node(0, 0, b, c);

	return new node(0, color, a, tmp);
}

/* function for case 5 (double rotation) */
node del_5(node a, node b, node c, node d, int color)
  requires a::rb2<na , 0> * b::rb2<nb, 0> * c::rb2<nc, 0> * d::rb2<nd, 0> & color = 0 or
  a::rb2<na , 0> * b::rb2<nb, 0> * c::rb2<nc, 0> * d::rb2<nd, 0> & color = 1
  ensures res::rb2<na + nb + nc + nd + 3, 0> & color = 0 or
  res::rb2<na + nb + nc + nd + 3, 1> & color = 1;
{
	node tmp;

	tmp = new node(0, 1, c, d);

	return del_6(a, b, tmp, color);
}

/* function for case 5(double rotation) - right child */
node del_5r(node a, node b, node c, node d, int color)
  requires a::rb2<na , 0> * b::rb2<nb, 0> * c::rb2<nc, 0> * d::rb2<nd, 0> & color = 0 or
  a::rb2<na , 0> * b::rb2<nb, 0> * c::rb2<nc, 0> * d::rb2<nd, 0> & color = 1
  ensures res::rb2<na + nb + nc + nd + 3, 0> & color = 0 or
  res::rb2<na + nb + nc + nd + 3, 1> & color = 1;
{
	node tmp;

	tmp = new node(0, 1, a, b);
	return del_6r(tmp, c, d, color);
}

/* function for case 4(just recolor) */
node del_4(node a, node b, node c)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0>
  ensures res::rb2<na + nb + nc + 2, 0>;
{
	node tmp1,tmp2;
	tmp1 = new node(0, 1, b, c);
    tmp2 = new node(0, 0, a, tmp1);
	return tmp2;
}

/* function for case 4 (just recolor) - right child */
node del_4r(node a, node b, node c)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0>
  ensures res::rb2<na + nb + nc + 2, 0>;
{
	node tmp;

	tmp = new node(0, 1, a, b);

	return new node(0, 0, tmp, c);
}

/* function for case 3 (just recolor) */
node del_3(node a, node b, node c)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0>
  ensures res::rb2<na + nb + nc + 2, 0>;
{
	node tmp;

	tmp = new node(0, 1, b, c);

	return new node(0, 0, a, tmp);
}

/* function for case 3 (just recolor) - right child */
node del_3r(node a, node b, node c)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0>
  ensures res::rb2<na + nb + nc + 2, 0>;
{
	node tmp;

	tmp = new node(0, 1, a, b);

	return new node(0, 0, tmp, c);
}

/* function for case 2 (simple rotation + applying one of the cases 4, 5, 6) */
node del_2(node a, node b, node c)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0> & b != null
  ensures res::rb2<na+nb+nc+2, 0>;
{
	node tmp;

	if (is_black(b.right))
	{
		if (is_black(b.left))
			tmp = del_4(a, b.left, b.right);
		else
			tmp = del_5(a, b.left.left, b.left.right, b.right, 1);
	}
	else
		tmp = del_6(a, b.left, b.right, 1);
    //dprint;
	return new node(0, 0, tmp, c);
}


/************** it can assert that a'::rb<na, 0, h> & a'::rb<na, 0, h+1> and even that a'::rb<na + 5, 0, h> or a'::rb<nb, 0, h> */

/* function for case 2 (simple rotation + applying one of the cases 4, 5, 6) - right child*/
node del_2r(node a, node b, node c)
  requires a::rb2<na, 0> * b::rb2<nb, 0> * c::rb2<nc, 0> & b != null
  ensures res::rb2<na+nb+nc+2, 0>;
{
	node tmp, f;

	if (is_black(b.left))
	{
		if (is_black(b.right))
			tmp = del_4r(b.left, b.right, c);
		else
			tmp = del_5r(b.left, b.right.left, b.right.right, c, 1);
	}
	else
		tmp = del_6r(b.left, b.right, c, 1);
	//assert tmp'::rb<nb+nc+1, _, ha> & h=ha;
	assert a'::rb2<n_1, 0> & n_1=nb;
	assert a'::rb2<n_2, 0> & n_2=na;
	f = new node(0, 0, a, tmp);
	//assert f'::rb<_,_,_>;
	return f;
}


/* not working, waiting for all the others to work to check the pbs*/
/* primitive for the black height */
int bh(node x) requires true ensures false;
/*
int bh(node x)
  requires x::rb<n,cl,bh>
  ensures x::rb<n,cl,bh> & res=bh;
*/
/* function to delete the smalles element in a rb and then rebalance */
int remove_min(ref node x)
  requires x::rb2<n, cl> & x != null & 0 <= cl <= 1
  ensures x'::rb2<n-1, cl2> & cl = 1 & 0 <= cl2 <= 1
		or x'::rb2<n-1, 0> & cl = 0;
{
	int v1;

	if (x.left == null)
	{
		int tmp = x.val;

		if (is_red(x.right))
          x.right.color = 0;
		x = x.right;

		return tmp;
	}
	else
	{
		v1 = remove_min(x.left);

		//rebalance
		if (bh(x.left) < bh(x.right))
		{
          if (is_black(x.left))
			{
              if (is_red(x.right))
				{
                  if (x.right.left != null)
                    {
                      x = del_2(x.left, x.right.left, x.right.right);
                      return v1;
                    }
                  else
                    return v1;
				}
              else
                {
                  if (is_black(x.right.right))
					{
                      if (is_black(x.right.left))
                        if (x.color == 0)
                          {
                            x = del_3(x.left, x.right.left, x.right.right);
                            return v1;
                          }
                        else
                          {
                            x = del_4(x.left, x.right.left, x.right.right);
                            return v1;
                          }
                      else
						{
                          x = del_5(x.left, x.right.left.left, x.right.left.right, x.right.right, x.color);
                          return v1;
						}
					}
                  else
					{
                      x = del_6(x.left, x.right.left, x.right.right, x.color);
                      return v1;
					}
				}
			}
			else
				return v1;
		}
		else
			return v1;
	}
}

/* function to delete an element in a red black tree */
//relation DEL1(int a, int b).
//relation DEL2(int a, int b).
//relation DEL3(int a, int b).
void del(ref node  x, int a)
//infer[DEL1,DEL2,DEL3]
  requires x::rb2<n, cl> & 0 <= cl <= 1
  ensures  x'::rb2<n1, cl2> & cl = 1 & 0 <= cl2 <= 1 & n1=n-1//DEL1(n,n1)//'n1=n-1
  or x'::rb2<n2, 0> & cl = 0 & n2=n-1//DEL2(n,n2)//'n2=n-1
  or x'::rb2<n3, cl> & n3=n;//DEL3(n,n3); //'n3=n
/*
!!! REL :  DEL2(n,n2)
!!! POST:  n2>=0 & (n2+1)>=n & n>=n2
!!! PRE :  0<=n
!!! REL :  DEL1(n,n1)
!!! POST:  n>=1 & n=n1+1
!!! PRE :  1<=n
!!! REL :  DEL3(n,n3)
!!! POST:  n3>=0 & (n3+1)>=n & n>=n3
!!! PRE :  0<=n
 */
{
	int v;

    assert false;if (x!=null)
    {  assert false;
      if (x.val == a) // delete x
        {
          if (x.right == null)
			{
              if (is_red(x.left))
                x.left.color = 0;
              x = x.left;
			}
			else
			{
              v = remove_min(x.right);
              if (bh(x.right) < bh(x.left))
				{
                  if (is_black(x.right))
					{
                      if (is_red(x.left))
						{
                          if (x.left.right != null)
                            x = del_2r(x.left.left, x.left.right, x.right);
						}
                      else
						{
                          if (is_black(x.left.left))
                            if (is_black(x.left.right))
                              if (x.color == 0)
                                x = del_3r(x.left.left, x.left.right, x.right);
                              else
                                x = del_4r(x.left.left, x.left.right, x.right);
                            else
                              x = del_5r(x.left.left, x.left.right.left, x.left.right.right, x.right, x.color);
                          else
                            x = del_6r(x.left.left, x.left.right, x.right, x.color);
						}
					}
				}
			}
		}
		else
		{
          if (x.val < a) //go right
			{
              del(x.right, a);

              // rebalance
              if (bh(x.right) < bh(x.left))
				{
                  if (is_black(x.right))
                    if (is_red(x.left))
                      {
                        if (x.left.right != null)
                          x = del_2r(x.left.left, x.left.right, x.right);
                      }
                    else
                      {
                        if (is_black(x.left.left))
                          if (is_black(x.left.right))
                            if (x.color == 0)
                              x = del_3r(x.left.left, x.left.right, x.right);
                            else
                              x = del_4r(x.left.left, x.left.right, x.right);
                          else
                            x = del_5r(x.left.left, x.left.right.left, x.left.right.right, x.right, x.color);
							else
                              x = del_6r(x.left.left, x.left.right, x.right, x.color);
                      }
				}
			}
          else   // go left
			{
              del(x.left, a);
              // rebalance
              if (bh(x.left) < bh(x.right))
				{
                  if (is_black(x.left))
                    if (is_red(x.right))
                      {
                        if (x.right.left != null)
                          x = del_2(x.left, x.right.left, x.right.right);
                      }
                    else
                      {
                        if (is_black(x.right.right))
                          if (is_black(x.right.left))
                            {
                              if (x.color == 0)
                                x = del_3(x.left, x.right.left, x.right.right);
                              else
                                x = del_4(x.left, x.right.left, x.right.right);
                            }
                          else
                            x = del_5(x.left, x.right.left.left, x.right.left.right, x.right.right, x.color);
                        else
                          x = del_6(x.left, x.right.left, x.right.right, x.color);
                      }
				}
			}
		}
	}
}

node node_error() requires true ensures false;

//relation INS(int a, int b).
node insert(node x, int v)
//infer[INS]
  requires x::rb2<n, _>
  ensures res::rb2<n1, _> & res != null & n1=n+1;//INS(n,n1);//
/*
!!! REL :  INS(n,n1)
!!! POST:  0=n & 1=n1
!!! PRE :  n=0
 */
{
	node tmp, tmp_null = null;

	if (x == null)

      return new node(v, 1, tmp_null, tmp_null);
	else
	{
      if (v <= x.val)
		{ // left
          tmp = x.left;
          x.left = insert(tmp, v);
          // rebalance
          if (x.color == 0)
			{
              if (is_red(x.left))
				{
                  if (is_red(x.left.left))
					{
                      if (is_red(x.right))
						{
                          x.left.color = 0;
                          x.right.color = 0;
                          return x;
						}
                      else
						{
                          x = rotate_case_3(x.left.left, x.left.right, x.right);
                          return x;
						}
					}
                  else
					{
                      if (is_red(x.left.right))
						{
                          if (is_red(x.right))
							{
                              x.left.color = 0;
                              x.right.color = 0;
                              return x;
							}
                          else
							{
                              x = case_2(x.left.left, x.left.right.left, x.left.right.right, x.right);
                              return x;
							}
						}
                      else
                        return node_error();
					}
				}
              else
                return node_error();
			}
          else
            return node_error();
		}
		else
          { // right
			tmp = x.right;
			x.right = insert(tmp, v);

			// rebalance
			if (x.color == 0)
			{
              if (is_red(x.right))
				{
                  if (is_red(x.right.left))
                    if (is_red(x.left))
                      {
                        x.left.color = 0;
                        x.right.color = 0;
                        return x;
                      }
                    else
                      {
                        x = case_2r(x.left, x.right.left.left, x.right.left.right, x.right.right);
                        return x;
                      }
                  else
					{
                      if (is_red(x.right.right))
                        if (is_red(x.left))
                          {
                            x.left.color = 0;
                            x.right.color = 0;
                            return x;
                          }
                        else
                          {
                            x = rotate_case_3r(x.left, x.right.left, x.right.right);
                            return x;
                          }
                      else
                        return node_error();
					}
				}
              else
                return node_error();
			}
			else
              return node_error();
          }
	}
}
/****************************************************************************/
