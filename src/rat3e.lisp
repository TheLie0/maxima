;;; -*-  Mode: Lisp; Package: Maxima; Syntax: Common-Lisp; Base: 10 -*- ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     The data in this file contains enhancments.                    ;;;;;
;;;                                                                    ;;;;;
;;;  Copyright (c) 1984,1987 by William Schelter,University of Texas   ;;;;;
;;;     All rights reserved                                            ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     (c) Copyright 1982 Massachusetts Institute of Technology         ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "MAXIMA")
(macsyma-module rat3e)

;;	This is the rational function package part 5.
;;	It includes the conversion and top-level routines used
;;	by the rest of the functions.

(DECLARE-TOP(*LEXPR OUTERMAP1 $DIVIDE $CONTENT $GCD $RAT $RATSIMP $FACTOR FACTOR)
	 (*EXPR $FLOAT)
	 (SPECIAL INTBS* ALFLAG VAR DOSIMP ALC $MYOPTIONS TRUNCLIST
		  VLIST SCANMAPP RADLIST EXPSUMSPLIT *RATSIMP* MPLC*
		  $RATSIMPEXPONS $EXPOP $EXPON $NEGDISTRIB $GCD))

(LOAD-MACSYMA-MACROS RZMAC RATMAC)

(DECLARE-TOP(GENPREFIX A_5))

