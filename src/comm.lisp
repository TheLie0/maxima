;;; -*-  Mode: Lisp; Package: Maxima; Syntax: Common-Lisp; Base: 10 -*- ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     The data in this file contains enhancments.                    ;;;;;
;;;                                                                    ;;;;;
;;;  Copyright (c) 1984,1987 by William Schelter,University of Texas   ;;;;;
;;;     All rights reserved                                            ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :maxima)

;;	** (c) Copyright 1982 Massachusetts Institute of Technology **

(macsyma-module comm)

(declare-top (special $exptsubst $linechar $nolabels $inflag $piece $dispflag
		      $gradefs $props $dependencies derivflag derivlist
		      $linenum $partswitch linelable nn* dn* islinp
		      $powerdisp atvars atp $errexp $derivsubst $dotdistrib
		      $opsubst $subnumsimp $transrun in-p substp $sqrtdispflag
		      $pfeformat dummy-variable-operators))

;; op and opr properties

(mapc #'(lambda (x) (putprop (car x) (cadr x) 'op) (putprop (cadr x) (car x) 'opr))
      '((mplus &+) (mminus &-) (mtimes &*) (mexpt &**) (mexpt &^)
	(mnctimes |&.|) (rat &//) (mquotient &//) (mncexpt &^^)
	(mequal &=) (mgreaterp &>) (mlessp &<) (mleqp &<=) (mgeqp &>=)
	(mnotequal |&#|) (mand &and) (mor &or) (mnot &not) (msetq |&:|)
	(mdefine |&:=|) (mdefmacro |&::=|) (mquote |&'|) (mlist &[)
	(mset |&::|) (mfactorial &!) (marrow &->) (mprogn |&(|)
	(mcond &if)))

(mapc #'(lambda (x) (putprop (car x) (cadr x) 'op))
      '((mqapply $subvar) (bigfloat $bfloat)))

(mapc #'(lambda (x) (putprop (car x) (cadr x) 'opr))
      '((|&and| mand) (|&or| mor) (|&not| mnot) (|&if| mcond)))


(setq $exptsubst nil
      $partswitch nil
      $inflag nil
      $gradefs '((mlist simp))
      $dependencies '((mlist simp))
      atvars '(&@1 &@2 &@3 &@4)
      atp nil
      islinp nil
      lnorecurse nil
      &** '&^
      $derivsubst nil
      timesp nil
      $opsubst t
      in-p nil
      substp nil)

(defmvar $vect_cross nil
  "If TRUE allows DIFF(X~Y,T) to work where ~ is defined in
	  SHARE;VECT where VECT_CROSS is set to TRUE.")


(defmfun $substitute (old new &optional (expr nil three-arg?))
  (cond (three-arg? (maxima-substitute old new expr))
	(t
	 (let ((l old) (z new))
	   (cond ((and ($listp l) ($listp (cadr l)) (null (cddr l)))
		  ($substitute (cadr l) z))
		 ((notloreq l) (improper-arg-err l '$substitute))
		 ((eq (caar l) 'mequal) (maxima-substitute (caddr l) (cadr l) z))
		 (t (do ((l (cdr l) (cdr l)))
			((null l) z)
		      (setq z ($substitute (car l) z)))))))))

(declare-top (special x y oprx opry negxpty timesp))

(defmfun maxima-substitute (x y z) ; The args to SUBSTITUTE are assumed to be simplified.
  (declare (special x y ))
  (let ((in-p t) (substp t))
    (if (and (mnump y) (= (signum1 y) 1))
	(let ($sqrtdispflag ($pfeformat t)) (setq z (nformat-all z))))
    (simplifya
     (if (atom y)
	 (cond ((equal y -1)
		(setq y '((mminus) 1)) (subst2 (nformat-all z)))
	       (t
		(cond ((and (not (symbolp x))
			    (functionp x))
		       (let ((tem (gensym)))
			 (setf (get  tem  'operators) 'application-operator)
			 (setf (symbol-function tem) x)
			 (setq x tem))))
		(let ((oprx (getopr x)) (opry (getopr y)))
		  (declare (special oprx opry ))
		  (subst1 z))))
	 (let ((negxpty (if (and (eq (caar y) 'mexpt)
				 (= (signum1 (caddr y)) 1))
			    (mul2 -1 (caddr y))))
	       (timesp (if (eq (caar y) 'mtimes) (setq y (nformat y)))))
	   (declare (special negxpty timesp))
	   (subst2 z)))
     nil)))

;;Remainder of page is update from F302 --gsb

;;Used only in COMM2 (AT), and below.
(defvar dummy-variable-operators '(%product %sum %laplace %integrate %limit %at))

(defun subst1 (z)			; Y is an atom
  (cond ((atom z) (if (equal y z) x z))
	((specrepp z) (subst1 (specdisrep z)))
	((eq (caar z) 'bigfloat) z)
	((and (eq (caar z) 'rat) (or (equal y (cadr z)) (equal y (caddr z))))
	 (div (subst1 (cadr z)) (subst1 (caddr z))))
	((at-substp z) z)
	((and (eq y t) (eq (caar z) 'mcond))
	 (list (cons (caar z) nil) (subst1 (cadr z)) (subst1 (caddr z))
	       (cadddr z) (subst1 (car (cddddr z)))))
	(t (let ((margs (mapcar #'subst1 (cdr z))))
	     (if (and $opsubst
		      (or (eq opry (caar z))
			  (and (eq (caar z) 'rat) (eq opry 'mquotient))))
		 (if (or (numberp x)
			 (member x '(t nil $%e $%pi $%i) :test #'eq)
			 (and (not (atom x))
			      (not (or (eq (car x) 'lambda)
				       (eq (caar x) 'lambda)))))
		     (if (or (and (member 'array (cdar z) :test #'eq)
				  (or (and (mnump x) $subnumsimp)
				      (and (not (mnump x)) (not (atom x)))))
			     ($subvarp x))
			 (let ((substp 'mqapply))
			   (subst0 (list* '(mqapply) x margs) z))
			 (merror "Attempt to MAXIMA-SUBSTITUTE ~M for ~M in ~M~
			   ~%Illegal substitution for operator of expression" x y z))
		     (subst0 (cons (cons oprx nil) margs) z))
		 (subst0 (cons (cons (caar z) nil) margs) z))))))

(defun subst2 (z)
  (let (newexpt)
    (cond ((atom z) z)
	  ((specrepp z) (subst2 (specdisrep z)))
	  ((and atp (member (caar z) '(%derivative %laplace) :test #'eq)) z)
	  ((at-substp z) z)
	  ((alike1 y z) x)
	  ((and timesp (eq (caar z) 'mtimes) (alike1 y (setq z (nformat z)))) x)
	  ((and (eq (caar y) 'mexpt) (eq (caar z) 'mexpt) (alike1 (cadr y) (cadr z))
		(setq newexpt (cond ((alike1 negxpty (caddr z)) -1)
				    ($exptsubst (expthack (caddr y) (caddr z))))))
	   (list '(mexpt) x newexpt))
	  ((and $derivsubst (eq (caar y) '%derivative) (eq (caar z) '%derivative)
		(alike1 (cadr y) (cadr z)))
	   (let ((tail (subst-diff-match (cddr y) (cdr z))))
	     (cond ((null tail) z)
		   (t (cons (cons (caar z) nil) (cons x (cdr tail)))))))
	  (t (recur-apply #'subst2 z)))))

(declare-top (unspecial x y oprx opry negxpty timesp))

(defmfun subst0 (new old)
  (cond ((atom new) new)
	((alike (cdr new) (cdr old))
	 (cond ((eq (caar new) (caar old)) old)
	       (t (simplifya (cons (cons (caar new) (member 'array (cdar old) :test #'eq)) (cdr old))
			     nil))))
	((member 'array (cdar old) :test #'eq)
	 (simplifya (cons (cons (caar new) '(array)) (cdr new)) nil))
	(t (simplifya new nil))))

(defun expthack (y z)
  (prog (nn* dn* yn yd zn zd qd)
     (cond ((and (mnump y) (mnump z))
	    (return (if (numberp (setq y (div* z y))) y)))
	   ((atom z) (if (not (mnump y)) (return nil)))
	   ((or (ratnump z) (eq (caar z) 'mplus)) (return nil)))
     (numden y)				; (CSIMP) sets NN* and DN*
     (setq yn nn* yd dn*)
     (numden z)
     (setq zn nn* zd dn*)
     (setq qd (cond ((and (equal zd 1) (equal yd 1)) 1)
		    ((prog2 (numden (div* zd yd))
			 (and (equal dn* 1) (equal nn* 1)))
		     1)
		    ((equal nn* 1) (div* 1 dn*))
		    ((equal dn* 1) nn*)
		    (t (return nil))))
     (numden (div* zn yn))
     (if (equal dn* 1) (return (div* nn* qd)))))

(defun subst-diff-match (l1 l2)
  (do ((l l1 (cddr l)) (l2 (copy-list l2)) (failed nil nil))
      ((null l) l2)
    (do ((l2 l2 (cddr l2)))
	((null (cdr l2)) (setq failed t))
      (if (alike1 (car l) (cadr l2))
	  (if (and (fixnump (cadr l)) (fixnump (caddr l2)))
	      (cond ((< (cadr l) (caddr l2))
		     (return (rplacd (cdr l2)
				     (cons (- (caddr l2) (cadr l))
					   (cdddr l2)))))
		    ((= (cadr l) (caddr l2))
		     (return (rplacd l2 (cdddr l2))))
		    (t (return (setq failed t))))
	      (return (setq failed t)))))
    (if failed (return nil))))

;;This probably should be a subst or macro.
(defun at-substp (z)
  (and atp (or (member (caar z) '(%derivative %del) :test #'eq)
	       (member (caar z) dummy-variable-operators :test #'eq))))
(defmfun recur-apply (fun e)
  (cond ((eq (caar e) 'bigfloat) e)
	((specrepp e) (funcall fun (specdisrep e)))
	(t (let ((newargs (mapcar fun (cdr e))))
	     (if (alike newargs (cdr e))
		 e
		 (simplifya (cons (cons (caar e) (member 'array (cdar e) :test #'eq)) newargs)
			    nil))))))

(defmfun $depends n
  (if (oddp n) (merror "`depends' takes an even number of arguments."))
  (do ((i 1 (+ i 2)) (l))
      ((> i n) (i-$dependencies (nreverse l)))
    (cond (($listp (arg i))
	   (do ((l1 (cdr (arg i)) (cdr l1))) ((null l1))
	     (setq l (cons (depends1 (car l1) (arg (1+ i))) l))))
	  (t (setq l (cons (depends1 (arg i) (arg (1+ i))) l))))))

(defun depends1 (x y)
  (nonsymchk x '$depends)
  (cons (cons x nil) (if ($listp y) (cdr y) (cons y nil))))

(defmspec $dependencies (form) (i-$dependencies (cdr form)))

(defmfun i-$dependencies (l)
  (dolist (z l)
    (cond ((atom z) (merror "Wrong format.  Try F(X)."))
	  ((or (eq (caar z) 'mqapply) (member 'array (cdar z) :test #'eq))
	   (merror "Improper form for `depends':~%~M" z))
	  (t (let ((y (mget (caar z) 'depends)))
	       (mputprop (caar z)
			 (setq y (union* (reverse (cdr z)) y))
			 'depends)
	       (unless (cdr $dependencies)
		 (setq $dependencies (copy-list '((mlist simp)))))
	       (add2lnc (cons (cons (caar z) nil) y) $dependencies)))))
  (cons '(mlist simp) l))

(defmspec $gradef (l)
  (setq l (cdr l))
  (let ((z (car l)) (n 0))
    (cond ((atom z)
	   (if (not (= (length l) 3)) (merror "Wrong arguments to `gradef'"))
	   (mputprop z
		     (cons (cons (cadr l) (meval (caddr l)))
			   (mget z '$atomgrad))
		     '$atomgrad)
	   (i-$dependencies (cons (list (ncons z) (cadr l)) nil))
	   (add2lnc z $props)
	   z)
	  ((or (mopp1 (caar z)) (member 'array (cdar z) :test #'eq))
	   (merror "Wrong arguments to `gradef':~%~M" z))
	  ((prog2 (setq n (- (length z) (length l))) (minusp n))
	   (wna-err '$gradef))
	  (t (do ((zl (cdr z) (cdr zl))) ((null zl))
	       (if (not (symbolp (car zl)))
		   (merror "Parameters to `gradef' must be names:~%~M"
			   (car zl))))
	     (setq l (nconc (mapcar #'(lambda (x) (remsimp (meval x)))
				    (cdr l))
			    (mapcar #'(lambda (x) (list '(%derivative) z x 1))
				    (nthcdr (- (length z) n) z))))
	     (putprop (caar z)
		      (sublis (mapcar #'cons (cdr z) (mapcar #'stripdollar (cdr z)))
			      (cons (cdr z) l))
		      'grad)
	     (or (cdr $gradefs) (setq $gradefs (copy-list '((mlist simp)))))
	     (add2lnc (cons (cons (caar z) nil) (cdr z)) $gradefs) z))))

(defmfun $diff n (let (derivlist) (deriv (listify n))))

(defmfun $del (e) (stotaldiff e))

(defun deriv (e)
  (prog (exp z count)
     (cond ((null e) (wna-err '$diff))
	   ((null (cdr e)) (return (stotaldiff (car e))))
	   ((null (cddr e)) (nconc e '(1))))
     (setq exp (car e) z (setq e (copy-list e)))
     loop (if (or (null derivlist) (member (cadr z) derivlist :test #'equal)) (go doit))
					; DERIVLIST is set by $EV
     (setq z (cdr z))
     loop2(cond ((cdr z) (go loop))
		((null (cdr e)) (return exp))
		(t (go noun)))
     doit (cond ((nonvarcheck (cadr z) '$diff))
		((null (cddr z)) (wna-err '$diff))
		((not (eq (ml-typep (caddr z)) 'fixnum)) (go noun))
		((minusp (setq count (caddr z)))
		 (merror "Improper count to `diff':~%~M" count)))
     loop1(cond ((zerop count) (rplacd z (cdddr z)) (go loop2))
		((equal (setq exp (sdiff exp (cadr z))) 0) (return 0)))
     (setq count (1- count))
     (go loop1)
     noun (return (diff%deriv (cons exp (cdr e))))))

(defun chainrule (e x)
  (let (w)
    (cond (islinp (if (and (not (atom e))
			   (eq (caar e) '%derivative)
			   (not (freel (cdr e) x)))
		      (diff%deriv (list e x 1))
		      0))
	  ((atomgrad e x))
	  ((not (setq w (mget (cond ((atom e) e)
				    ((member 'array (cdar e) :test #'eq) (caar e))
				    ((atom (cadr e)) (cadr e))
				    (t (caaadr e)))
			      'depends)))
	   0)
	  (t (let (derivflag)
	       (addn (mapcar
		      #'(lambda (u)
			  (let ((y (sdiff u x)))
			    (if (equal y 0)
				0
				(list '(mtimes)
				      (or (atomgrad e u)
					  (list '(%derivative) e u 1))
				      y))))
		      w)
		     nil))))))

(defun atomgrad (e x)
  (let (y)
    (and (atom e) (setq y (mget e '$atomgrad)) (assolike x y))))

(defun depends (e x)
  (cond ((alike1 e x) t)
	((mnump e) nil)
	((atom e) (mget e 'depends))
	(t (or (depends (caar e) x) (dependsl (cdr e) x)))))

(defun dependsl (l x)
  (dolist (u l)
    (if (depends u x) (return t))))

(defmfun sdiff (e x) ; The args to SDIFF are assumed to be simplified.
  (cond ((alike1 e x) 1)
	((mnump e) 0)
	((or (atom e) (member 'array (cdar e) :test #'eq)) (chainrule e x))
	((eq (caar e) 'mrat) (ratdx e x))
	((eq (caar e) 'mplus) (addn (sdiffmap (cdr e) x) t))
	((mbagp e) (cons (car e) (sdiffmap (cdr e) x)))
	((member (caar e) '(%sum %product) :test #'eq) (diffsumprod e x))
	((eq (caar e) '%at) (diff-%at e x))
	((not (depends e x)) 0)
	((eq (caar e) 'mtimes) (addn (sdifftimes (cdr e) x) t))
	((eq (caar e) 'mexpt) (diffexpt e x))
	((eq (caar e) 'mnctimes)
	 (let (($dotdistrib t))
	   (add2 (ncmuln (cons (sdiff (cadr e) x) (cddr e)) t)
		 (ncmul2 (cadr e) (sdiff (cons '(mnctimes) (cddr e)) x)))))
	((and $vect_cross (eq (caar e) '|$~|))
	 (add2* `((|$~|) ,(cadr e) ,(sdiff (caddr e) x))
		`((|$~|) ,(sdiff (cadr e) x) ,(caddr e))))
	((eq (caar e) 'mncexpt) (diffncexpt e x))
	((member (caar e) '(%log %plog) :test #'eq)
	 (sdiffgrad (cond ((and (not (atom (cadr e))) (eq (caaadr e) 'mabs))
			   (cons (car e) (cdadr e)))
			  (t e))
		    x))
	((eq (caar e) '%derivative)
	 (cond ((or (atom (cadr e)) (member 'array (cdaadr e) :test #'eq)) (chainrule e x))
	       ((freel (cddr e) x) (diff%deriv (cons (sdiff (cadr e) x) (cddr e))))
	       (t (diff%deriv (list e x 1)))))
	((member (caar e) '(%binomial $beta) :test #'eq)
	 (let ((efact ($makefact e)))
	   (mul2 (factor (sdiff efact x)) (div e efact))))
	((eq (caar e) '%integrate) (diffint e x))
	((eq (caar e) '%laplace) (difflaplace e x))
	((eq (caar e) '%at) (diff-%at e x))
	((member (caar e) '(%realpart %imagpart) :test #'eq)
	 (list (cons (caar e) nil) (sdiff (cadr e) x)))
	((and (eq (caar e) 'mqapply)
	      (eq (caaadr e) '$%f))
	 ;; Handle %f, hypergeometric function
	 ;;
	 ;; The derivative of %f[p,q]([a1,...,ap],[b1,...,bq],z) is
	 ;;
	 ;; a1*a2*...*ap/(b1*b2*...*bq)
	 ;;   *%f[p,q]([a1+1,a2+1,...,ap+1],[b1+1,b2+1,...,bq+1],z)
	 (let* ((arg1 (cdr (third e)))
		(arg2 (cdr (fourth e)))
		(v (fifth e)))
	   (mul (sdiff v x)
		(div (mull arg1) (mull arg2))
		`((mqapply) (($%f array) ,(length arg1) ,(length arg2))
		  ((mlist) ,@(incr1 arg1))
		  ((mlist) ,@(incr1 arg2))
		  ,v))))
	(t (sdiffgrad e x))))

(defun sdiffgrad (e x)
  (let ((fun (caar e)) grad args)
    (cond ((and (eq fun 'mqapply) (oldget (caaadr e) 'grad))
	   (sdiffgrad (cons (cons (caaadr e) nil) (append (cdadr e) (cddr e)))
		      x))
	  ((or (eq fun 'mqapply) (null (setq grad (oldget fun 'grad))))
	   (if (not (depends e x)) 0 (diff%deriv (list e x 1))))
	  ((not (= (length (cdr e)) (length (car grad))))
	   (merror "Wrong number of arguments for ~:M" fun))
	  (t (setq args (sdiffmap (cdr e) x))
	     (addn (mapcar
		    #'mul2
		    (cdr (substitutel
			  (cdr e) (car grad)
			  (do ((l1 (cdr grad) (cdr l1))
			       (args args (cdr args)) (l2))
			      ((null l1) (cons '(mlist) (nreverse l2)))
			    (setq l2 (cons (cond ((equal (car args) 0) 0)
						 (t (car l1)))
					   l2)))))
		    args)
		   t)))))

(defun sdiffmap (e x)
  (mapcar #'(lambda (term) (sdiff term x)) e))

(defun sdifftimes (l x)
  (prog (term left out)
   loop (setq term (car l) l (cdr l))
   (setq out (cons (muln (cons (sdiff term x) (append left l)) t) out))
   (if (null l) (return out))
   (setq left (cons term left))
   (go loop)))

(defun diffexpt (e x)
  (if (mnump (caddr e))
      (mul3 (caddr e) (power (cadr e) (addk (caddr e) -1)) (sdiff (cadr e) x))
      (mul2 e (add2 (mul3 (power (cadr e) -1) (caddr e) (sdiff (cadr e) x))
		    (mul2 (simplifya (list '(%log) (cadr e)) t)
			  (sdiff (caddr e) x))))))

(defun diff%deriv (e)
  (let (derivflag)
    (simplifya (cons '(%derivative) e) t)))


;; grad properties

(let ((header '(x)))
  (mapc #'(lambda (z) (putprop (car z) (cons header (cdr z)) 'grad))
	;; All these GRAD templates have been simplified and then the SIMP flags
	;;	 (which are unnecessary) have been removed to save core space.
	'((%log ((mexpt) x -1)) (%plog ((mexpt) x -1))
	  (%gamma ((mtimes) ((mqapply) (($psi array) 0) x) ((%gamma) x)))
	  (mfactorial ((mtimes) ((mqapply) (($psi array) 0) ((mplus) 1 x)) ((mfactorial) x)))
	  (%sin ((%cos) x))
	  (%cos ((mtimes) -1 ((%sin) x)))
	  (%tan ((mexpt) ((%sec) x) 2))
	  (%cot ((mtimes) -1 ((mexpt) ((%csc) x) 2)))
	  (%sec ((mtimes) ((%sec) x) ((%tan) x)))
	  (%csc ((mtimes) -1 ((%cot) x) ((%csc) x)))
	  (%asin ((mexpt) ((mplus) 1 ((mtimes) -1 ((mexpt) x 2))) ((rat) -1 2)))
	  (%acos ((mtimes) -1 ((mexpt) ((mplus) 1 ((mtimes) -1 ((mexpt) x 2)))
			       ((rat) -1 2))))
	  (%atan ((mexpt) ((mplus) 1 ((mexpt) x 2)) -1))
	  (%acot ((mtimes) -1 ((mexpt) ((mplus) 1 ((mexpt) x 2)) -1)))
	  (%acsc ((mtimes) -1
		  ((mexpt) ((mplus) 1 ((mtimes) -1 ((mexpt) x -2)))
		   ((rat) -1 2))
		  ((mexpt) x -2)))
	  (%asec ((mtimes)
		  ((mexpt) ((mplus) 1 ((mtimes) -1 ((mexpt) x -2)))
		   ((rat) -1 2))
		  ((mexpt) x -2)))
	  (%sinh ((%cosh) x))
	  (%cosh ((%sinh) x))
	  (%tanh ((mexpt) ((%sech) x) 2))
	  (%coth ((mtimes) -1 ((mexpt) ((%csch) x) 2)))
	  (%sech ((mtimes) -1 ((%sech) x) ((%tanh) x)))
	  (%csch ((mtimes) -1 ((%coth) x) ((%csch) x)))
	  (%asinh ((mexpt) ((mplus) 1 ((mexpt) x 2)) ((rat) -1 2)))
	  (%acosh ((mexpt) ((mplus) -1 ((mexpt) x 2)) ((rat) -1 2)))
	  (%atanh ((mexpt) ((mplus) 1 ((mtimes) -1 ((mexpt) x 2))) -1))
	  (%acoth ((mtimes) -1 ((mexpt) ((mplus) -1 ((mexpt) x 2)) -1)))
	  (%asech ((mtimes) -1
		   ((mexpt) ((mplus) -1 ((mexpt) x -2)) ((rat) -1 2))
		   ((mexpt) x -2)))
	  (%acsch ((mtimes) -1
		   ((mexpt) ((mplus) 1 ((mexpt) x -2)) ((rat) -1 2))
		   ((mexpt) x -2)))
	  (mabs ((mtimes) x ((mexpt) ((mabs) x) -1)))
	  (%erf ((mtimes) 2 ((mexpt) $%pi ((rat) -1 2))
		 ((mexpt) $%e ((mtimes) -1 ((mexpt) x 2)))))
	  ;;	   ($LI2 ((MTIMES) -1 ((%LOG) ((MPLUS) 1 ((MTIMES) -1 X))) ((MEXPT) X -1)))
	  ($ei ((mtimes) ((mexpt) x -1) ((mexpt) $%e x))))))

(defprop $atan2 ((x y) ((mtimes) y ((mexpt) ((mplus) ((mexpt) x 2) ((mexpt) y 2)) -1))
		 ((mtimes) -1 x ((mexpt) ((mplus) ((mexpt) x 2) ((mexpt) y 2)) -1)))
  grad)

(defprop $%j ((n x) ((%derivative) ((mqapply) (($%j array) n) x) n 1)
	      ((mplus) ((mqapply) (($%j array) ((mplus) -1 n)) x)
	       ((mtimes) -1 n ((mqapply) (($%j array) n) x) ((mexpt) x -1))))
  grad)

(defprop $li ((n x) ((%derivative) ((mqapply) (($li array) n) x) n 1)
	      ((mtimes) ((mqapply) (($li array) ((mplus) -1 n)) x) ((mexpt) x -1)))
  grad)

(defprop $psi ((n x) ((%derivative) ((mqapply) (($psi array) n) x) n 1)
	       ((mqapply) (($psi array) ((mplus) 1 n)) x))
  grad)

(defmfun atvarschk (argl)
  (do ((largl (length argl) (1- largl))
       (latvrs (length atvars))
       (l))
      ((not (< latvrs largl)) (nconc atvars l))
    (setq l (cons (implode (cons '& (cons '@ (mexploden largl)))) l))))

(defmfun notloreq (x)
  (or (atom x)
      (not (member (caar x) '(mlist mequal) :test #'eq))
      (and (eq (caar x) 'mlist)
	   (dolist (u (cdr x))
	     (if (not (mequalp u)) (return t))))))

(defmfun substitutel (l1 l2 e)
  (do ((l1 l1 (cdr l1))
       (l2 l2 (cdr l2)))
      ((null l1) e)
    (setq e (maxima-substitute (car l1) (car l2) e))))

(defmfun union* (a b)
  (do ((a a (cdr a))
       (x b))
      ((null a) x)
    (if (not (memalike (car a) b)) (setq x (cons (car a) x)))))

(defmfun intersect* (a b)
  (do ((a a (cdr a))
       (x))
      ((null a) x)
    (if (memalike (car a) b) (setq x (cons (car a) x)))))

(defmfun nthelem (n e)
  (car (nthcdr (1- n) e)))

(defmfun delsimp (e)
  (delq 'simp (copy-list e) 1))

(defmfun remsimp (e)
  (if (atom e) e (cons (delsimp (car e)) (mapcar #'remsimp (cdr e)))))

(defmfun $trunc (e)
  (cond ((atom e) e)
	((eq (caar e) 'mplus) (cons (append (car e) '(trunc)) (cdr e)))
	((mbagp e) (cons (car e) (mapcar #'$trunc (cdr e))))
	((specrepp e) ($trunc (specdisrep e)))
	(t e)))

(defmfun nonvarcheck (e fn)
  (if (or (mnump e)
	  (maxima-integerp e)
	  (and (not (atom e)) (not (eq (caar e) 'mqapply)) (mopp1 (caar e))))
      (merror "Non-variable 2nd argument to ~:M:~%~M" fn e)))

(defmspec $ldisplay (form)
  (disp1 (cdr form) t t))

(defmfun $ldisp n
  (disp1 (listify n) t nil))

(defmspec $display
    (form) (disp1 (cdr form) nil t))

(defmfun $disp n
  (disp1 (listify n) nil nil))

(defun disp1 (ll lablist eqnsp)
  (if lablist (setq lablist (cons '(mlist simp) nil)))
  (do ((ll ll (cdr ll))
       (l)
       (ans)
       ($dispflag t)
       (tim 0))
      ((null ll) (or lablist '$done))
    (setq l (car ll) ans (if eqnsp (meval l) l))
    (if (and eqnsp (not (mequalp ans)))
	(setq ans (list '(mequal simp) (disp2 l) ans)))
    (if lablist (nconc lablist (cons (elabel ans) nil)))
    (setq tim (get-internal-run-time))
    (displa (list '(mlable) (if lablist linelable) ans))
    (mterpri)
    (timeorg tim)))

(defun disp2 (e)
  (cond ((atom e) e)
	((eq (caar e) 'mqapply)
	 (cons '(mqapply) (cons (cons (caadr e) (mapcar #'meval (cdadr e)))
				(mapcar #'meval (cddr e)))))
	((eq (caar e) 'msetq) (disp2 (cadr e)))
	((eq (caar e) 'mset) (disp2 (meval (cadr e))))
	((eq (caar e) 'mlist) (cons (car e) (mapcar #'disp2 (cdr e))))
	((mspecfunp (caar e)) e)
	(t (cons (car e) (mapcar #'meval (cdr e))))))

; Construct a new intermediate result label,
; and bind it to the expression e.
; The global flag $NOLABELS is ignored; the label is always bound.
; Otherwise (if ELABEL were to observe $NOLABELS) it would be
; impossible to programmatically refer to intermediate result expression.

(defmfun elabel (e)
  (if (not (checklabel $linechar)) (setq $linenum (1+ $linenum)))
  (let (($nolabels nil)) ; <-- This is pretty ugly. MAKELABEL should take another argument.
    (makelabel $linechar))
  (setf (symbol-value linelable) e)
  linelable)

(defmfun $dispterms (e)
  (cond ((or (atom e) (eq (caar e) 'bigfloat)) (displa e))
	((specrepp e) ($dispterms (specdisrep e)))
	(t (let (($dispflag t))
	     (mterpri)
	     (displa (getop (mop e)))
	     (do ((e (if (and (eq (caar e) 'mplus) (not $powerdisp))
			 (reverse (cdr e))
			 (margs e))
		     (cdr e))) ((null e)) (mterpri) (displa (car e)) (mterpri)))
	   (mterpri)))
  '$done)

(defmfun $dispform n
  (if (not (or (= n 1) (and (= n 2) (eq (arg 2) '$all))))
      (merror "Incorrect arguments to `dispform'"))
  (let ((e (arg 1)))
    (if (or (atom e)
	    (atom (setq e (if (= n 1) (nformat e) (nformat-all e))))
	    (member 'simp (cdar e) :test #'eq))
	e
	(cons (cons (caar e) (cons 'simp (cdar e)))
	      (if (and (eq (caar e) 'mplus) (not $powerdisp))
		  (reverse (cdr e))
		  (cdr e))))))

;;; These functions implement the Macsyma functions $op and $operatorp.
;;; Dan Stanger
(defmfun $op (expr)
  ($part expr 0))

(defmfun $operatorp (expr oplist)
  (if ($listp oplist)
      ($member ($op expr) oplist)
      (equal ($op expr) oplist)))

(defmfun $part n
  (mpart (listify n) nil nil $inflag '$part))

(defmfun $inpart n
  (mpart (listify n) nil nil t '$inpart))

(defmspec $substpart (l)
  (let ((substp t))
    (mpart (cdr l) t nil $inflag '$substpart)))

(defmspec $substinpart (l)
  (let ((substp t))
    (mpart (cdr l) t nil t '$substinpart)))

(defmfun part1 (arglist substflag dispflag inflag) ; called only by TRANSLATE
  (let ((substp t))
    (mpart arglist substflag dispflag inflag '$substpart)))

(defmfun mpart (arglist substflag dispflag inflag fn)
  (prog (substitem arg arg1 exp exp1 exp* sevlist count prevcount n specp
	 lastelem lastcount)
     (setq specp (or substflag dispflag))
     (if substflag (setq substitem (car arglist) arglist (cdr arglist)))
     (if (null arglist) (wna-err '$part))
     (setq exp (if substflag (meval (car arglist)) (car arglist)))
     (when (null (setq arglist (cdr arglist)))
       (setq $piece exp)
       (return (cond (substflag (meval substitem))
		     (dispflag (box exp dispflag))
		     (t exp))))
     (cond ((not inflag)
	    (cond ((or (and ($listp exp) (null (cdr arglist)))
		       (and ($matrixp exp)
			    (or (null (cdr arglist)) (null (cddr arglist)))))
		   (setq inflag t))
		  ((not specp) (setq exp (nformat exp)))
		  (t (setq exp (nformat-all exp)))))
	   ((specrepp exp) (setq exp (specdisrep exp))))
     (if (and (atom exp) (null $partswitch))
	 (merror "~:M called on atom: ~:M" fn exp))
     (if (and inflag specp) (setq exp (copy-tree exp)))
     (setq exp* exp)
     start(cond ((or (atom exp) (eq (caar exp) 'bigfloat)) (go err))
		((equal (setq arg (cond (substflag (meval (car arglist)))
					(t (car arglist))))
			0)
		 (setq arglist (cdr arglist))
		 (cond ((mnump substitem)
			(merror "~M is an invalid operator in ~:M"
				substitem fn))
		       ((and specp arglist)
			(if (eq (caar exp) 'mqapply)
			    (prog2 (setq exp (cadr exp)) (go start))
			    (merror "Invalid operator in ~:M" fn)))
		       (t (setq $piece (getop (mop exp)))
			  (return
			    (cond (substflag
				   (setq substitem (getopr (meval substitem)))
				   (cond ((mnump substitem)
					  (merror "Invalid operator in ~:M:~%~M"
						  fn substitem))
					 ((not (atom substitem))
					  (if (not (eq (caar exp) 'mqapply))
					      (rplaca (rplacd exp (cons (car exp)
									(cdr exp)))
						      '(mqapply)))
					  (rplaca (cdr exp) substitem)
					  (return (resimplify exp*)))
					 ((eq (caar exp) 'mqapply)
					  (rplacd exp (cddr exp))))
				   (rplaca exp (cons substitem
						     (if (and (member 'array (cdar exp) :test #'eq)
							      (not (mopp substitem)))
							 '(array))))
				   (resimplify exp*))
				  (dispflag
				   (rplacd exp (cdr (box (copy-tree exp) dispflag)))
				   (rplaca exp (if (eq dispflag t)
						   '(mbox)
						   '(mlabox)))
				   (resimplify exp*))
				  (t (when arglist (setq exp $piece) (go a))
				     $piece))))))
		((not (atom arg)) (go several))
		((not (fixnump arg))
		 (merror "Non-integer argument to ~:M:~%~M" fn arg))
		((< arg 0) (go bad)))
     (if (eq (caar exp) 'mqapply) (setq exp (cdr exp)))
     loop (cond ((not (zerop arg)) (setq arg (1- arg) exp (cdr exp))
		 (if (null exp) (go err)) (go loop))
		((null (setq arglist (cdr arglist)))
		 (return (cond (substflag (setq $piece (resimplify (car exp)))
					  (rplaca exp (meval substitem))
					  (resimplify exp*))
			       (dispflag (setq $piece (resimplify (car exp)))
					 (rplaca exp (box (car exp) dispflag))
					 (resimplify exp*))
			       (inflag (setq $piece (car exp)))
			       (t (setq $piece (simplify (car exp))))))))
     (setq exp (car exp))
     a    (cond ((and (not inflag) (not specp)) (setq exp (nformat exp)))
		((specrepp exp) (setq exp (specdisrep exp))))
     (go start)
     err  (cond ((eq $partswitch 'mapply)
		 (merror "Improper index to list or matrix"))
		($partswitch (return (setq $piece '$end)))
		(t (merror "~:M fell off end." fn)))
     bad  (improper-arg-err arg fn)
     several
     (if (or (not (member (caar arg) '(mlist $allbut) :test #'eq)) (cdr arglist))
	 (go bad))
     (setq exp1 (cons (caar exp) (if (member 'array (cdar exp) :test #'eq) '(array))))
     (if (eq (caar exp) 'mqapply)
	 (setq sevlist (list (cadr exp) exp1) exp (cddr exp))
	 (setq sevlist (ncons exp1) exp (cdr exp)))
     (setq arg1 (cdr arg) prevcount 0 exp1 exp)
     (dolist (arg* arg1)
       (if (not (fixnump arg*))
	   (merror "Non-integer argument to ~:M:~%~M" fn arg*)))
     (when (and specp (eq (caar arg) 'mlist))
       (if substflag (setq lastelem (car (last arg1))))
       (setq arg1 (sort (copy-list arg1) #'<)))
     (when (eq (caar arg) '$allbut)
       (setq n (length exp))
       (dolist (i arg1)
	 (if (or (< i 1) (> i n))
	     (merror "Invalid argument to ~:M:~%~M" fn i)))
       (do ((i n (1- i)) (arg2))
	   ((= i 0) (setq arg1 arg2))
	 (if (not (member i arg1 :test #'equal)) (setq arg2 (cons i arg2))))
       (if substflag (setq lastelem (car (last arg1)))))
     (if (null arg1) (if specp (go bad) (go end)))
     (if substflag (setq lastcount lastelem))
     sevloop
     (if specp
	 (setq count (- (car arg1) prevcount) prevcount (car arg1))
	 (setq count (car arg1)))
     (if (< count 1) (go bad))
     (if (and substflag (< (car arg1) lastelem))
	 (setq lastcount (1- lastcount)))
     count(cond ((null exp) (go err))
		((not (= count 1)) (setq count (1- count) exp (cdr exp)) (go count)))
     (setq sevlist (cons (car exp) sevlist))
     (setq arg1 (cdr arg1))
     end  (cond ((null arg1)
		 (setq sevlist (nreverse sevlist))
		 (setq $piece (if (or inflag (not specp))
				  (simplify sevlist)
				  (resimplify sevlist)))
		 (return (cond (substflag (rplaca (nthcdr (1- lastcount) exp1)
						  (meval substitem))
					  (resimplify exp*))
			       (dispflag (rplaca exp (box (car exp) dispflag))
					 (resimplify exp*))
			       (t $piece))))
		(substflag (if (null (cdr exp)) (go err))
			   (rplaca exp (cadr exp)) (rplacd exp (cddr exp)))
		(dispflag (rplaca exp (box (car exp) dispflag))
			  (setq exp (cdr exp)))
		(t (setq exp exp1)))
     (go sevloop)))

(defmfun getop (x)
  (or (and (symbolp x) (get x 'op)) x))

(defmfun getopr (x)
  (or (and (symbolp x) (get x 'opr)) x))


(defmfun $listp (x)
  (and (not (atom x))
       (not (atom (car x)))
       (eq (caar x) 'mlist)))

(defmfun $cons (x e)
  (atomchk (setq e (specrepcheck e)) '$cons t)
  (mcons-exp-args e (cons x (margs e))))

(defmfun $endcons (x e)
  (atomchk (setq e (specrepcheck e)) '$endcons t)
  (mcons-exp-args e (append (margs e) (ncons x))))

(defmfun $reverse (e)
  (atomchk (setq e (format1 e)) '$reverse nil)
  (mcons-exp-args e (reverse (margs e))))

(defmfun $append n
  (if (= n 0)
      '((mlist simp))
      (let ((arg1 (specrepcheck (arg 1))) op arrp)
	(atomchk arg1 '$append nil)
	(setq op (mop arg1) arrp (if (member 'array (cdar arg1) :test #'eq) t))
	(mcons-exp-args
	 arg1
	 (apply #'append
		(mapcar #'(lambda (u)
			    (atomchk (setq u (specrepcheck u)) '$append nil)
			    (if (or (not (alike1 op (mop u)))
				    (not (eq arrp (if (member 'array (cdar u) :test #'eq) t))))
				(merror "Arguments to `append' are not compatible."))
			    (margs u))
			(listify n)))))))

(defun mcons-exp-args (e args)
  (if (eq (caar e) 'mqapply)
      (list* (delsimp (car e)) (cadr e) args)
      (cons (if (mlistp e) (car e) (delsimp (car e))) args)))

(defmfun $member (x e)
  (atomchk (setq e ($totaldisrep e)) '$member t)
  (if (memalike ($totaldisrep x) (margs e)) t))

(defmfun atomchk (e fun 2ndp)
  (if (or (atom e) (eq (caar e) 'bigfloat))
      (merror "~Margument value `~M' to ~:M was not a list"
	      (if 2ndp '|2nd | "") e fun)))

(defmfun format1 (e)
  (cond (($listp e) e) ($inflag (specrepcheck e)) (t (nformat e))))

(defmfun $first (e)
  (atomchk (setq e (format1 e)) '$first nil)
  (if (null (cdr e)) (merror "Argument to `first' is empty."))
  (car (margs e)))

;; This macro is used to create functions second thru tenth.
;; Rather than try to modify mformat for ~:R, use the quoted symbol

(defmacro make-nth (si i)
  (let ((sim (intern (concatenate 'string "$" (symbol-name si)))))
    `(defmfun ,sim (e)
      (atomchk (setq e (format1 e)) ',sim nil)
      (if (< (length (margs e)) ,i)
	  (merror "There is no ~A element:~%~M" ',si e))
      (,si (margs e)))))

(make-nth second  2)
(make-nth third   3)
(make-nth fourth  4)
(make-nth fifth   5)
(make-nth sixth   6)
(make-nth seventh 7)
(make-nth eighth  8)
(make-nth ninth   9)
(make-nth tenth  10)

(defmfun $rest n
  (prog (m fun fun1 revp)
     (if (and (= n 2) (equal (arg 2) 0)) (return (arg 1)))
     (atomchk (setq m (format1 (arg 1))) '$rest nil)
     (cond ((= n 1))
	   ((not (= n 2)) (wna-err '$rest))
	   ((not (fixnump (arg 2)))
	    (merror "2nd argument to `rest' must be an integer:~%~M"
		    (arg 2)))
	   ((minusp (setq n (arg 2))) (setq n (- n) revp t)))
     (if (< (length (margs m)) n)
	 (if $partswitch (return '$end) (merror "`rest' fell off end.")))
     (setq fun (car m))
     (if (eq (car fun) 'mqapply) (setq fun1 (cadr m) m (cdr m)))
     (setq m (cdr m))
     (if revp (setq m (reverse m)))
     (do ((n n (1- n))) ((zerop n)) (setq m (cdr m)))
     (setq m (cons (if (eq (car fun) 'mlist) fun (delsimp fun))
		   (if revp (nreverse m) m)))
     (if (eq (car fun) 'mqapply)
	 (return (cons (car m) (cons fun1 (cdr m)))))
     (return m)))

(defmfun $last (e)
  (atomchk (setq e (format1 e)) '$last nil)
  (if (null (cdr e)) (merror "Argument to `last' is empty."))
  (car (last e)))

(defmfun $args (e)
  (atomchk (setq e (format1 e)) '$args nil)
	 (cons '(mlist) (margs e)))

(defmfun $delete n
  (cond ((= n 2) (setq n -1))
	((not (= n 3)) (wna-err '$delete))
	((or (not (fixnump (arg 3))) (minusp (setq n (arg 3))))
	 (merror "Improper 3rd argument to `delete':~%~M" (arg 3))))
  (let ((x (arg 1)) (l (arg 2)))
    (atomchk (setq l (specrepcheck l)) '$delete t)
    (setq x (specrepcheck x) l (cons (delsimp (car l)) (copy-list (cdr l))))
    (prog (l1)
       (setq l1 (if (eq (caar l) 'mqapply) (cdr l) l))
       loop (cond ((or (null (cdr l1)) (zerop n)) (return l))
		  ((alike1 x (specrepcheck (cadr l1)))
		   (setq n (1- n)) (rplacd l1 (cddr l1)))
		  (t (setq l1 (cdr l1))))
       (go loop))))

(defmfun $length (e)
  (setq e (cond (($listp e) e)
		((or $inflag (not ($ratp e))) (specrepcheck e))
		(t ($ratdisrep e))))
  (cond ((symbolp e) (merror "`length' called on atomic symbol ~:M" e))
	((or (numberp e) (eq (caar e) 'bigfloat))
	 (if (and (not $inflag) (mnegp e))
	     1
	     (merror "`length' called on number ~:M" e)))
	((or $inflag (not (member (caar e) '(mtimes mexpt) :test #'eq))) (length (margs e)))
	((eq (caar e) 'mexpt)
	 (if (and (alike1 (caddr e) '((rat simp) 1 2)) $sqrtdispflag) 1 2))
	(t (length (cdr (nformat e))))))

(defmfun $atom (x)
  (setq x (specrepcheck x)) (or (atom x) (eq (caar x) 'bigfloat)))

(defmfun $symbolp (x)
  (setq x (specrepcheck x)) (symbolp x))

(defmfun $num (e)
  (let (x)
    (cond ((atom e) e)
	  ((eq (caar e) 'mrat) ($ratnumer e))
	  ((eq (caar e) 'rat) (cadr e))
	  ((eq (caar (setq x (nformat e))) 'mquotient) (simplify (cadr x)))
	  ((and (eq (caar x) 'mminus) (not (atom (setq x (cadr x))))
		(eq (caar x) 'mquotient))
	   (simplify (list '(mtimes) -1 (cadr x))))
	  (t e))))

(defmfun $denom (e)
  (cond ((atom e) 1)
	((eq (caar e) 'mrat) ($ratdenom e))
	((eq (caar e) 'rat) (caddr e))
	((or (eq (caar (setq e (nformat e))) 'mquotient)
	     (and (eq (caar e) 'mminus) (not (atom (setq e (cadr e))))
		  (eq (caar e) 'mquotient)))
	 (simplify (caddr e)))
	(t 1)))


(defmfun $fix (e)
  ($entier e))

(defmfun $entier (e)
  (let ((e1 (specrepcheck e)))
    (cond ((numberp e1) (floor e1))
	  ((ratnump e1) (setq e (quotient (cadr e1) (caddr e1)))
	   (if (minusp (cadr e1)) (1- e) e))
	  (($bfloatp e1)
	   (setq e (fpentier e1))
	   (if (and (minusp (cadr e1)) (not (zerop1 (sub e e1))))
	       (1- e)
	       e))
	  (t (list '($entier) e)))))

(defmfun $float (e)
  (cond ((numberp e) (float e))
	((and (symbolp e) (mget e '$numer)))
	((or (atom e) (member 'array (cdar e) :test #'eq)) e)
	((eq (caar e) 'rat) (fpcofrat e))
	((eq (caar e) 'bigfloat) (fp2flo e))
	((member (caar e) '(mexpt mncexpt) :test #'eq)
	 (list (ncons (caar e)) ($float (cadr e)) (caddr e)))
	(t (recur-apply #'$float e))))

(defmfun $coeff n
  (cond ((= n 3) (if (equal (arg 3) 0)
		     (coeff (arg 1) (arg 2) (arg 3))
		     (coeff (arg 1) (power (arg 2) (arg 3)) 1)))
	((= n 2) (coeff (arg 1) (arg 2) 1))
	(t (wna-err '$coeff))))

(defmfun coeff (e var pow)
  (simplify
   (cond ((alike1 e var) (if (equal pow 1) 1 0))
	 ((atom e) (if (equal pow 0) e 0))
	 ((eq (caar e) 'mexpt)
	  (cond ((alike1 (cadr e) var)
		 (if (or (equal pow 0) (not (alike1 (caddr e) pow))) 0 1))
		((equal pow 0) e)
		(t 0)))
	 ((or (eq (caar e) 'mplus) (mbagp e))
	  (cons (if (eq (caar e) 'mplus) '(mplus) (car e))
		(mapcar #'(lambda (e) (coeff e var pow)) (cdr e))))
	 ((eq (caar e) 'mrat) (ratcoeff e var pow))
	 ((equal pow 0) (if (free e var) e 0))
	 ((eq (caar e) 'mtimes)
	  (let ((term (if (equal pow 1) var (power var pow))))
	    (if (memalike term (cdr e)) ($delete term e 1) 0)))
	 (t 0))))

(declare-top (special powers var hiflg num flag))

(defmfun $hipow (e var)
  (findpowers e t))

;; These work best on expanded "simple" expressions.

(defmfun $lopow (e var)
  (findpowers e nil))

(defun findpowers (e hiflg)
  (let (powers num flag)
    (findpowers1 e)
    (cond ((null powers) (if (null num) 0 num))
	  (t (when num (setq powers (cons num powers)))
	     (maximin powers (if hiflg '$max '$min))))))

(defun findpowers1 (e)
  (cond ((alike1 e var) (checkpow 1))
	((atom e))
	((eq (caar e) 'mplus)
	 (cond ((not (freel (cdr e) var))
		(do ((e (cdr e) (cdr e))) ((null e))
		  (setq flag nil) (findpowers1 (car e))
		  (if (null flag) (checkpow 0))))))
	((and (eq (caar e) 'mexpt) (alike1 (cadr e) var)) (checkpow (caddr e)))
	((specrepp e) (findpowers1 (specdisrep e)))
	(t (mapc #'findpowers1 (cdr e)))))

(defun checkpow (pow)
  (setq flag t)
  (cond ((not (numberp pow)) (setq powers (cons pow powers)))
	((null num) (setq num pow))
	(hiflg (if (greaterp pow num) (setq num pow)))
	((lessp pow num) (setq num pow))))

(declare-top (unspecial powers var hiflg num flag))
