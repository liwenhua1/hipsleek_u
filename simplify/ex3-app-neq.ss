data node {
	int val;
	node next;
}

ll<n> == self=null & n=0
	or self::node<_, q> * q::ll<n-1>
	inv n>=0;


void foo(node xxx, node yyyy)
  requires xxx::ll<nnn> & nnn>0
  ensures xxx::ll<nnn>;
{
  // dprint;
	node tmpZZZ = xxx.next;
	bool fl_bb = tmpZZZ != yyyy;
	if (fl_bb) {
                dprint;
		return;
	}
	else {
		return;
	}
}

/*
# ex3-app-new.ss

!!! **cfout.ml#423:important variables:[fl_47,tmp_46,nnn,xxx,yyyy,xxx',Anon_1507,q_1508,flted_7_1506]
!!! **cfout.ml#425:exists variables:[fl_47',yyyy',tmp_46']


 why tmp renamed to tmp_46?
 why fl_bb renamed to fl_47?

(i) should not be any renaming
(ii) should be from tmp -> tmp_46 and fl_bb --> fl_bb_47

void foo$node~node(  node xxx,  node yyyy)static  EBase exists (Expl)[](Impl)[nnn](ex)[]xxx::ll{}<nnn>&0<nnn&
       {FLOW,(4,5)=__norm#E}[]
         EBase emp&MayLoop[]&{FLOW,(4,5)=__norm#E}[]
                 EAssume 
                   (exists nnn_44: xxx::ll{}<nnn_44>&nnn_44=nnn&
                   {FLOW,(4,5)=__norm#E}[]
                   
dynamic  EBase hfalse&false&{FLOW,(4,5)=__norm#E}[]
{(((node tmp_46;
tmp_46 = bind xxx to (val_16_1467,next_16_1468) [read] in 
next_16_1468);
(boolean fl_47;
fl_47 = {neq___$node~node(tmp_46,yyyy)}));
if (fl_47) [LABEL! 100,0: {(dprint;
ret#)}]
else [LABEL! 100,1: {ret#}]
)}

===========================================


{(11,0),(0,-1)}

Successful States:
[
 Label: [(,0 ); (,1 )]
 State:xxx'::node<Anon_1507,q_1508> * q_1508::ll{}<flted_7_1506>
 & fl_47' & tmp_46'!=yyyy' & 0<nnn & yyyy'=yyyy 
 & xxx'=xxx & flted_7_1506+1=nnn & tmp_46'=q_1508
&{FLOW,(4,5)=__norm#E}[]

 ]

dprint after: ex3-app-neq.ss:19: ctx:  List of Failesc Context: [FEC(0, 0, 1  [(,0 ); (,1 )])]

Successful States:
[
 Label: [(,0 ); (,1 )]
 State:xxx'::node<Anon_1507,q_1508> * q_1508::ll{}<flted_7_1506>
 &xxx=xxx' & nnn=1+flted_7_1506 & 0<=flted_7_1506 
 & yyyy!=q_1508
 &{FLOW,(4,5)=__norm#E}[]


*/