(DEFMVAR GENVAR NIL
	 "List of gensyms used to point to kernels from within polynomials.
	 The values cell and property lists of these symbols are used to
	 store various information.")
(DEFMVAR GENPAIRS NIL)
(DEFMVAR VARLIST NIL "List of kernels")
(DEFMVAR *FNEWVARSW NIL)
(DEFMVAR *RATWEIGHTS NIL)
(DEFVAR *RATSIMP* NIL)
(DEFMVAR FACTORRESIMP NIL "If T resimplifies FACTOR(X-Y) to X-Y")

;; User level global variables.

(DEFMVAR $KEEPFLOAT NIL
	 "If t floating point coeffs are not converted to rationals")
(DEFMVAR $FACTORFLAG NIL "If t constant factor of polynomial is also factored")
(DEFMVAR $DONTFACTOR '((MLIST)))
(DEFMVAR $NOREPEAT T)
(DEFMVAR $RATWEIGHTS '((MLIST SIMP)))

(DEFMVAR $RATFAC NIL "If t cre-forms are kept factored")
(DEFMVAR $ALGEBRAIC NIL)
(DEFMVAR $RATVARS '((MLIST SIMP)))
(DEFMVAR $FACEXPAND T)

;; Constants required for Franz
#+Franz
(progn 'compile
   (defvar two30f	(expt 2.0 30.))
   (defvar two30 	(expt 2. 30.))
   (defvar two53f	(expt 2.0 53.))
   (defvar two53 	(expt 2. 53.)))

(DECLARE-TOP(SPECIAL EVP $INFEVAL))

(DEFMFUN MRATEVAL (X)
  (LET ((VARLIST (CADDAR X)))
    (COND ((AND EVP $INFEVAL) (MEVAL ($RATDISREP X)))
	  ((OR EVP
	       (AND $FLOAT $KEEPFLOAT)
	       (NOT (ALIKE VARLIST (MAPCAR #'MEVAL VARLIST))))
	   (RATF (MEVAL ($RATDISREP X))))
	  (T X))))

;(DEFPROP MRAT (LAMBDA (X) (MRATEVAL X)) MFEXPR*)
(DEFPROP MRAT mrateval MFEXPR*)

(DEFMFUN $RATNUMER (X)
 (SETQ X (TAYCHK2RAT X)) (CONS (CAR X) (CONS (CADR X) 1)))

(DEFMFUN $RATDENOM (X)
 (SETQ X (TAYCHK2RAT X)) (CONS (CAR X) (CONS (CDDR X) 1)))

(DEFUN TAYCHK2RAT (X)
 (COND ((AND ($RATP X) (MEMQ 'TRUNC (CDAR X))) ($TAYTORAT X)) (T (RATF X))))


(DEFMVAR TELLRATLIST NIL)

(DEFUN TELLRATDISP (X)
       (PDISREP+ (TRDISP1 (CDR X) (CAR X))))

(DEFUN TRDISP1 (P VAR)
       (COND ((NULL P) NIL)
	     (T (CONS (PDISREP* (IF (MTIMESP (CADR P)) (COPY1 (CADR P))
				    (CADR P))		;prevents clobbering p
				(PDISREP! (CAR P) VAR))
		      (TRDISP1 (CDDR P) VAR)))))

(DEFMFUN $UNTELLRAT N
  (DOLIST (X (LISTIFY N))
	  (IF (SETQ X (ASSOL X TELLRATLIST))
	      (SETQ TELLRATLIST (zl-REMOVE X TELLRATLIST))))
  (CONS '(MLIST) (MAPCAR 'TELLRATDISP TELLRATLIST)))

#+cl
(DEFMFUN $TELLRAT (&rest narg-rest-argument &aux
			 #+lispm (default-cons-area working-storage-area )
			 (narg (length narg-rest-argument)) n)
    (setq n narg)
  (DO ((I 1 (f1+ I))) ((f> I N)) (TELLRAT1 (narg-ARG I)))
  (OR (= N 0) (ADD2LNC 'TELLRATLIST $MYOPTIONS))
  (CONS '(MLIST) (MAPCAR 'TELLRATDISP TELLRATLIST)))

#-cl
(DEFMFUN $TELLRAT N
  (DO ((I 1 (f1+ I))) ((f> I N)) (TELLRAT1 (ARG I)))
  (OR (= N 0) (ADD2LNC 'TELLRATLIST $MYOPTIONS))
  (CONS '(MLIST) (MAPCAR 'TELLRATDISP TELLRATLIST)))

(DEFUN TELLRAT1 (X &AUX VARLIST GENVAR $ALGEBRAIC $RATFAC ALGVAR)
  (SETQ X ($TOTALDISREP X))
  (AND (NOT (ATOM X)) (EQ (CAAR X) 'MEQUAL)
       (NEWVAR (CADR X)))
  (NEWVAR (SETQ X (MEQHK X)))
  (OR VARLIST (MERROR "Improper polynomial"))
  (SETQ ALGVAR (CAR (LAST VARLIST)))
  (SETQ X (P-TERMS (PRIMPART (CADR (RATREP* X)))))
  (IF (NOT (EQUAL (PT-LC X) 1)) (MERROR "Minimal polynomial must be monic"))
  (DO ((P (PT-RED X) (PT-RED P))) ((PTZEROP P)) (SETF (PT-LC P) (PDIS (PT-LC P))))
  (SETQ ALGVAR (CONS ALGVAR X))
  (IF (SETQ X (ASSOL (CAR ALGVAR) TELLRATLIST))
      (SETQ TELLRATLIST (zl-REMOVE X TELLRATLIST)))
  (PUSH ALGVAR TELLRATLIST))


(DEFMFUN $PRINTVARLIST () (CONS '(MLIST) (COPY VARLIST)))

;(DEFMFUN $SHOWRATVARS (E)
;  (CONS '(MLIST SIMP)
;	(IF ($RATP E) (CADDAR E)
;	    (LET (VARLIST)
;	      (LNEWVAR E) 
;	      VARLIST))))
;Update from F302 --gsb
(DEFMFUN $SHOWRATVARS (E)
  (CONS '(MLIST SIMP)
	(COND (($RATP E)
	       (IF (MEMQ 'TRUNC (CDAR E)) (SETQ E ($TAYTORAT E)))
	       (CADDAR (MINIMIZE-VARLIST E)))
	      (T (LET (VARLIST) (LNEWVAR E) VARLIST)))))

(DEFMFUN $RATVARS N
  (ADD2LNC '$RATVARS $MYOPTIONS)
  (SETQ $RATVARS
	(CONS '(MLIST SIMP) (SETQ VARLIST (MAPFR1 (LISTIFY N) VARLIST)))))

(DEFUN MAPFR1 (L VARLIST) (MAPCAR #'(LAMBDA (Z) (FR1 Z VARLIST)) L))

(DEFMVAR INRATSIMP NIL)

(DEFMFUN $FULLRATSIMP N
       (IF (= N 0) (WNA-ERR '$FULLRATSIMP))
       (PROG (EXP EXP1 ARGL)
	     (SETQ EXP (ARG 1) ARGL (CDR (LISTIFY N)))
	LOOP (SETQ EXP1 (SIMPLIFY (APPLY #'$RATSIMP (CONS EXP ARGL))))
	     (COND ((ALIKE1 EXP EXP1) (RETURN EXP)))
	     (SETQ EXP EXP1)
	     (GO LOOP)))

(DEFUN FULLRATSIMP (L)
 (LET (($EXPOP 0) ($EXPON 0) (INRATSIMP T) $RATSIMPEXPONS)
      (SETQ L ($TOTALDISREP L)) (FR1 L VARLIST))) 

(DEFMFUN $TOTALDISREP (L)
  (COND ((ATOM L) L)
	((NOT (AMONG 'MRAT L)) L)
	((EQ (CAAR L) 'MRAT) (RATDISREP L))
	(T (CONS (DELQ 'RATSIMP (CAR L)) (MAPCAR '$TOTALDISREP (CDR L))))))

;;;VARLIST HAS MAIN VARIABLE AT END

(DEFUN JOINVARLIST (CDRL)
       (MAPC #'(LAMBDA (Z) (IF (NOT (MEMALIKE Z VARLIST))
			       (SETQ VARLIST (CONS Z VARLIST))))
	     (REVERSE (MAPFR1 CDRL NIL))))

(DEFMFUN $RAT N
       (IF (f= N 0) (WNA-ERR '$RAT))
       (COND ((f> N 1)
	      (LET (VARLIST) (JOINVARLIST (CDR (LISTIFY N)))
			     (LNEWVAR (ARG 1))
			     (RAT0 (ARG 1))))
	     (T (LNEWVAR (ARG 1)) (RAT0 (ARG 1)))))

(DEFUN RAT0 (EXP)					;SIMP FLAGS?
  (IF (MBAGP EXP) (CONS (CAR EXP) (MAPCAR #'RAT0 (CDR EXP))) (RATF EXP)))

(DEFMFUN $RATSIMP N
       (IF (f= N 0) (WNA-ERR '$RATSIMP))
       (COND ((f> N 1)
	      (LET (VARLIST) (JOINVARLIST (CDR (LISTIFY N)))
			     (FULLRATSIMP (ARG 1))))
	     (T (FULLRATSIMP (ARG 1)))))

; $RATSIMP, $FULLRATSIMP, and $RAT are LEXPRs to allow for optional extra 
; arguments specifying the VARLIST.

;;;PSQFR HAS NOT BEEN CHANGED TO MAKE USE OF THE SQFR FLAGS YET

(DEFMFUN $SQFR (X)
 (LET ((VARLIST (CDR $RATVARS)) GENVAR $KEEPFLOAT $RATFAC)
      (SUBLIS '((FACTORED . SQFRED) (IRREDUCIBLE . SQFR))
	      (FFACTOR X (FUNCTION PSQFR)))))

(DECLARE-TOP(SPECIAL FN CARGS))

(DEFUN WHICHFN (P)
       (COND ((AND (MEXPTP P) (INTEGERP (CADDR P)))
	      (LIST '(MEXPT) (WHICHFN (CADR P)) (CADDR P)))
	     ((MTIMESP P)
	      (CONS '(MTIMES) (MAPCAR (FUNCTION WHICHFN) (CDR P))))
	     (FN (FFACTOR P (FUNCTION PFACTOR)))
	     (T (FACTORALG P))))

(DECLARE-TOP(SPECIAL VAR))

(DEFMVAR ADN* 1 "common denom for algebraic coefficients")

(DEFUN FACTORALG (P) 
	 (PROG (ALC ANS ADN* $GCD)
	       (SETQ $GCD '$ALGEBRAIC)
	       (COND((OR (ATOM P) (NUMBERP P))(RETURN P)))
	       (SETQ ADN* 1)
	       (COND ((AND (NOT $NALGFAC) (NOT INTBS*))
		      (SETQ INTBS* (FINDIBASE MINPOLY*))))
	       (SETQ ALGFAC* T)
	       (SETQ ANS (FFACTOR P (FUNCTION PFACTOR)))
	       (COND ((EQ (CAAR ANS) 'MPLUS)(RETURN P))
		     (MPLC* (SETQ ANS (ALBK ANS))))
	       (IF (AND (NOT ALC) (EQUAL  1 ADN*)) (RETURN ANS))
	       (SETQ ANS (PARTITION ANS (CAR (LAST VARLIST)) 1))
	       (RETURN (MUL (LET ((DOSIMP T))
			      (MUL `((RAT) 1 ,ADN*)
				    (CAR ANS)
				    (IF ALC (PDIS ALC) 1)))
			    (CDR ANS)))))

(DEFUN ALBK (P)					 ;to undo monicizing subst 
  (let ((alpha (pdis alpha)) ($RATFAC T))
    (declare (special alpha))
;      (sratsimp    ;; don't multiply them back out
    (MAXIMA-SUBSTITUTE (list '(mtimes simp) mplc* alpha)	;assumes mplc* is int
		       alpha p)))


(DEFMFUN $GFACTOR (P &AUX (GAUSS T)) 
  (IF ($RATP P) (SETQ P ($RATDISREP P)))
  (SETQ P ($FACTOR (SUBST '%I '$%I P)
		   '((MPLUS) 1 ((MEXPT) %I 2))))
  (SETQ P (SUBLIS '((FACTORED . GFACTORED)
		    (IRREDUCIBLE . IRREDUCIBLEG))
		  P))
  (LET (($EXPOP 0) ($EXPON 0) $NEGDISTRIB) (MAXIMA-SUBSTITUTE '$%I '%I P)))


;; (DEFMFUN $FACTOR (EXP &OPTIONAL MINIMUM-POLYNOMIAL) ...)

(DEFMFUN $FACTOR NARGS
  (UNLESS (OR (f= NARGS 1) (f= NARGS 2)) (WNA-ERR '$FACTOR))
  (LET ($INTFACLIM (VARLIST (CDR $RATVARS)) GENVAR ANS)
    (SETQ ANS (APPLY #'FACTOR (LISTIFY NARGS)))
    (IF (AND FACTORRESIMP $NEGDISTRIB
	     (MTIMESP ANS) (NULL (CDDDR ANS))
	     (EQUAL (CADR ANS) -1) (MPLUSP (CADDR ANS)))
	(LET (($EXPOP 0) ($EXPON 0)) ($MULTTHRU ANS))
	ANS)))

#+cl (defvar alpha nil)

(DEFMFUN FACTOR NARGS
  ((LAMBDA (TELLRATLIST VARLIST GENVAR $GCD $NEGDISTRIB)
     (PROG (FN VAR MM* MPLC* INTBS* ALFLAG MINPOLY* ALPHA P ALGFAC* 
	    $KEEPFLOAT $ALGEBRAIC CARGS)
	   (OR (MEMQ $GCD *GCDL*) (SETQ $GCD (CAR *GCDL*)))
	   (LET  ($RATFAC)
	     (SETQ P (ARG 1) MM* 1 CARGS (CDR (LISTIFY NARGS)))
	     (AND (EQ (ml-typep P)  'symbol) (GO OUT))
	     (AND ($NUMBERP P) (GO NUM))
	     (COND ((MBAGP P)
		    (RETURN (CONS (CAR P)
				  (MAPCAR #'(LAMBDA (X) (APPLY 'FACTOR (CONS X CARGS)))
					  (CDR P))))))
	     (COND ((f= NARGS 2)
		    (SETQ ALPHA (MEQHK (ARG 2)))
		    (NEWVAR ALPHA)
		    (SETQ MINPOLY* (CADR (RATREP* ALPHA)))
		    (IF (OR (NOT (UNIVAR (CDR MINPOLY*)))
			    (PCOEFP MINPOLY*)
			    (f< (CADR MINPOLY*) 2))
			(MERROR
			  "The second argument to FACTOR must be a non-linear, univariate polynomial:~%~M"
			  ALPHA))
		    (SETQ ALPHA (PDIS (LIST (CAR MINPOLY*) 1 1)) 
			  MM* (CADR MINPOLY*))
		    (COND ((NOT (EQUAL (CADDR MINPOLY*) 1))
			   (SETQ MPLC* (CADDR MINPOLY*))
			   (SETQ MINPOLY* (PMONZ MINPOLY*))
			   (SETQ P (MAXIMA-SUBSTITUTE (DIV ALPHA MPLC*) ALPHA P)) ))
		    (SETQ $ALGEBRAIC T)
		    ($TELLRAT(PDIS MINPOLY*))
		    (SETQ ALGFAC* T))
		   (T (SETQ FN T)))
	     (IF (NOT SCANMAPP) (SETQ P (LET (($RATFAC T)) (SRATSIMP P))))
	     (NEWVAR P)
	     (AND (EQ (ml-typep P)  'symbol) (GO OUT))
	     (COND ((NUMBERP P) (GO NUM)))
	     (SETQ $NEGDISTRIB NIL)
	     (SETQ P (LET ($FACTORFLAG ($RATEXPAND $FACEXPAND)) (WHICHFN P))))
								 
	   (SETQ P (LET (($EXPOP 0) ($EXPON 0)) (SIMPLIFY P)))
	   (COND ((MNUMP P) (RETURN (FACTORNUMBER P)))
		 ((ATOM P) (GO OUT)))
	   (AND $RATFAC (NOT $FACTORFLAG) ($RATP (ARG 1)) (RETURN ($RAT P)))
	   (AND $FACTORFLAG (MTIMESP P) (MNUMP (CADR P))
		(SETQ ALPHA (FACTORNUMBER (CADR P)))
		(COND ((ALIKE1 ALPHA (CADR P)))
		      ((MTIMESP ALPHA)
		       (SETQ P (CONS (CAR P) (APPEND (CDR ALPHA) (CDDR P)))))
		      (T (SETQ P (CONS (CAR P) (CONS ALPHA (CDDR P)))))))
	   (AND (NULL (MEMQ 'FACTORED (CAR P)))
		(SETQ P (CONS (APPEND (CAR P) '(FACTORED)) (CDR P))))
	OUT  (RETURN P)
	NUM (RETURN (LET (($FACTORFLAG (NOT SCANMAPP))) (FACTORNUMBER P)))))
   NIL VARLIST NIL $GCD $NEGDISTRIB))


(DEFUN FACTORNUMBER (N)
 (SETQ N (NRETFACTOR1 (NRATFACT (CDR ($RAT N)))))
 (COND ((CDR N) (CONS '(MTIMES SIMP FACTORED)
		      (COND ((EQUAL (CAR N) -1)
			     (CONS (CAR N) (NREVERSE (CDR N))))
			    (T (NREVERSE N)))))
       ((ATOM (CAR N)) (CAR N))
       (T (CONS (CONS (CAAAR N) '(SIMP FACTORED)) (CDAR N)))))

(DEFUN NRATFACT (X)
 (COND ((EQUAL (CDR X) 1) (CFACTOR (CAR X)))
       ((EQUAL (CAR X) 1) (REVSIGN (CFACTOR (CDR X))))
       (T (NCONC (CFACTOR (CAR X)) (REVSIGN (CFACTOR (CDR X)))))))

;;; FOR LISTS OF JUST NUMBERS
(DEFUN NRETFACTOR1 (L)
  (COND ((NULL L) NIL)
	((EQUAL (CADR L) 1) (CONS (CAR L) (NRETFACTOR1 (CDDR L))))
	(T (CONS (COND ((EQUAL (CADR L) -1)
			(LIST '(RAT SIMP) 1 (CAR L)))
		       (T (LIST '(MEXPT SIMP) (CAR L) (CADR L))))
		 (NRETFACTOR1 (CDDR L))))))

(DECLARE-TOP(UNSPECIAL VAR))


(DEFMFUN $MOD NARGS
 (IF (NOT (OR (f= NARGS 1) (f= NARGS 2))) (WNA-ERR '$MOD))
 (LET ((MODULUS MODULUS))
      (COND ((f= NARGS 2)
	     (SETQ MODULUS (ARG 2))
	     (IF (OR (NOT (INTEGERP MODULUS)) (ZEROP MODULUS))
		 (MERROR "Improper value for MODULUS:~%~M" MODULUS))))
      (IF (MINUSP MODULUS) (SETQ MODULUS (ABS MODULUS)))
      (MOD1 (ARG 1))))

(DEFUN MOD1 (E)
 (IF (MBAGP E) (CONS (CAR E) (MAPCAR 'MOD1 (CDR E)))
     (LET (FORMFLAG)
       (NEWVAR E)
       (SETQ FORMFLAG ($RATP E) E (RATREP* E))
       (SETQ E (CONS (CAR E) (RATREDUCE (PMOD (CADR E)) (PMOD (CDDR E)))))
       (COND (FORMFLAG E) (T (RATDISREP E))))))

(DEFMFUN $DIVIDE NARGS
  (PROG (X Y H VARLIST TT TY FORMFLAG $RATFAC)
	(IF (f< NARGS 2) (MERROR "DIVIDE needs at least two arguments."))
	(SETQ X (ARG 1))
	(IF (AND ($RATP X) (SETQ FORMFLAG T) (INTEGERP (CADR X)) (EQUAL (CDDR X) 1))
	    (SETQ X (CADR X)))
	(SETQ Y (ARG 2))
	(IF (AND ($RATP Y) (SETQ FORMFLAG T) (INTEGERP (CADR Y)) (EQUAL (CDDR Y) 1))
	    (SETQ Y (CADR Y)))
	(IF (AND (INTEGERP X) (INTEGERP Y))
	    (RETURN (LIST '(MLIST) (*QUO X Y) (REMAINDER X Y))))
	(SETQ VARLIST (CDDR (LISTIFY NARGS)))
	(MAPC #'NEWVAR (REVERSE (CDR $RATVARS)))
	(NEWVAR Y)
	(NEWVAR X)
	(SETQ X (RATREP* X))
	(SETQ H (CAR X))
	(SETQ X (CDR X))
	(SETQ Y (CDR (RATREP* Y)))
	(COND ((AND (EQN (SETQ TT (CDR X)) 1) (EQN (CDR Y) 1)) 
	       (SETQ X (PDIVIDE (CAR X) (CAR Y))))
	      (T (SETQ TY (CDR Y))
		 (SETQ X (PTIMES (CAR X) (CDR Y)))
		 (SETQ X (PDIVIDE X (CAR Y))) 
		 (SETQ X (LIST
			  (RATQU (CAR X) TT)
			  (RATQU (CADR X) (PTIMES TT TY))))))
	(SETQ H (LIST (QUOTE (MLIST)) (CONS H (CAR X)) (CONS H (CADR X))))
	(RETURN (IF FORMFLAG H ($TOTALDISREP H)))))

(DEFMFUN $QUOTIENT NARGS (CADR (APPLY '$DIVIDE (LISTIFY NARGS))))

(DEFMFUN $REMAINDER NARGS (CADDR (APPLY '$DIVIDE (LISTIFY NARGS))))


(DEFMFUN $GCD NARGS
  (PROG (X Y H VARLIST GENVAR $KEEPFLOAT FORMFLAG)
	(IF (f< NARGS 2) (MERROR "GCD needs 2 arguments"))
	(SETQ FORMFLAG ($RATP (SETQ X (ARG 1))))
	(SETQ Y (ARG 2))
	(AND ($RATP Y) (SETQ FORMFLAG T))
	(SETQ VARLIST (CDDR (LISTIFY NARGS)))
	(DOLIST (V VARLIST) (IF (NUMBERP V) (IMPROPER-ARG-ERR V '$GCD)))
	(NEWVAR X)
	(NEWVAR Y)
	(WHEN (AND ($RATP X) ($RATP Y) (EQUAL (CAR X) (CAR Y)))
	      (SETQ GENVAR (CAR (LAST (CAR X))) H (CAR X) X (CDR X) Y (CDR Y))
	      (GO ON))
	(SETQ X (RATREP* X))
	(SETQ H (CAR X))
	(SETQ X (CDR X))
	(SETQ Y (CDR (RATREP* Y)))
ON	(SETQ X (CONS (PGCD (CAR X) (CAR Y)) (PLCM (CDR X) (CDR Y))))
	(SETQ H (CONS H X))
	(RETURN (IF FORMFLAG H (RATDISREP H)))))

(DEFMFUN $CONTENT NARGS
	(PROG (X Y H VARLIST FORMFLAG)
	      (SETQ FORMFLAG ($RATP (SETQ X (ARG 1))))
	      (SETQ VARLIST (CDR (LISTIFY NARGS)))
	      (NEWVAR X)
	      (DESETQ (H X . Y) (RATREP* X))
	      (unless (atom x)
		;; (CAR X) => gensym corresponding to apparent main var.
		;; MAIN-GENVAR => gensym corresponding to the genuine main var.
		(let ((main-genvar (nth (1- (length varlist)) genvar)))
		  (unless (eq (car x) main-genvar)
		    (setq x `(,main-genvar 0 ,x)))))
	      (SETQ X (RCONTENT X)
		    Y (CONS 1 Y))
	      (SETQ H (LIST '(MLIST)
			    (CONS H (RATTIMES (CAR X) Y NIL))
			    (CONS H (CADR X))))
	      (RETURN (IF FORMFLAG H ($TOTALDISREP H)))))

(DEFMFUN PGET (GEN) (CONS GEN '(1 1)))

(DEFUN M$EXP? (X) (AND (MEXPTP X) (EQ (CADR X) '$%E)))

(DEFUN ALGP ($X) (ALGPCHK $X NIL))

(DEFUN ALGPGET ($X) (ALGPCHK $X T))

(DEFUN ALGPCHK ($X MPFLAG &AUX TEMP)
  (COND ((EQ $X '$%I) '(2 -1))
	((EQ $X '$%PHI) '(2 1 1 -1 0 -1))
	((RADFUNP $X NIL)
	 (IF (NOT MPFLAG) T
	   (LET ((R (PREP1 (CADR $X))))
	     (COND ((ONEP1 (CDR R))		;INTEGRAL ALG. QUANT.?
		    (LIST (CADDR (CADDR $X))
			  (CAR R)))
		   (*RATSIMP* (SETQ RADLIST (CONS $X RADLIST)) NIL)))))
	((NOT $ALGEBRAIC) NIL)
	((AND (M$EXP? $X) (MTIMESP (SETQ TEMP (CADDR $X)))
	      (EQUAL (CDDR TEMP) '($%I $%PI))
	      (RATNUMP (SETQ TEMP (CADR TEMP))))
	 (IF MPFLAG (PRIMCYCLO (f* 2 (CADDR TEMP))) T))
	((NOT MPFLAG) (ASSOLIKE $X TELLRATLIST))
	((SETQ TEMP (COPY1 (ASSOLIKE $X TELLRATLIST)))
	 (DO ((P TEMP (CDDR P))) ((NULL P))
	     (RPLACA (CDR P) (CAR (PREP1 (CADR P)))))
	 (SETQ TEMP
	       (COND ((PTZEROP (PT-RED TEMP)) (LIST (PT-LE TEMP) (PZERO)))
		     ((ZEROP (PT-LE (PT-RED TEMP)))
		      (LIST (PT-LE TEMP) (PMINUS (PT-LC (PT-RED TEMP)))))
		     (T TEMP)))
	 (IF (AND (f= (PT-LE TEMP) 1) (SETQ $X (ASSOL $X GENPAIRS)))
	     (RPLACD $X (CONS (CADR TEMP) 1)))
	 TEMP)))

(DEFUN RADFUNP (X FUNCFLAG)	;FUNCFLAG -> TEST FOR ALG FUNCTION NOT NUMBER
       (COND ((ATOM X) NIL)
	     ((NOT (EQ (CAAR X) 'MEXPT)) NIL)
	     ((NOT (RATNUMP (CADDR X))) NIL)
	     (FUNCFLAG (NOT (NUMBERP (CADR X))))
	     (T T)))

(DEFMFUN RATSETUP (VL GL) (RATSETUP1 VL GL) (RATSETUP2 VL GL))

(DEFUN RATSETUP1 (VL GL)
  (AND $RATWTLVL
       (MAPC #'(LAMBDA (V G) 
	        (SETQ V (ASSOLIKE V *RATWEIGHTS))
	        (IF V (PUTPROP G V '$RATWEIGHT) (REMPROP G '$RATWEIGHT)))
	     VL GL)))

(DEFUN RATSETUP2 (VL GL)
  (WHEN $ALGEBRAIC
	(MAPC #'(LAMBDA (G) (REMPROP G 'ALGORD)) GL)
	(MAPL #'(LAMBDA (V LG)
		(COND ((SETQ V (ALGPGET (CAR V)))
		       (ALGORDSET V LG) (PUTPROP (CAR LG) V 'TELLRAT))
		      (T (REMPROP (CAR LG) 'TELLRAT))))
	     VL GL))
  (AND $RATFAC (LET ($RATFAC)
		    (MAPC #'(LAMBDA (V G) 
			     (IF (MPLUSP V)
				 (PUTPROP G (CAR (PREP1 V)) 'UNHACKED)
				 (REMPROP G 'UNHACKED)))
			  VL GL))))

(defun porder (p) (IF (pcoefp p) 0 (valget (car p))))

(defun algordset (x gl)
       (do ((p x (cddr p))
	    (mv 0))
	   ((null p)
	    (do ((l gl (cdr l))) ((or (null l) (f> (valget (car l)) mv)))
		(putprop (car l) t 'algord)))
	   (setq mv (max mv (porder (cadr p))))))

 
#+cl
(defun gensym-readable (name &aux #+lispm
			     (default-cons-area working-storage-area ))
  (cond ((symbolp name)(gensym (string-trim "$" (string name))))
	(t  (setq name (aformat nil "~:M" name))
	    (cond (name (gensym name))
		  (t (gensym))))))

#+cl
(defun orderpointer (l)
  (sloop for v in l
	for i below (f- (length l) (length genvar))
	collecting  (gensym-readable v) into tem
	finally (setq genvar (nconc tem genvar)) (return (prenumber genvar 1))))
#-cl
(DEFUN ORDERPOINTER (L)
       (CREATSYM (f- (LENGTH L) (LENGTH GENVAR)))
       (PRENUMBER GENVAR 1))

(DEFUN CREATSYM (N)
  #+lispm (let ((default-cons-area working-storage-area))
	    (COND ((f> N 0) (SETQ GENVAR (CONS (GENSYM) GENVAR))
		   (CREATSYM (SUB1 N)))))
  #-lispm   (COND ((f> N 0) (SETQ GENVAR (CONS (GENSYM) GENVAR))
		   (CREATSYM (SUB1 N)))))

(DEFUN PRENUMBER (V N)
       (DO ((VL V (CDR VL))
	    (I N (f1+ I)))
	   ((NULL VL) NIL)
	   (SET (CAR VL) I)))

(DEFUN RGET (GENV)
       (CONS (IF (AND $RATWTLVL
		      (OR (fixnump $ratwtlvl) 
			  (MERROR "Illegal value for RATWTLVL:~%~M" $RATWTLVL))
		      (f> (OR (GET GENV '$RATWEIGHT) -1) $RATWTLVL))
		 (PZERO)
		 (PGET GENV))
	     1))

(DEFMFUN RATREP (X VARL) (SETQ VARLIST VARL) (RATREP* X))

(DEFMFUN RATREP* (X) 
       (LET (GENPAIRS)
	    (ORDERPOINTER VARLIST)
	    (RATSETUP1 VARLIST GENVAR)
	    (MAPC #'(LAMBDA (Y Z) (PUSH (CONS Y (RGET Z)) GENPAIRS))
		  VARLIST GENVAR)
	    (RATSETUP2 VARLIST GENVAR)
	    (XCONS (PREP1 X)			      ; PREP1 changes VARLIST
		   (LIST* 'MRAT 'SIMP VARLIST GENVAR  ;    when $RATFAC is T.
			  (IF (AND (NOT (ATOM X)) (MEMQ 'IRREDUCIBLE (CDAR X)))
			      '(IRREDUCIBLE))))))
 
(DEFVAR *WITHINRATF* NIL)

(DEFMFUN RATF (L)
 (PROG (U *WITHINRATF*)
       (SETQ *WITHINRATF* T)
       (WHEN (EQ '%% (CATCH 'RATF (NEWVAR L)))
	     (SETQ *WITHINRATF* NIL) (RETURN (SRF L)))
       (SETQ U (CATCH 'RATF (RATREP* L)))  ; for truncation routines
       (RETURN (OR U (PROG2 (SETQ *WITHINRATF* NIL) (SRF L))))))


(DEFUN PREP1 (X &AUX TEMP) 
       (COND ((FLOATP X)
	      (COND ($KEEPFLOAT (CONS X 1.0)) ((PREPFLOAT X))))
	     ((INTEGERP X) (CONS (CMOD X) 1))
	     #+cl ((rationalp x)
		      (cond ((null modulus)(cons  (numerator x) (denominator x)))
			    (t (cquotient (numerator x) (denominator x)))))
	     ((ATOM X)(COND ((ASSOLIKE X GENPAIRS)) (T (NEWSYM X))))
	     ((AND $RATFAC (ASSOLIKE X GENPAIRS)))
	     ((EQ (CAAR X) 'MPLUS)
	      (COND ($RATFAC
		     (SETQ X (MAPCAR 'PREP1 (CDR X)))
		     (COND ((ANDMAPC 'FRPOLY? X)
			    (CONS (MFACPPLUS (MAPL #'(lambda (X)
						      (RPLACA X (CAAR X)))
						  X)) 
				  1))
			   (T (DO ((A (CAR X) (FACRPLUS A (CAR L)))
				   (L (CDR X) (CDR L)))
				  ((NULL L) A)))))
		    (T (DO ((A (PREP1 (CADR X)) (RATPLUS A (PREP1 (CAR L))))
			    (L (CDDR X) (CDR L)))
			   ((NULL L) A)))))
	     ((EQ (CAAR X) 'MTIMES)
	      (DO ((A (SAVEFACTORS (PREP1 (CADR X)))
		      (RATTIMES A (SAVEFACTORS (PREP1 (CAR L))) SW))
		   (L (CDDR X) (CDR L))
		   (SW (NOT (AND $NOREPEAT (MEMQ 'RATSIMP (CDAR X))))))
		  ((NULL L) A)))
	     ((EQ (CAAR X) 'MEXPT)
	      (NEWVARMEXPT X (CADDR X) T))
	     ((EQ (CAAR X) 'MQUOTIENT)
	      (RATQUOTIENT (SAVEFACTORS (PREP1 (CADR X)))
			   (SAVEFACTORS (PREP1 (CADDR X)))))
	     ((EQ (CAAR X) 'MMINUS)
	      (RATMINUS (PREP1 (CADR X))))
	     ((EQ (CAAR X) 'RAT)
	      (COND (MODULUS (CONS (CQUOTIENT (CMOD (CADR X)) (CMOD (CADDR X))) 1))
		    (T (CONS (CADR X) (CADDR X)))))
	     ((EQ (CAAR X) 'BIGFLOAT)(BIGFLOAT2RAT X))
	     ((EQ (CAAR X) 'MRAT)
	      (COND ((AND *WITHINRATF* (MEMQ 'TRUNC (CAR X)))
		     (THROW 'RATF NIL))
		    ((CATCH 'COMPATVL
		       (PROGN (SETQ TEMP (COMPATVARL (CADDAR X)
						     VARLIST
						     (CADDDR (CAR X))
						     GENVAR))
			      T))
		     (COND ((MEMQ 'TRUNC (CAR X))
			    (CDR ($TAYTORAT X)))
			   ((AND (NOT $KEEPFLOAT)
				 (OR (PFLOATP (CADR X)) (PFLOATP (CDDR X))))
			    (CDR (RATREP* ($RATDISREP X))))
			   ((SUBLIS TEMP (CDR X)))))
		    (T (CDR (RATREP* ($RATDISREP X))))))
	     ((ASSOLIKE X GENPAIRS))
	     (T (SETQ X (LITTLEFR1 X))
		(COND ((ASSOLIKE X GENPAIRS))
		      (T (NEWSYM X))))))


(DEFUN PUTONVLIST (X)
       (PUSH X VLIST)
       (AND $ALGEBRAIC
	    (SETQ X (ASSOLIKE X TELLRATLIST))
	    (MAPC 'NEWVAR1 X)))

(SETQ EXPSUMSPLIT T)			   ;CONTROLS SPLITTING SUMS IN EXPONS

(DEFUN NEWVARMEXPT (X E FLAG) 

       ;; WHEN FLAG IS T, CALL RETURNS RATFORM
       (PROG (TOPEXP) 
	     (COND ((AND (INTEGERP E) (NOT FLAG))
		    (RETURN (NEWVAR1 (CADR X))))

		   ;; THIS MAKES PROBLEMS FOR RISCH ((AND(NOT(INTEGERP
		   ;;E))(MEMQ 'RATSIMP (CDAR X))) (RETURN(SETQ VLIST
		   ;;(CONS X VLIST))))
		   )
	     (SETQ TOPEXP 1)
	TOP  (COND

	      ;; X=B^N FOR N A NUMBER
	      ((INTEGERP E)
	       (SETQ TOPEXP (TIMES TOPEXP E))
	       (SETQ X (CADR X)))
	      ((ATOM E) NIL)

	      ;; X=B^(P/Q) FOR P AND Q INTEGERS
	      ((EQ (CAAR E) 'RAT)
	       (COND ((OR (MINUSP (CADR E)) (GREATERP (CADR E) 1))
		      (SETQ TOPEXP (TIMES TOPEXP (CADR E)))
		      (SETQ X (LIST '(MEXPT)
				    (CADR X)
				    (LIST '(RAT) 1 (CADDR E))))))
	       (COND ((OR FLAG (NUMBERP (CADR X)) ))
		     (*RATSIMP*
		      (COND ((MEMALIKE X RADLIST) (RETURN NIL))
			    (T (SETQ RADLIST (CONS X RADLIST))
			       (RETURN (NEWVAR1 (CADR X))))) )
		     ($ALGEBRAIC (NEWVAR1 (CADR X)))))
	      ;; X=B^(A*C)
	      ((EQ (CAAR E) 'MTIMES)
	       (COND
		((OR 

		     ;; X=B^(N *C)
		     (AND (ATOM (CADR E))
			  (INTEGERP (CADR E))
			  (SETQ TOPEXP (TIMES TOPEXP (CADR E)))
			  (SETQ E (CDDR E)))

		     ;; X=B^(P/Q *C)
		     (AND (NOT (ATOM (CADR E)))
			  (EQ (CAAADR E) 'RAT)
			  (NOT (EQUAL 1 (CADADR E)))
			  (SETQ TOPEXP (TIMES TOPEXP (CADADR E)))
			  (SETQ E (CONS (LIST '(RAT)
					      1
					      (CADDR (CADR E)))
					(CDDR E)))))
		 (SETQ X
		       (LIST '(MEXPT)
			     (CADR X)
			     (SETQ E (SIMPLIFY (CONS '(MTIMES)
						      E)))))
		 (GO TOP))))

	      ;; X=B^(A+C)
	      ((AND (EQ (CAAR E) 'MPLUS) EXPSUMSPLIT)	;SWITCH CONTROLS
	       (SETQ					;SPLITTING EXPONENT
		X					;SUMS
		(CONS
		 '(MTIMES)
		 (MAPCAR 
		  (FUNCTION (LAMBDA (LL) 
				    (LIST '(MEXPT)
					  (CADR X)
					  (SIMPLIFY (LIST '(MTIMES)
							   TOPEXP
							   LL)))))
		  (CDR E))))
	       (COND (FLAG (RETURN (PREP1 X)))
		     (T (RETURN (NEWVAR1 X))))))
	     (COND (FLAG NIL)
		   ((EQUAL 1 TOPEXP)
		    (COND ((OR (ATOM X)
			       (NOT (EQ (CAAR X) 'MEXPT)))
			   (NEWVAR1 X))
			  ((OR (MEMALIKE X VARLIST) (MEMALIKE X VLIST))
			   NIL)
			  (T (COND ((OR (ATOM X) (NULL *FNEWVARSW))
				    (PUTONVLIST X))
				   (T (SETQ X (LITTLEFR1 X))
				      (MAPC (FUNCTION NEWVAR1)
					    (CDR X))
				     (OR (MEMALIKE X VLIST)
					 (MEMALIKE X VARLIST)
					 (PUTONVLIST X)))))))
		   (T (NEWVAR1 X)))
	     (RETURN
	      (COND
	       ((NULL FLAG) NIL)
	       ((EQUAL 1 TOPEXP)
		(COND
		 ((AND (NOT (ATOM X)) (EQ (CAAR X) 'MEXPT))
		  (COND ((ASSOLIKE X GENPAIRS))
; *** SHOULD ONLY GET HERE IF CALLED FROM FR1. *FNEWVARSW=NIL
			(T (SETQ X (LITTLEFR1 X))
			 (COND ((ASSOLIKE X GENPAIRS))
			       (T (NEWSYM X))))))
		 (T (PREP1 X))))
	       (T (RATEXPT (PREP1 X) TOPEXP))))))

(DEFUN NEWVAR1 (X) 
       (COND ((NUMBERP X) NIL)
	     ((MEMALIKE X VARLIST) NIL)
	     ((MEMALIKE X VLIST) NIL)
	     ((ATOM X) (PUTONVLIST X))
	     ((MEMQ (CAAR X)
		    '(MPLUS MTIMES RAT MDIFFERENCE
			    MQUOTIENT MMINUS BIGFLOAT))
	      (MAPC (FUNCTION NEWVAR1) (CDR X)))
	     ((EQ (CAAR X) 'MEXPT)
	      (NEWVARMEXPT X (CADDR X) NIL))
	     ((EQ (CAAR X) 'MRAT)
	      (AND *WITHINRATF* (MEMQ 'TRUNC (CDDDAR X)) (THROW 'RATF '%%))
	      (COND ($RATFAC (MAPC 'NEWVAR3 (CADDAR X)))
		    (T (MAPC (FUNCTION NEWVAR1) (REVERSE (CADDAR X))))))
	     (T (COND (*FNEWVARSW (SETQ X (LITTLEFR1 X))
				  (MAPC (FUNCTION NEWVAR1)
					(CDR X))
				  (OR (MEMALIKE X VLIST)
				      (MEMALIKE X VARLIST)
				      (PUTONVLIST X)))
		      (T (PUTONVLIST X))))))

(DEFUN NEWVAR3 (X)
       (OR (MEMALIKE X VLIST)
	   (MEMALIKE X VARLIST)
	   (PUTONVLIST X)))
 


(DEFUN FR1 (X VARLIST)		;put radicands on initial varlist?
  (PROG (GENVAR $NOREPEAT *RATSIMP* RADLIST VLIST NVARLIST OVARLIST GENPAIRS)
	(NEWVAR1 X)
	(SETQ NVARLIST (MAPCAR #'FR-ARGS VLIST))
	(COND ((NOT *RATSIMP*)	;*ratsimp* not set for initial varlist
	       (SETQ VARLIST (NCONC (SORTGREAT VLIST) VARLIST))
	       (RETURN (RDIS (CDR (RATREP* X))))))
	(SETQ OVARLIST (NCONC VLIST VARLIST)
	      VLIST NIL)
	(MAPC (FUNCTION NEWVAR1) NVARLIST) ;*RATSIMP*=T PUTS RADICANDS ON VLIST
	(SETQ NVARLIST (NCONC NVARLIST VARLIST) ; RADICALS ON RADLIST
	      VARLIST (NCONC (SORTGREAT VLIST) (RADSORT RADLIST) VARLIST))
	(ORDERPOINTER VARLIST)
	(SETQ GENPAIRS
	      (MAPCAR (FUNCTION (LAMBDA (X Y) (CONS X (RGET Y))))
		      VARLIST GENVAR))
	(LET (($ALGEBRAIC $ALGEBRAIC) ($RATALGDENOM $RATALGDENOM) RADLIST)
	     (AND (NOT $ALGEBRAIC)
		  (ORMAPC (FUNCTION ALGPGET) VARLIST) ;NEEDS *RATSIMP*=T
		  (SETQ $ALGEBRAIC T $RATALGDENOM NIL))
	     (RATSETUP VARLIST GENVAR)
	     (SETQ GENPAIRS
		   (MAPCAR (FUNCTION (LAMBDA (X Y) (CONS X (PREP1 Y))))
			   OVARLIST NVARLIST))
	     (SETQ X (RDIS (PREP1 X)))
	     (COND (RADLIST				;rational radicands
		    (SETQ *RATSIMP* NIL)
		    (SETQ X (RATSIMP (SIMPLIFY X) NIL NIL)))))
	(RETURN X) ))

(DEFUN RATSIMP (X VARLIST GENVAR) ($RATDISREP (RATF X)))

(DEFUN LITTLEFR1 (X) 
       (CONS (REMQ 'SIMP (CAR X))
	     (MAPFR1 (CDR X) NIL)))

;;IF T RATSIMP FACTORS RADICANDS AND LOGANDS
(DEFMVAR FR-FACTOR NIL)				       

(DEFUN FR-ARGS (X)	;SIMP (A/B)^N TO A^N/B^N ?
  (COND ((ATOM X)
	 (WHEN (EQ X '$%I) (SETQ *RATSIMP* T)) ;indicates algebraic present
	 X)
	(T (SETQ *RATSIMP* T)	;FLAG TO CHANGED ELMT.
	   (SIMPLIFY (ZP (CONS (REMQ 'SIMP (CAR X))
			       (IF (OR (RADFUNP X NIL) (EQ (CAAR X) '%LOG))
				   (CONS (IF FR-FACTOR (FACTOR (CADR X))
					     (FR1 (CADR X) VARLIST))
					 (CDDR X))
				   (LET (MODULUS)
					(MAPFR1 (CDR X) VARLIST)))))))))

;(DEFUN ZP (X)						;SIMPLIFY MEXPT'S &
;       (COND ((ATOM X) X)				;RATEXPAND EXPONENT
;	     ((NOT (EQ (CAAR X) 'MEXPT)) X)
;	     ((EQUAL 0 (CADDR X)) 1)
;	     ((EQUAL 0 (CADR X)) 0)
;	     ((EQUAL 1 (CADR X)) 1)
;	     ((ATOM (CADDR X)) X)
;	     (T (LIST (CAR X) (CADR X)
;		      ((LAMBDA (VARLIST *RATSIMP*) ($RATEXPAND (CADDR X)))
;		       VARLIST NIL)))))

(DEFUN ZP (X)
       (IF (AND (MEXPTP X) (NOT (ATOM (CADDR X))))
	   (LIST (CAR X) (CADR X)
		 (LET ((VARLIST VARLIST) *RATSIMP*)
		      ($RATEXPAND (CADDR X))))
	   X))


(DEFUN NEWSYM (E)
  (PROG (G P)
	(COND ((SETQ G (ASSOLIKE E GENPAIRS))
	       (RETURN G)))
	#-cl
	(SETQ G (GENSYM))
	#+cl
	(SETQ G (gensym-readable e))
	(PUTPROP G E 'DISREP)
	(PUSH E VARLIST)
	(PUSH (CONS E (RGET G)) GENPAIRS)
	(VALPUT G (IF GENVAR (SUB1 (VALGET (CAR GENVAR))) 1))
	(PUSH G GENVAR)
	(COND ((SETQ P (AND $ALGEBRAIC (ALGPGET E)))
	       (ALGORDSET P GENVAR)
	       (PUTPROP G P 'TELLRAT)))
	(RETURN (RGET G))))


;;  Any program which calls RATF on
;;  a floating point number but does not wish to see "RAT replaced ..."
;;  message, must bind $RATPRINT to NIL.

(DEFMVAR $RATPRINT T)

(DEFMVAR $RATEPSILON #-Franz 2.0E-8 
		     #+(and Franz VAX) (expt 2.0 -56.)
		     #+(and Franz 68k) (expt 2.0 -52.))
				;; Some 68k stuff has a shorter significand.
;; This control of conversion from float to rational appears to be explained
;; nowhere. - RJF

(DEFMFUN MAXIMA-RATIONALIZE (X)
  (COND ((NOT (FLOATP X)) X)
	((< X 0.0) (SETQ X (RATION1 (*$ -1.0 X)))
		   (RPLACA X (TIMES -1 (CAR X))))
	(T (RATION1 X))))

; the following code patches the fact that fix(float(bignum))
; sometimes fails in franz.
#+Franz
(defun ration1 (x)
 ((lambda (rateps)
       (or (and (zerop x) (cons 0 1))
	   (prog (y a)
		 (return (do ((xx x (setq y (//$ 1.0 (-$ xx (float a)))))
			      (num (setq a (newfix x)) 
				   (plus (times (setq a (newfix y)) num) onum))
			      (den 1 (plus (times a den) oden))
			      (onum 1 num)
			      (oden 0 den))
			     ((and (not (zerop den))
				   (< (abs (//$ (-$ x (//$ (float num) (float den)))
						x))
					  rateps))
			      (cons num den))  )))))
 (cond ((not (floatp $ratepsilon)) ($float $ratepsilon)) (t $ratepsilon))))

#+Franz
(defun newfix (x)
  (cond ((greaterp (abs x) two30f)
	 (times two30 (newfix (quotient x two30f))))
	(t (fix x))))

#-Franz
(DEFUN RATION1 (X)
 (let ((rateps
	(COND ((NOT (FLOATP $RATEPSILON))
	       ($FLOAT $RATEPSILON)) (T $RATEPSILON))))
   (OR (AND (ZEROP X) (CONS 0 1))
       (PROG
	(Y A)
	(RETURN
	 (DO ((XX X (SETQ Y (/ 1.0 (- XX (FLOAT A x)))))
	      (NUM (SETQ A (FIX X)) (PLUS (TIMES (SETQ A (FIX Y)) NUM) ONUM))
	      (DEN 1 (PLUS (TIMES A DEN) ODEN))
	      (ONUM 1 NUM)
	      (ODEN 0 DEN))
	     ((AND (NOT (ZEROP DEN))
		   (NOT (> (ABS
			    (/
			     (- X
				(/ (FLOAT NUM x)
				   (FLOAT DEN x)))
			     X))
			   RATEPS)))
	      (CONS NUM DEN))))))))

(DEFUN PREPFLOAT (F)
 (COND ((< (ABS F) 1.0E-37) (SETQ F 0.0)))   ;changed 38 to 37 --wfs
 (COND (MODULUS (MERROR "Floating point meaningless unless MODULUS = FALSE"))
       ($RATPRINT (MTELL "~&RAT replaced ~A by" F)))
 (SETQ F (MAXIMA-RATIONALIZE F))
 (IF $RATPRINT (MTELL " ~A//~A = ~A~%"  (CAR F) (CDR F)
		      (FPCOFRAT1 (CAR F) (CDR F))))
 F)


(DEFUN PDISREP (P)
       (COND ((ATOM P) P)
	     (T (PDISREP+ (PDISREP2 (CDR P) (GET (CAR P) 'DISREP))))))

(DEFUN PDISREP! (N VAR)
       (COND ((ZEROP N) 1)
	     ((EQN N 1) (COND ((ATOM VAR) VAR)
			      ((OR (EQ (CAAR VAR) 'MTIMES)
				   (EQ (CAAR VAR) 'MPLUS))
			       (COPY1 VAR))
			      (T VAR)))
	     (T (LIST '(MEXPT RATSIMP) VAR N))))

(DEFUN PDISREP+ (P)
       (COND ((NULL (CDR P)) (CAR P))
	     (T (LET ((A (LAST P)))
		  (COND ((MPLUSP (CAR A))
			 (RPLACD A (CDDAR A))
			 (RPLACA A (CADAR A))))
		  (CONS '(MPLUS RATSIMP) P)))))
	 
(DEFUN PDISREP* (A B)
  (COND ((EQN A 1) B)
	((EQN B 1) A)
	(T (CONS '(MTIMES RATSIMP)
		 (NCONC (PDISREP*CHK A) (PDISREP*CHK B))))))

(DEFUN PDISREP*CHK (A)
  (IF (MTIMESP A) (CDR A) (NCONS A)))

(DEFUN PDISREP2 (P VAR)
       (COND ((NULL P) NIL)
	     ($RATEXPAND (PDISREP2EXPAND P VAR))
	     (T (DO ((L () (CONS (PDISREP* (PDISREP (CADR P))
					   (PDISREP! (CAR P) VAR))
				 L))
		     (P P (CDDR P)))
		    ((NULL P)
		     (NREVERSE L))))))

;; IF $RATEXPAND IS TRUE, (X+1)*(Y+1) WILL DISPLAY AS
;; XY + Y + X + 1  OTHERWISE, AS (X+1)Y + X + 1
(DEFMVAR $RATEXPAND NIL)

(DEFMFUN $RATEXPAND (X)
 (COND ((MBAGP X) (CONS (CAR X) (MAPCAR '$RATEXPAND (CDR X))))
       (T ((LAMBDA ($RATEXPAND $RATFAC) (RATDISREP (RATF X))) T NIL))))
	 
(DEFUN PDISREP*EXPAND (A B)
  (COND ((EQN A 1) (LIST B))
	((EQN B 1) (LIST A))
	((OR (ATOM A) (NOT (EQ (CAAR A) 'MPLUS)))
	 (LIST (CONS (QUOTE (MTIMES RATSIMP))
		     (NCONC (PDISREP*CHK A) (PDISREP*CHK B)))))
	(T (MAPCAR #'(LAMBDA (Z) (IF (EQN Z 1) B
				     (CONS '(MTIMES RATSIMP)
					   (NCONC (PDISREP*CHK Z)
						  (PDISREP*CHK B)))))
		   (CDR A)))))
	 
(DEFUN PDISREP2EXPAND (P VAR)
  (COND ((NULL P) NIL)
	(T (NCONC (PDISREP*EXPAND (PDISREP (CADR P))
				  (PDISREP! (CAR P) VAR))
		  (PDISREP2EXPAND (CDDR P) VAR)))))


(DEFMVAR $RATDENOMDIVIDE T)

(DEFMFUN $RATDISREP (X)
  (COND ((NOT ($RATP X)) X)
	(T (SETQ X (RATDISREPD X))
	   (IF (AND (NOT (ATOM X)) (MEMQ 'TRUNC (CDAR X)))
	       (CONS (DELQ 'TRUNC (copy-top-level (CAR X)) 1) (CDR X))
	       X))))

; RATDISREPD is needed by DISPLA. - JPG
(DEFUN RATDISREPD (X)
  (MAPC #'(LAMBDA (Y Z) (PUTPROP Y Z (QUOTE DISREP)))
	(CADDDR (CAR X))
	(CADDAR X))
  (LET ((VARLIST (CADDAR X)))
       (IF (MEMQ 'TRUNC (CAR X)) (SRDISREP X) (CDISREP (CDR X)))))

(DEFUN CDISREP (X &AUX N D SIGN)
  (COND ((PZEROP (CAR X)) 0)
	((OR (EQN 1 (CDR X)) (FLOATP (CDR X))) (PDISREP (CAR X)))
	(T (SETQ SIGN (COND ($RATEXPAND (SETQ N (PDISREP (CAR X))) 1)
			    ((PMINUSP (CAR X))
			     (SETQ N (PDISREP (PMINUS (CAR X)))) -1)
			    (T (SETQ N (PDISREP (CAR X))) 1)))
	   (SETQ D (PDISREP (CDR X)))
	   (COND ((AND (NUMBERP N) (NUMBERP D))
		  (LIST '(RAT) (TIMES SIGN N) D))
		 ((AND $RATDENOMDIVIDE $RATEXPAND
		       (NOT (ATOM N))
		       (EQ (CAAR N) 'MPLUS))
		  (FANCYDIS N D))
		 ((NUMBERP D)
		  (LIST '(MTIMES RATSIMP)
			(LIST '(RAT) SIGN D) N))
		 ((EQN SIGN -1) 
		  (CONS '(MTIMES RATSIMP)
			(COND ((NUMBERP N)
			       (LIST (TIMES N -1)
				     (LIST '(MEXPT RATSIMP) D -1)))
			      (T (LIST SIGN N (LIST '(MEXPT RATSIMP) D -1))))))
		 ((EQN N 1)
		  (LIST '(MEXPT RATSIMP) D -1))
		 (T (LIST '(MTIMES RATSIMP) N
			  (LIST '(MEXPT RATSIMP) D -1)))))))
 

;; FANCYDIS GOES THROUGH EACH TERM AND DIVIDES IT BY THE DENOMINATOR.

(DEFUN FANCYDIS (N D)
  (SETQ D (SIMPLIFY (LIST '(MEXPT) D -1)))
  (SIMPLIFY (CONS '(MPLUS)
		  (MAPCAR #'(LAMBDA (Z)
				    ($RATDISREP (RATF (LIST '(MTIMES) Z D))))
			  (CDR N)))))


(DEFUN COMPATVARL (A B C D)
       (COND ((NULL A) NIL)
	     ((OR (NULL B) (NULL C) (NULL D)) (THROW 'COMPATVL NIL))
	     ((ALIKE1 (CAR A) (CAR B))
	      (SETQ A (COMPATVARL (CDR A) (CDR B) (CDR C) (CDR D)))
	      (COND ((EQ (CAR C) (CAR D)) A)
		    (T (CONS (CONS (CAR C) (CAR D)) A))))
	     (T (COMPATVARL A (CDR B) C (CDR D)))))

(DEFUN NEWVAR (L &AUX VLIST)
  (NEWVAR1 L)
  (SETQ VARLIST (NCONC (SORTGREAT VLIST) VARLIST)))

(DEFUN SORTGREAT (L) (AND L (NREVERSE (SORT L 'GREAT))))

(DEFUN FNEWVAR (L &AUX (*FNEWVARSW T)) (NEWVAR L))

(DEFUN NESTLEV (EXP)
       (COND ((ATOM EXP) 0)
	     (T (DO ((M (NESTLEV (CADR EXP)) (MAX M (NESTLEV (CAR L))))
		     (L (CDDR EXP) (CDR L)))
		    ((NULL L) (f1+ M))))))

(DEFUN RADSORT (L)
  (SORT L #'(LAMBDA (A B)
	      ((LAMBDA (NA NB)
		 (COND ((< NA NB) T)
		       ((> NA NB) NIL)
		       (T (GREAT B A))))
	       (NESTLEV A) (NESTLEV B)))))

;;	THIS IS THE END OF THE NEW RATIONAL FUNCTION PACKAGE PART 5
;;	IT INCLUDES THE CONVERSION AND TOP-LEVEL ROUTINES USED
;;	BY THE REST OF THE FUNCTIONS.

