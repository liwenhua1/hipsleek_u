Starting Reduce... 
Starting Omega...oc
Entail  (1): Valid. 
Inferred Heap:[]
Inferred Pure:[ !(n=0 & y=null), n=1]
<1>EXISTS(q_50,flted_7_48: q_50::ll<flted_7_48>@M[Orig] & flted_7_48+1=n & 
n=1 &
{FLOW,(17,18)=__norm})


Entail  (2): Valid. 
Inferred Heap:[]
Inferred Pure:[ n!=0, n=1]
<1>EXISTS(q_80,flted_7_78: q_80::ll<flted_7_78>@M[Orig] & flted_7_78+1=n & 
n=1 &
{FLOW,(17,18)=__norm})


Entail  (3): Valid. 
Inferred Heap:[]
Inferred Pure:[ n!=0]
<1>EXISTS(flted_7_104: b::ll<flted_7_104>@M[Orig] & flted_7_104+1=n &
{FLOW,(17,18)=__norm})


Entail  (4): Valid. 
Inferred Heap:[]
Inferred Pure:[ n=0]
<1>true & y=null & n=0 &
{FLOW,(17,18)=__norm}


Entail  (5): Valid. 
Inferred Heap:[]
Inferred Pure:[ n!=1]
<1>false & false &
{FLOW,(17,18)=__norm}


Entail  (6): Valid. 
Inferred Heap:[]
Inferred Pure:[ n!=1]
<1>false & false &
{FLOW,(17,18)=__norm}


Entail  (7): Valid. 
Inferred Heap:[]
Inferred Pure:[ 4<=n]
<1>true & 0<n & m<n & 4<=n &
{FLOW,(17,18)=__norm}


Entail  (8): Valid. 
Inferred Heap:[]
Inferred Pure:[ 9<=n]
<1>true & 0<n & m<n & 4<m & 9<=n &
{FLOW,(17,18)=__norm}


Entail  (9): Valid. 
Inferred Heap:[]
Inferred Pure:[ 1>n]
<1>false & false &
{FLOW,(17,18)=__norm}


Entail  (10): Valid. 
Inferred Heap:[]
Inferred Pure:[ !(m<n & 1<=n)]
<1>false & false &
{FLOW,(17,18)=__norm}


Entail  (11): Fail.(must) cause:(failure_code=213)  true |-  n=2 & n=1 (RHS: contradiction).
<1>true & true &
{FLOW,(1,2)=__Error}


Entail  (12): Valid. 
Inferred Heap:[]
Inferred Pure:[ !(m=2 & 1<=n)]
<1>false & false &
{FLOW,(17,18)=__norm}


Entail  (13): Fail.(may) cause:(failure_code=213)  4<=p & 2<m & a=p |-  m<a (may-bug).

Entail  (14): Fail.(may) cause:(failure_code=213)  2<m & 6<=p |-  4<m;  2<m & 6<=p |-  m<p (may-bug).

Entail  (15): Fail.(may) cause:(failure_code=213)  2<m & 5<=m |-  m<p (may-bug).

Entail  (16): Valid. 
Inferred Heap:[]
Inferred Pure:[ 5<=m & m<p]
<1>true & 2<m & 5<=m & m<p &
{FLOW,(17,18)=__norm}


Stop Omega... 235 invocations 