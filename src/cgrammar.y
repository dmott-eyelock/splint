/*;-*-C-*-;
** Copyright (c) Massachusetts Institute of Technology 1994-1998.
**          All Rights Reserved.
**          Unpublished rights reserved under the copyright laws of
**          the United States.
**
** THIS MATERIAL IS PROVIDED AS IS, WITH ABSOLUTELY NO WARRANTY EXPRESSED
** OR IMPLIED.  ANY USE IS AT YOUR OWN RISK.
**
** This code is distributed freely and may be used freely under the 
** following conditions:
**
**     1. This notice may not be removed or altered.
**
**     2. Works derived from this code are not distributed for
**        commercial gain without explicit permission from MIT 
**        (for permission contact lclint-request@sds.lcs.mit.edu).
*/
%{
/*
**
** cgrammar.y
**
** Yacc/Bison grammar for extended ANSI C used by LCLint.
**
** original grammar by Nate Osgood ---
**    hacrat@catfish.lcs.mit.edu Mon Jun 14 13:06:32 1993
**
** changes for LCLint --- handle typedef names correctly
** fix struct/union parsing bug (empty struct is accepted)
** add productions to handle macros --- require
** error correction --- main source of conflicts in grammar.
** need to process initializations sequentially, L->R
**
** production names are cryptic, so more productions fit on one line
**
** conflicts:  87 shift/reduce, 18 reduce/reduce
** most of these are due to handling macros
** a few are due to handling type expressions
*/

/*@=allmacros@*/

extern int yylex ();
extern void swallowMacro (void);
extern void yyerror (char *);

# include "lclintMacros.nf"
# include "basic.h"
# include "cgrammar.h"
# include "exprChecks.h"

/*@-allmacros@*/
/*@-matchfields@*/

# define SHOWCSYM FALSE

/*
** This is necessary, or else when the bison-generated code #include's malloc.h,
** there will be a parse error.
**
** Unfortunately, it means the error checking on malloc, etc. is lost for allocations
** in bison-generated files under Win32.
*/

# ifdef WIN32
# undef malloc
# undef calloc
# undef realloc
# endif

%}

%union
{
  lltok tok;
  int count;
  qual typequal;
  qualList tquallist;
  ctype ctyp;
  /*@dependent@*/ sRef sr;
  /*@only@*/ sRef osr;

  /*@only@*/ functionClauseList funcclauselist;
  /*@only@*/ functionClause funcclause;  
  /*@only@*/ flagSpec flagspec;
  /*@only@*/ globalsClause globsclause;
  /*@only@*/ modifiesClause modsclause;
  /*@only@*/ warnClause warnclause;
  /*@only@*/ stateClause stateclause;

  /*@only@*/ sRefList srlist;
  /*@only@*/ globSet globset;
  /*@only@*/ qtype qtyp;
  /*@only@*/ cstring cname;
  /*@observer@*/ annotationInfo annotation;
  /*@only@*/ idDecl ntyp;
  /*@only@*/ idDeclList ntyplist;
  /*@only@*/ uentryList flist;
  /*@owned@*/ uentryList entrylist;
  /*@observer@*/ /*@dependent@*/ uentry entry;
  /*@only@*/ uentry oentry;
  /*@only@*/ exprNode expr;
  /*@only@*/ enumNameList enumnamelist;
  /*@only@*/ exprNodeList alist;
  /*@only@*/ sRefSet srset; 
  /*@only@*/ cstringList cstringlist;
  /*drl
    added 1/19/2001
  */
  constraint con;
  constraintList conL;
  constraintExpr conE;
  /* drl */  
}

/* standard C tokens */

%token <tok> BADTOK SKIPTOK
%token <tok> CTOK_ELIPSIS CASE DEFAULT CIF CELSE SWITCH WHILE DO CFOR
%token <tok> GOTO CONTINUE BREAK RETURN
%token <tok> TSEMI TLBRACE TRBRACE TCOMMA TCOLON TASSIGN TLPAREN 
%token <tok> TRPAREN TLSQBR TRSQBR TDOT TAMPERSAND TEXCL TTILDE
%token <tok> TMINUS TPLUS TMULT TDIV TPERCENT TLT TGT TCIRC TBAR TQUEST
%token <tok> CSIZEOF CALIGNOF ARROW_OP CTYPEDEF COFFSETOF
%token <tok> INC_OP DEC_OP LEFT_OP RIGHT_OP
%token <tok> LE_OP GE_OP EQ_OP NE_OP AND_OP OR_OP
%token <tok> MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN SUB_ASSIGN
%token <tok> LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN XOR_ASSIGN OR_ASSIGN
%token <tok> CSTRUCT CUNION CENUM
%token <tok> VA_ARG VA_DCL
%token <tok> QWARN
%token <tok> QGLOBALS
%token <tok> QMODIFIES 
%token <tok> QNOMODS
%token <tok> QCONSTANT
%token <tok> QFUNCTION
%token <tok> QITER
%token <tok> QDEFINES 
%token <tok> QUSES
%token <tok> QALLOCATES
%token <tok> QSETS
%token <tok> QRELEASES 
%token <tok> QPRECLAUSE 
%token <tok> QPOSTCLAUSE 
%token <tok> QALT 
%token <tok> QUNDEF QKILLED
%token <tok> QENDMACRO

/* additional tokens introduced by lclint pre-processor. */
%token <tok> LLMACRO LLMACROITER LLMACROEND TENDMACRO

/* break comments: */
%token <tok> QSWITCHBREAK QLOOPBREAK QINNERBREAK QSAFEBREAK
%token <tok> QINNERCONTINUE

/* case fall-through marker: */
%token <tok> QFALLTHROUGH

/* used in scanner only */
%token <tok> QLINTNOTREACHED
%token <tok> QLINTFALLTHROUGH
%token <tok> QLINTFALLTHRU
%token <tok> QARGSUSED
%token <tok> QPRINTFLIKE QLINTPRINTFLIKE QSCANFLIKE QMESSAGELIKE

/* not-reached marker: (used like a label) */
%token <tok> QNOTREACHED

/* type qualifiers: */
%token <tok> QCONST QVOLATILE QINLINE QEXTENSION QEXTERN QSTATIC QAUTO QREGISTER
%token <tok> QOUT QIN QYIELD QONLY QTEMP QSHARED QREF QUNIQUE
%token <tok> QCHECKED QUNCHECKED QCHECKEDSTRICT QCHECKMOD
%token <tok> QKEEP QKEPT QPARTIAL QSPECIAL QOWNED QDEPENDENT
%token <tok> QRETURNED QEXPOSED QNULL QOBSERVER QISNULL 
%token <tok> QEXITS QMAYEXIT QNEVEREXIT QTRUEEXIT QFALSEEXIT
%token <tok> QLONG QSIGNED QUNSIGNED QSHORT QUNUSED QSEF QNOTNULL QRELNULL
%token <tok> QABSTRACT QCONCRETE QMUTABLE QIMMUTABLE
%token <tok> QTRUENULL QFALSENULL QEXTERNAL
%token <tok> QREFCOUNTED QREFS QNEWREF QTEMPREF QKILLREF QRELDEF
%token <ctyp> CGCHAR CBOOL CINT CGFLOAT CDOUBLE CVOID 
%token <tok> QANYTYPE QINTEGRALTYPE QUNSIGNEDINTEGRALTYPE QSIGNEDINTEGRALTYPE

%type <typequal> nullterminatedQualifier
%token <tok> QNULLTERMINATED
%token <tok> QSETBUFFERSIZE
%token <tok> QSETSTRINGLENGTH
%token <tok> QMAXSET
%token <tok> QMAXREAD
%token <tok> QTESTINRANGE

%token <tok> TCAND


/* identifiers, literals */
%token <entry> IDENTIFIER
%token <cname> NEW_IDENTIFIER TYPE_NAME_OR_ID 
%token <annotation> CANNOTATION
%token <expr> CCONSTANT
%type <cname> flagId
%type <flagspec> flagSpec
%type <expr> cconstantExpr
%token <entry> ITER_NAME ITER_ENDNAME 
%type <entry> endIter 

%type <funcclauselist> functionClauses functionClausesPlain
%type <funcclause> functionClause functionClause functionClausePlain

%type <globsclause> globalsClause globalsClausePlain
%type <modsclause> modifiesClause modifiesClausePlain nomodsClause
%type <warnclause> warnClause warnClausePlain
%type <funcclause> conditionClause conditionClausePlain
%type <stateclause> stateClause stateClausePlain

%type <sr> globId globIdListExpr
%type <globset> globIdList

%token <ctyp>  TYPE_NAME 
%type <cname> enumerator newId  /*@-varuse@*/ /* yacc declares yytranslate here */
%type <count> pointers /*@=varuse@*/

%type <tok> doHeader stateTag conditionTag startConditionClause
%type <typequal> exitsQualifier checkQualifier stateQualifier 
                 paramQualifier returnQualifier visibilityQualifier
                 typedefQualifier refcountQualifier definedQualifier

/* type construction */
%type <ctyp> abstractDecl abstractDeclBase optAbstractDeclBase
%type <ctyp> suSpc enumSpc typeName typeSpecifier

%type <ntyp> namedDecl namedDeclBase optNamedDecl
%type <ntyp> plainNamedDecl plainNamedDeclBase
%type <ntyp> structNamedDecl
%type <ntyp> fcnDefHdrAux plainFcn

%type <oentry> paramDecl 
%type <entry> id 

%type <ntyplist> structNamedDeclList

%type <entrylist> genericParamList paramTypeList paramList idList paramIdList
%type <alist> argumentExprList iterArgList
%type <alist> initList
%type <flist> structDeclList structDecl
%type <srset> locModifies modList specClauseList optSpecClauseList
%type <sr>    mExpr modListExpr specClauseListExpr

/*drl*/
%type <con>    BufConstraint
%type <tok> relationalOp
%type <tok> BufBinaryOp
%type <tok> bufferModifier

%type <conE> BufConstraintExpr

%type <conE> BufConstraintTerm
%type <sr> BufConstraintSrefExpr

%type <conL>    BufConstraintList

%type <tok>  BufUnaryOp

%type <enumnamelist> enumeratorList 
%type <cstringlist> fieldDesignator

%type <expr> sizeofExpr sizeofExprAux offsetofExpr
%type <expr> openScope closeScope 
%type <expr> instanceDecl namedInitializer optDeclarators
%type <expr> primaryExpr postfixExpr primaryIterExpr postfixIterExpr
%type <expr> unaryExpr castExpr timesExpr plusExpr
%type <expr> unaryIterExpr castIterExpr timesIterExpr plusIterExpr
%type <expr> shiftExpr relationalExpr equalityExpr bitandExpr
%type <expr> xorExpr bitorExpr andExpr
%type <expr> orExpr conditionalExpr assignExpr 
%type <expr> shiftIterExpr relationalIterExpr equalityIterExpr bitandIterExpr
%type <expr> xorIterExpr bitorIterExpr andIterExpr
%type <expr> orIterExpr conditionalIterExpr assignIterExpr iterArgExpr
%type <expr> expr optExpr constantExpr
%type <expr> init macroBody iterBody endBody partialIterStmt iterSelectionStmt
%type <expr> stmt stmtList fcnBody iterStmt iterDefStmt iterDefStmtList
%type <expr> labeledStmt caseStmt defaultStmt 
%type <expr> compoundStmt compoundStmtAux compoundStmtRest compoundStmtAuxErr
%type <expr> expressionStmt selectionStmt iterationStmt jumpStmt iterDefIterationStmt 
%type <expr> stmtErr stmtListErr compoundStmtErr expressionStmtErr 
%type <expr> iterationStmtErr initializerList initializer ifPred whilePred forPred iterWhilePred

%type <typequal> storageSpecifier typeQualifier typeModifier globQual
%type <tquallist> optGlobQuals
%type <qtyp> completeType completeTypeSpecifier optCompleteType
%type <qtyp> completeTypeSpecifierAux altType typeExpression 
/*%type <expr> lclintassertion*/

%start file

%%

file
 :              
 | externalDefs

externalDefs
 : externalDef
 | externalDefs externalDef 

externalDef
 : fcnDef optSemi { uentry_clearDecl (); } 
 | constantDecl   { uentry_clearDecl (); } 
 | fcnDecl        { uentry_clearDecl (); }
 | iterDecl       { uentry_clearDecl (); } 
 | macroDef       { uentry_clearDecl (); } 
 | initializer    { uentry_checkDecl (); exprNode_free ($1); }
 | error          { uentry_clearDecl (); } 

constantDecl
 : QCONSTANT completeTypeSpecifier NotType namedDecl NotType optSemi IsType QENDMACRO
   { checkConstant ($2, $4); }
 | QCONSTANT completeTypeSpecifier NotType namedDecl NotType TASSIGN IsType init optDeclarators optSemi QENDMACRO
   { checkValueConstant ($2, $4, $8) ; }

fcnDecl
 : QFUNCTION { context_enterFunctionHeader (); } plainFcn optSemi QENDMACRO 
   { 
     declareStaticFunction ($3); context_quietExitFunction (); 
     context_exitFunctionHeader (); 
   }

plainFcn
 : plainNamedDecl
   { 
     qtype qint = qtype_create (ctype_int);
     $$ = idDecl_fixBase ($1, qint);
     qtype_free (qint);
   }
 | completeTypeSpecifier NotType plainNamedDecl
   { $$ = idDecl_fixBase ($3, $1); }

plainNamedDecl
 : plainNamedDeclBase
 | pointers plainNamedDeclBase 
   { $$ = $2; qtype_adjustPointers ($1, idDecl_getTyp ($$)); }

namedDeclBase
 : newId { $$ = idDecl_create ($1, qtype_unknown ()); }
 | IsType TLPAREN NotType namedDecl IsType TRPAREN
   { $$ = idDecl_expectFunction ($4); }
 | namedDeclBase TLSQBR TRSQBR 
   { $$ = idDecl_replaceCtype ($1, ctype_makeArray (idDecl_getCtype ($1))); }
 | namedDeclBase TLSQBR IsType constantExpr TRSQBR NotType
   { 
     $$ = idDecl_replaceCtype ($1, ctype_makeFixedArray (idDecl_getCtype ($1), exprNode_getLongValue ($4)));
   }
 | namedDeclBase PushType TLPAREN TRPAREN 
   { setCurrentParams (uentryList_missingParams); }
   functionClauses
   { /* need to support globals and modifies here! */
     ctype ct = ctype_makeFunction (idDecl_getCtype ($1), 
				    uentryList_makeMissingParams ());
     
     $$ = idDecl_replaceCtype ($1, ct);
     idDecl_addClauses ($$, $6);
     context_popLoc (); 
   }
 | namedDeclBase PushType TLPAREN genericParamList TRPAREN 
   { setCurrentParams ($4); } 
   functionClauses
   { setImplictfcnConstraints ();
     clearCurrentParams ();
     $$ = idDecl_replaceCtype ($1, ctype_makeFunction (idDecl_getCtype ($1), $4));
     idDecl_addClauses ($$, $7);
     context_popLoc (); 
   }

plainNamedDeclBase
 : newId { $$ = idDecl_create ($1, qtype_unknown ()); }
 | IsType TLPAREN NotType plainNamedDecl IsType TRPAREN
   { $$ = idDecl_expectFunction ($4); }
 | plainNamedDeclBase TLSQBR TRSQBR 
   { $$ = idDecl_replaceCtype ($1, ctype_makeArray (idDecl_getCtype ($1))); }
 | plainNamedDeclBase TLSQBR IsType constantExpr TRSQBR NotType
   { 
     int value;

     if (exprNode_hasValue ($4) 
	 && multiVal_isInt (exprNode_getValue ($4)))
       {
	 value = (int) multiVal_forceInt (exprNode_getValue ($4));
       }
     else
       {
	 value = 0;
       }

     $$ = idDecl_replaceCtype ($1, ctype_makeFixedArray (idDecl_getCtype ($1), value));
   }
 | plainNamedDeclBase PushType TLPAREN TRPAREN 
   { setCurrentParams (uentryList_missingParams); }
   functionClausesPlain
   {
     ctype ct = ctype_makeFunction (idDecl_getCtype ($1), 
				    uentryList_makeMissingParams ());
     
     $$ = idDecl_replaceCtype ($1, ct);
     idDecl_addClauses ($$, $6);
     context_popLoc (); 
   }
 | plainNamedDeclBase PushType TLPAREN genericParamList TRPAREN 
   { setCurrentParams ($4); } 
   functionClausesPlain
   { 
     clearCurrentParams ();
     $$ = idDecl_replaceCtype ($1, ctype_makeFunction (idDecl_getCtype ($1), $4));
     idDecl_addClauses ($$, $7);
     context_popLoc (); 
   }

iterDecl
 : QITER newId TLPAREN genericParamList TRPAREN 
   { setCurrentParams ($4); } functionClausesPlain
   { clearCurrentParams (); } optSemi QENDMACRO
   { declareCIter ($2, $4); }

macroDef
 : LLMACRO macroBody TENDMACRO     { exprNode_checkMacroBody ($2); }
 | LLMACROITER iterBody TENDMACRO  { exprNode_checkIterBody ($2); }
 | LLMACROEND endBody TENDMACRO    { exprNode_checkIterEnd ($2); }
 | LLMACRO TENDMACRO /* no stmt */ { exprChecks_checkEmptyMacroBody (); } 

fcnDefHdr
  : fcnDefHdrAux { clabstract_declareFunction ($1); }

/*drl*/

BufConstraintList
: BufConstraint TCAND BufConstraintList { $$ = constraintList_add ($3, $1); }
| BufConstraint {constraintList c; c = constraintList_makeNew(); c = constraintList_add (c, $1); $$ = c}

BufConstraint
:  BufConstraintExpr relationalOp BufConstraintExpr {
 $$ = makeConstraintParse3 ($1, $2, $3);
 DPRINTF(("Done BufConstraint1\n")); }

bufferModifier
 : QMAXSET
 | QMAXREAD

relationalOp
 : GE_OP
 | LE_OP
 | EQ_OP

BufConstraintExpr
 : BufConstraintTerm 
 | BufUnaryOp TLPAREN BufConstraintExpr TRPAREN {$$ = constraintExpr_parseMakeUnaryOp ($1, $3);  DPRINTF( ("Got BufConstraintExpr UNary Op ") ); }
 | TLPAREN BufConstraintExpr BufBinaryOp BufConstraintExpr TRPAREN {
   DPRINTF( ("Got BufConstraintExpr BINary Op ") );
   $$ = constraintExpr_parseMakeBinaryOp ($2, $3, $4); }

BufConstraintTerm
: BufConstraintSrefExpr { $$ =  constraintExpr_makeTermsRef($1);} 
 | CCONSTANT {  char *t; int c;
  t =  cstring_toCharsSafe (exprNode_unparse($1));
  c = atoi( t );
  $$ = constraintExpr_makeIntLiteral (c);
}


BufConstraintSrefExpr
: id                               { /*@-onlytrans@*/ $$ = checkbufferConstraintClausesId ($1); /*@=onlytrans@*/ /*@i523@*/ }
| NEW_IDENTIFIER                   { $$ = fixStateClausesId ($1); }
| BufConstraintSrefExpr TLSQBR TRSQBR       { $$ = sRef_makeAnyArrayFetch ($1); }
|  BufConstraintSrefExpr  TLSQBR CCONSTANT TRSQBR {
  char *t; int c; 
  t =  cstring_toCharsSafe (exprNode_unparse($3)); /*@i5234 yuck!@*/
  c = atoi( t );
  $$ = sRef_makeArrayFetchKnown($1, c); }
| TMULT  BufConstraintSrefExpr               { $$ = sRef_constructPointer ($2); }
| TLPAREN BufConstraintSrefExpr TRPAREN     { $$ = $2; }  
|  BufConstraintSrefExpr TDOT newId          { cstring_markOwned ($3);
 $$ = sRef_buildField ($1, $3); }
|  BufConstraintSrefExpr ARROW_OP newId      { cstring_markOwned ($3);
 $$ = sRef_makeArrow ($1, $3); }

/*
| BufConstraintTerm TLSQBR TRSQBR       { $$ = sRef_makeAnyArrayFetch ($1); }
 | specClauseListExpr TLSQBR mExpr TRSQBR { $$ = sRef_makeAnyArrayFetch ($1); }
 | TLPAREN specClauseListExpr TRPAREN     { $$ = $2; }  
 | specClauseListExpr TDOT newId          { cstring_markOwned ($3);
					    $$ = sRef_buildField ($1, $3); }
*/

/*BufConstraintExpr
: BufConstraintTerm 
*/

BufUnaryOp
: bufferModifier 
;

BufBinaryOp
 : TPLUS
| TMINUS
;
/*
** Function clauses can appear in any order.
*/

functionClauses
 : { $$ = functionClauseList_new (); }
 | functionClause functionClauses
   { $$ = functionClauseList_prepend ($2, $1); }

/*
** Inside macro definitions, there are no end macros.
*/

functionClausesPlain
 : 
   { $$ = functionClauseList_new (); }
 | functionClausePlain functionClausesPlain
   { $$ = functionClauseList_prepend ($2, $1); }

functionClause
 : globalsClause   { $$ = functionClause_createGlobals ($1); }
 | modifiesClause  { $$ = functionClause_createModifies ($1); }
 | nomodsClause    { $$ = functionClause_createModifies ($1); }
 | stateClause     { $$ = functionClause_createState ($1); }  
 | conditionClause { $$ = $1; }
 | warnClause      { $$ = functionClause_createWarn ($1); }

functionClausePlain
 : globalsClausePlain   { $$ = functionClause_createGlobals ($1); }
 | modifiesClausePlain  { $$ = functionClause_createModifies ($1); }
 | nomodsClause         { $$ = functionClause_createModifies ($1); }
 | stateClausePlain     { $$ = functionClause_createState ($1); }  
 | conditionClausePlain { $$ = $1; }
 | warnClausePlain      { $$ = functionClause_createWarn ($1); }

globalsClause
 : globalsClausePlain QENDMACRO { $$ = $1; }

globalsClausePlain
 : QGLOBALS { setProcessingGlobalsList (); } 
   globIdList optSemi  
   { 
     unsetProcessingGlobals (); 
     $$ = globalsClause_create ($1, $3); 
   }

nomodsClause
 : QNOMODS { $$ = modifiesClause_createNoMods ($1); }

modifiesClause
 : modifiesClausePlain QENDMACRO { $$ = $1; }

modifiesClausePlain
 : QMODIFIES 
   {
     context_setProtectVars (); enterParamsTemp (); 
     sRef_setGlobalScopeSafe (); 
   }
   locModifies
   { 
     exitParamsTemp ();
     sRef_clearGlobalScopeSafe (); 
     context_releaseVars ();
     $$ = modifiesClause_create ($1, $3);
   }

flagSpec
 : flagId 
   { $$ = flagSpec_createPlain ($1); }
 | flagId TBAR flagSpec
   { $$ = flagSpec_createOr ($1, $3); }

flagId
 : NEW_IDENTIFIER

warnClause
 : warnClausePlain QENDMACRO { $$ = $1; }

warnClausePlain
 : QWARN flagSpec cconstantExpr
   { $$ = warnClause_create ($1, $2, $3); }
 | QWARN flagSpec
   { $$ = warnClause_create ($1, $2, exprNode_undefined); }

globIdList
 : globIdListExpr                     { $$ = globSet_single ($1); }
 | globIdList TCOMMA globIdListExpr   { $$ = globSet_insert ($1, $3); }
 
globIdListExpr 
 : optGlobQuals globId { $$ = clabstract_createGlobal ($2, $1); }

optGlobQuals
 : /* empty */           { $$ = qualList_undefined; }
 | globQual optGlobQuals { $$ = qualList_add ($2, $1); }

globId
 : id             { $$ = uentry_getSref ($1); }
 | NEW_IDENTIFIER { $$ = clabstract_unrecognizedGlobal ($1); }
 | initializer    { $$ = clabstract_checkGlobal ($1); }

globQual
 : QUNDEF   { $$ = qual_createUndef (); }
 | QKILLED  { $$ = qual_createKilled (); }
 | QOUT     { $$ = qual_createOut (); }
 | QIN      { $$ = qual_createIn (); }
 | QPARTIAL { $$ = qual_createPartial (); }

stateTag
 : QDEFINES
 | QUSES
 | QALLOCATES
 | QSETS
 | QRELEASES

conditionTag
 : QPRECLAUSE
 | QPOSTCLAUSE

fcnDefHdrAux
 : namedDecl                               
   { 
     qtype qint = qtype_create (ctype_int);
     $$ = idDecl_fixBase ($1, qint);
     qtype_free (qint);
   }
 | completeTypeSpecifier NotType namedDecl 
   { $$ = idDecl_fixBase ($3, $1); }
 
fcnBody
 : TLBRACE { checkDoneParams (); context_enterInnerContext (); } 
   compoundStmtRest 
   {  
     exprNode_checkFunctionBody ($3); $$ = $3; 
     context_exitInner ($3); 
   }
 | initializerList 
   { doneParams (); context_enterInnerContext (); }
   compoundStmt 
   {
     context_exitInner ($3);
     exprNode_checkFunctionBody ($3); 
     $$ = $3; /* old style */ 
   } 
 
fcnDef
 : fcnDefHdr fcnBody 
   { 
     context_setFunctionDefined (exprNode_loc ($2)); 
     exprNode_checkFunction (context_getHeader (), $2); 
     /* DRL 8 8 2000 */
     
     context_exitFunction ();
   }

locModifies
 : modList optSemi           { $$ = $1; }
 | optSemi                   { $$ = sRefSet_new (); }
 
modListExpr
 : id                              { $$ = uentry_getSref ($1); checkModifiesId ($1); }
 | NEW_IDENTIFIER                  { $$ = fixModifiesId ($1); }
 | modListExpr TLSQBR TRSQBR       { $$ = modListArrayFetch ($1, sRef_undefined); }
 | modListExpr TLSQBR mExpr TRSQBR { $$ = modListArrayFetch ($1, $3); }
 | TMULT modListExpr               { $$ = modListPointer ($2); }
 | TLPAREN modListExpr TRPAREN     { $$ = $2; }  
 | modListExpr TDOT newId          { $$ = modListFieldAccess ($1, $3); }
 | modListExpr ARROW_OP newId      { $$ = modListArrowAccess ($1, $3); }


mExpr
  : modListExpr     { $$ = $1; }
  | cconstantExpr   { $$ = sRef_makeUnknown (); /* sRef_makeConstant ($1); ? */ }
    /* arithmetic? */

modList
  : modListExpr                { $$ = sRefSet_single ($1); }
  | modList TCOMMA modListExpr { $$ = sRefSet_insert ($1, $3); }

specClauseListExpr
 : id                                     
   { $$ = checkStateClausesId ($1); }
 | NEW_IDENTIFIER                         
   { $$ = fixStateClausesId ($1); }
 | specClauseListExpr TLSQBR TRSQBR       { $$ = sRef_makeAnyArrayFetch ($1); }
 | specClauseListExpr TLSQBR mExpr TRSQBR { $$ = sRef_makeAnyArrayFetch ($1); }
 | TMULT specClauseListExpr               { $$ = sRef_constructPointer ($2); }
 | TLPAREN specClauseListExpr TRPAREN     { $$ = $2; }  
 | specClauseListExpr TDOT newId          { cstring_markOwned ($3);
					    $$ = sRef_buildField ($1, $3); }
 | specClauseListExpr ARROW_OP newId      { cstring_markOwned ($3);
                                            $$ = sRef_makeArrow ($1, $3); }

optSpecClauseList
 : /* empty */ { $$ = sRefSet_undefined }
 | specClauseList

specClauseList
  : specClauseListExpr                       
    { if (sRef_isValid ($1)) { $$ = sRefSet_single ($1); } 
      else { $$ = sRefSet_undefined; } 
    }
  | specClauseList TCOMMA specClauseListExpr 
    { if (sRef_isValid ($3))
	{
	  $$ = sRefSet_insert ($1, $3); 
	}
      else
	{
	  $$ = $1;
	}
    }

primaryExpr
 : id { $$ = exprNode_fromIdentifier ($1); }
 | NEW_IDENTIFIER { $$ = exprNode_fromUIO ($1); } 
 | cconstantExpr
 | TLPAREN expr TRPAREN { $$ = exprNode_addParens ($1, $2); }
 | TYPE_NAME_OR_ID { $$ = exprNode_fromIdentifier (coerceId ($1)); } 
 | QEXTENSION { $$ = exprNode_makeError (); }
 
postfixExpr
 : primaryExpr 
 | postfixExpr TLSQBR expr TRSQBR { $$ = exprNode_arrayFetch ($1, $3); }
 | postfixExpr TLPAREN TRPAREN { $$ = exprNode_functionCall ($1, exprNodeList_new ()); }
 | postfixExpr TLPAREN argumentExprList TRPAREN { $$ = exprNode_functionCall ($1, $3); }
 | VA_ARG TLPAREN assignExpr TCOMMA typeExpression TRPAREN { $$ = exprNode_vaArg ($1, $3, $5); }
 | postfixExpr NotType TDOT newId IsType { $$ = exprNode_fieldAccess ($1, $3, $4); }
 | postfixExpr NotType ARROW_OP newId IsType { $$ = exprNode_arrowAccess ($1, $3, $4); }
 | postfixExpr INC_OP { $$ = exprNode_postOp ($1, $2); }
 | postfixExpr DEC_OP { $$ = exprNode_postOp ($1, $2); }
 
argumentExprList
 : assignExpr { $$ = exprNodeList_singleton ($1); }
 | argumentExprList TCOMMA assignExpr { $$ = exprNodeList_push ($1, $3); }
 
unaryExpr
 : postfixExpr 
 | INC_OP unaryExpr { $$ = exprNode_preOp ($2, $1); }
 | DEC_OP unaryExpr { $$ = exprNode_preOp ($2, $1); }
 | TAMPERSAND castExpr { $$ = exprNode_preOp ($2, $1); }
 | TMULT castExpr  { $$ = exprNode_preOp ($2, $1); }
 | TPLUS castExpr  { $$ = exprNode_preOp ($2, $1); }
 | TMINUS castExpr { $$ = exprNode_preOp ($2, $1); }
 | TTILDE castExpr { $$ = exprNode_preOp ($2, $1); }
 | TEXCL castExpr  { $$ = exprNode_preOp ($2, $1); }
 | sizeofExpr      { $$ = $1; }
 | offsetofExpr    { $$ = $1; }

fieldDesignator
 : fieldDesignator TDOT newId { $$ = cstringList_add ($1, $3); }
 | newId                      { $$ = cstringList_single ($1); }

offsetofExpr
 : COFFSETOF IsType TLPAREN typeExpression NotType TCOMMA fieldDesignator TRPAREN IsType
   { $$ = exprNode_offsetof ($4, $7); }

sizeofExpr
 : IsType { context_setProtectVars (); } 
   sizeofExprAux { context_sizeofReleaseVars (); $$ = $3; }

sizeofExprAux 
 : CSIZEOF TLPAREN typeExpression TRPAREN { $$ = exprNode_sizeofType ($3); } 
 | CSIZEOF unaryExpr                      { $$ = exprNode_sizeofExpr ($2); }
 | CALIGNOF TLPAREN typeExpression TRPAREN { $$ = exprNode_alignofType ($3); } 
 | CALIGNOF unaryExpr                      { $$ = exprNode_alignofExpr ($2); }
 
castExpr
 : unaryExpr 
 | TLPAREN typeExpression TRPAREN castExpr 
   { $$ = exprNode_cast ($1, $4, $2); } 
 
timesExpr
 : castExpr 
 | timesExpr TMULT castExpr { $$ = exprNode_op ($1, $3, $2); }
 | timesExpr TDIV castExpr { $$ = exprNode_op ($1, $3, $2); }
 | timesExpr TPERCENT castExpr { $$ = exprNode_op ($1, $3, $2); }

plusExpr
 : timesExpr 
 | plusExpr TPLUS timesExpr { $$ = exprNode_op ($1, $3, $2); }
 | plusExpr TMINUS timesExpr { $$ = exprNode_op ($1, $3, $2); }

shiftExpr
 : plusExpr 
 | shiftExpr LEFT_OP plusExpr { $$ = exprNode_op ($1, $3, $2); }
 | shiftExpr RIGHT_OP plusExpr { $$ = exprNode_op ($1, $3, $2); }

relationalExpr
 : shiftExpr 
 | relationalExpr TLT shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 | relationalExpr TGT shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 | relationalExpr LE_OP shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 | relationalExpr GE_OP shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 
equalityExpr 
 : relationalExpr 
 | equalityExpr EQ_OP relationalExpr { $$ = exprNode_op ($1, $3, $2); }
 | equalityExpr NE_OP relationalExpr { $$ = exprNode_op ($1, $3, $2); }

bitandExpr
 : equalityExpr 
 | bitandExpr TAMPERSAND equalityExpr { $$ = exprNode_op ($1, $3, $2); }

xorExpr
 : bitandExpr 
 | xorExpr TCIRC bitandExpr { $$ = exprNode_op ($1, $3, $2); }
; 

bitorExpr
 : xorExpr 
 | bitorExpr TBAR xorExpr { $$ = exprNode_op ($1, $3, $2); }

andExpr 
 : bitorExpr 
 | andExpr AND_OP 
   { exprNode_produceGuards ($1); 
     context_enterAndClause ($1); 
   } 
   bitorExpr 
   { 
     $$ = exprNode_op ($1, $4, $2); 
     context_exitAndClause ($$, $4);
   }

orExpr
 : andExpr 
 | orExpr OR_OP 
   { 
     exprNode_produceGuards ($1);
     context_enterOrClause ($1); 
   } 
   andExpr 
   { 
     $$ = exprNode_op ($1, $4, $2); 
     context_exitOrClause ($$, $4);
   }

conditionalExpr 
 : orExpr 
 | orExpr TQUEST { exprNode_produceGuards ($1); context_enterTrueClause ($1); } expr TCOLON 
   { context_enterFalseClause ($1); } conditionalExpr
   { $$ = exprNode_cond ($1, $4, $7); context_exitClause ($1, $4, $7); }

assignExpr
 : conditionalExpr 
 | unaryExpr TASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr MUL_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr DIV_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr MOD_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr ADD_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr SUB_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr LEFT_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr RIGHT_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr AND_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr XOR_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr OR_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 

expr
 : assignExpr 
 | expr TCOMMA assignExpr { $$ = exprNode_comma ($1, $3); } 

optExpr
 : /* empty */ { $$ = exprNode_undefined; }
 | expr 

constantExpr
 : conditionalExpr 

/* instance_orTypeDecl_and_possible_initialization */

initializer
 : instanceDecl { $$ = $1; }
 | VA_DCL       { doVaDcl (); $$ = exprNode_makeError (); } 
 | typeDecl     { $$ = exprNode_makeError (); }

instanceDecl
 : completeTypeSpecifier IsType TSEMI 
   { $$ = exprNode_makeError (); }
    /*
     ** This causes r/r conflicts with function definitions.
     ** Instead we need to snarf one first. (gack)
     **
     ** | completeTypeSpecifier { setProcessingVars ($1); } 
     ** NotType 
     ** namedInitializerList IsType TSEMI 
     ** { unsetProcessingVars (); }
     **;
     **
     ** the solution is pretty ugly:
     */
 | completeTypeSpecifier NotType namedDecl NotType 
   {
     setProcessingVars ($1); 
     processNamedDecl ($3); 
   }
   IsType optDeclarators TSEMI IsType 
   { 
     unsetProcessingVars (); 
     $$ = exprNode_makeEmptyInitialization ($3); 
     DPRINTF (("Empty initialization: %s", exprNode_unparse ($$)));
   }
 | completeTypeSpecifier NotType namedDecl NotType TASSIGN 
   { setProcessingVars ($1); processNamedDecl ($3); }
   IsType init optDeclarators TSEMI IsType 
   { $$ = exprNode_concat ($9, exprNode_makeInitialization ($3, $8)); 
     unsetProcessingVars ();
   }

namedInitializer
 : namedDecl NotType 
   { 
     processNamedDecl ($1); 
     $$ = exprNode_makeEmptyInitialization ($1);
   }
 | namedDecl NotType TASSIGN { processNamedDecl ($1); } IsType init
   { $$ = exprNode_makeInitialization ($1, $6); }

typeDecl
 : CTYPEDEF completeTypeSpecifier { setProcessingTypedef ($2); } 
   NotType namedInitializerList IsType TSEMI { unsetProcessingTypedef (); } 
 | CTYPEDEF completeTypeSpecifier IsType TSEMI { /* in the ANSI grammar, semantics unclear */ }
 | CTYPEDEF namedInitializerList IsType TSEMI { /* in the ANSI grammar, semantics unclear */ } 

IsType
 : { g_expectingTypeName = TRUE; }

PushType
 : { g_expectingTypeName = TRUE; context_pushLoc (); }

namedInitializerList
 :  namedInitializerListAux IsType { ; }

namedInitializerListAux
 : namedInitializer { ; }
 | namedInitializerList TCOMMA NotType namedInitializer { ; }

optDeclarators
 : /* empty */      { $$ = exprNode_makeError (); }
 | optDeclarators TCOMMA NotType namedInitializer { $$ = exprNode_concat ($1, $4); }

init
 : assignExpr                      
 | TLBRACE initList TRBRACE        { $$ = exprNode_makeInitBlock ($1, $2); }
 | TLBRACE initList TCOMMA TRBRACE { $$ = exprNode_makeInitBlock ($1, $2); }


initList
 : init 
   { $$ = exprNodeList_singleton ($1); }
 | initList TCOMMA init 
   { $$ = exprNodeList_push ($1, $3); }

/*
** need to do the storage class global hack so tags are
** declared with the right storage class.
*/

storageSpecifier
 : QEXTERN   { setStorageClass (SCEXTERN); $$ = qual_createExtern (); }
 | QINLINE   { $$ = qual_createInline (); }
 | QSTATIC   { setStorageClass (SCSTATIC); $$ = qual_createStatic (); }
 | QAUTO     { $$ = qual_createAuto (); }
 | QREGISTER { $$ = qual_createRegister (); }

nullterminatedQualifier:
 QNULLTERMINATED IsType { $$ = qual_createNullTerminated (); }

stateClause
 : stateClausePlain QENDMACRO { $$ = $1; }

stateClausePlain
 : stateTag NotType
   {
     context_setProtectVars (); 
     enterParamsTemp (); 
     sRef_setGlobalScopeSafe (); 
   }
   specClauseList optSemi IsType
   { 
     exitParamsTemp ();
     sRef_clearGlobalScopeSafe (); 
     context_releaseVars ();
     $$ = stateClause_createPlain ($1, $4);
   }

conditionClause
 : conditionClausePlain QENDMACRO { $$ = $1; }

startConditionClause
: conditionTag NotType { $$ = $1; context_enterFunctionHeader (); } 

conditionClausePlain
 : startConditionClause stateQualifier
   {
     context_exitFunctionHeader ();
     context_setProtectVars (); 
     enterParamsTemp (); 
     sRef_setGlobalScopeSafe (); 
   }
   optSpecClauseList optSemi IsType
   { 
     exitParamsTemp ();
     sRef_clearGlobalScopeSafe (); 
     context_releaseVars ();
     $$ = functionClause_createState (stateClause_create ($1, $2, $4));
   }
 | startConditionClause
   {
     context_setProtectVars (); 
     enterParamsTemp (); 
     sRef_setGlobalScopeSafe (); 
   } 
   BufConstraintList optSemi IsType
   {
     context_exitFunctionHeader ();
     exitParamsTemp ();
     sRef_clearGlobalScopeSafe (); 
     context_releaseVars ();
     DPRINTF (("done optGlobBufConstraintsAux\n"));

     if (lltok_isEnsures ($1)) 
       {
	 $$ = functionClause_createEnsures ($3);
       }
     else if (lltok_isRequires ($1))
       {
	 $$ = functionClause_createRequires ($3);
       }
     else
       {
	 BADBRANCH;
       }
   }
 
exitsQualifier
 : QEXITS        { $$ = qual_createExits (); }
 | QMAYEXIT      { $$ = qual_createMayExit (); }
 | QTRUEEXIT     { $$ = qual_createTrueExit (); }
 | QFALSEEXIT    { $$ = qual_createFalseExit (); }
 | QNEVEREXIT    { $$ = qual_createNeverExit (); }

checkQualifier
 : QCHECKED        { $$ = qual_createChecked (); }
 | QCHECKMOD       { $$ = qual_createCheckMod (); }
 | QUNCHECKED      { $$ = qual_createUnchecked (); }
 | QCHECKEDSTRICT  { $$ = qual_createCheckedStrict (); }

stateQualifier
 : QOWNED        { $$ = qual_createOwned (); }
 | QDEPENDENT    { $$ = qual_createDependent (); }
 | QYIELD        { $$ = qual_createYield (); }
 | QTEMP         { $$ = qual_createTemp (); }
 | QONLY         { $$ = qual_createOnly (); }
 | QKEEP         { $$ = qual_createKeep (); }
 | QKEPT         { $$ = qual_createKept (); }
 | QSHARED       { $$ = qual_createShared (); }
 | QUNIQUE       { $$ = qual_createUnique (); }
 | QNULL         { $$ = qual_createNull (); }
 | QISNULL       { $$ = qual_createIsNull (); }
 | QRELNULL      { $$ = qual_createRelNull (); }
 | QNOTNULL      { $$ = qual_createNotNull (); }
 | QEXPOSED      { $$ = qual_createExposed (); }
 | QOBSERVER     { $$ = qual_createObserver (); }
 | CANNOTATION   { $$ = qual_createMetaState ($1); }

paramQualifier
 : QRETURNED     { $$ = qual_createReturned (); }
 | QSEF          { $$ = qual_createSef (); }

visibilityQualifier
 : QUNUSED       { $$ = qual_createUnused (); }
 | QEXTERNAL     { $$ = qual_createExternal (); }

returnQualifier
 : QTRUENULL     { $$ = qual_createTrueNull (); }
 | QFALSENULL    { $$ = qual_createFalseNull (); }

typedefQualifier
 : QABSTRACT     { $$ = qual_createAbstract (); }
 | QCONCRETE     { $$ = qual_createConcrete (); }
 | QMUTABLE      { $$ = qual_createMutable (); }
 | QIMMUTABLE    { $$ = qual_createImmutable (); }

refcountQualifier
 : QREFCOUNTED   { $$ = qual_createRefCounted (); }
 | QREFS         { $$ = qual_createRefs (); }
 | QKILLREF      { $$ = qual_createKillRef (); }
 | QRELDEF       { $$ = qual_createRelDef (); }
 | QNEWREF       { $$ = qual_createNewRef (); }
 | QTEMPREF      { $$ = qual_createTempRef (); }

typeModifier
 : QSHORT            { $$ = qual_createShort (); }
 | QLONG             { $$ = qual_createLong (); }
 | QSIGNED           { $$ = qual_createSigned (); }
 | QUNSIGNED         { $$ = qual_createUnsigned (); }

definedQualifier
 : QOUT              { $$ = qual_createOut (); }
 | QIN               { $$ = qual_createIn (); }
 | QPARTIAL          { $$ = qual_createPartial (); }
 | QSPECIAL          { $$ = qual_createSpecial (); }

typeQualifier
 : QCONST IsType       { $$ = qual_createConst (); }
 | QVOLATILE IsType    { $$ = qual_createVolatile (); }
 | definedQualifier IsType { $$ = $1; } 
 | stateQualifier IsType { $$ = $1; } 
 | exitsQualifier IsType { $$ = $1; }
 | paramQualifier IsType { $$ = $1; }
 | checkQualifier IsType { $$ = $1; }
 | returnQualifier IsType { $$ = $1; }
 | visibilityQualifier IsType { $$ = $1; }
 | typedefQualifier IsType { $$ = $1; }
 | refcountQualifier IsType { $$ = $1; }

/*
** This is copied into the mtgrammar!
*/

typeSpecifier
 : CGCHAR NotType 
 | CINT NotType 
 | CBOOL NotType
 | CGFLOAT NotType
 | CDOUBLE NotType
 | CVOID NotType 
 | QANYTYPE NotType              { $$ = ctype_unknown; }
 | QINTEGRALTYPE NotType         { $$ = ctype_anyintegral; }
 | QUNSIGNEDINTEGRALTYPE NotType { $$ = ctype_unsignedintegral; }
 | QSIGNEDINTEGRALTYPE NotType   { $$ = ctype_signedintegral; }
 | typeName NotType     
 | suSpc NotType 
 | enumSpc NotType
 | typeModifier NotType { $$ = ctype_fromQual ($1); }

completeType
 : IsType completeTypeSpecifier IsType
   { $$ = qtype_resolve ($2); }

completeTypeSpecifier
 : completeTypeSpecifierAux { $$ = $1; }
 | completeTypeSpecifierAux QALT altType QENDMACRO  
   { $$ = qtype_mergeAlt ($1, $3); }

altType
 : typeExpression
 | typeExpression TCOMMA altType
   { $$ = qtype_mergeAlt ($1, $3); } 

completeTypeSpecifierAux
 : storageSpecifier optCompleteType        { $$ = qtype_addQual ($2, $1); }
 | typeQualifier optCompleteType           { $$ = qtype_addQual ($2, $1); } 
 | typeSpecifier optCompleteType           { $$ = qtype_combine ($2, $1); }

optCompleteType
 : /* empty */                             { $$ = qtype_unknown (); }
 | completeTypeSpecifier                   { $$ = $1; }

suSpc
 : NotType CSTRUCT newId IsType TLBRACE { sRef_setGlobalScopeSafe (); } 
   CreateStructInnerScope 
   structDeclList DeleteStructInnerScope { sRef_clearGlobalScopeSafe (); }
   TRBRACE 
   { $$ = declareStruct ($3, $8); }
 | NotType CUNION  newId IsType TLBRACE { sRef_setGlobalScopeSafe (); } 
   CreateStructInnerScope 
   structDeclList DeleteStructInnerScope { sRef_clearGlobalScopeSafe (); } 
   TRBRACE
   { $$ = declareUnion ($3, $8); } 
 | NotType CSTRUCT newId IsType TLBRACE TRBRACE 
   { $$ = declareStruct ($3, uentryList_new ()); }
 | NotType CUNION  newId IsType TLBRACE TRBRACE 
   { $$ = declareUnion ($3, uentryList_new ()); }
 | NotType CSTRUCT IsType TLBRACE { sRef_setGlobalScopeSafe (); } 
   CreateStructInnerScope 
   structDeclList DeleteStructInnerScope { sRef_clearGlobalScopeSafe (); }
   TRBRACE 
   { $$ = declareUnnamedStruct ($7); }
 | NotType CUNION IsType TLBRACE { sRef_setGlobalScopeSafe (); } 
   CreateStructInnerScope 
   structDeclList DeleteStructInnerScope { sRef_clearGlobalScopeSafe (); }
   TRBRACE 
   { $$ = declareUnnamedUnion ($7); } 
 | NotType CSTRUCT IsType TLBRACE TRBRACE
   { $$ = ctype_createUnnamedStruct (uentryList_new ()); }
 | NotType CUNION  IsType TLBRACE TRBRACE 
   { $$ = ctype_createUnnamedUnion (uentryList_new ()); } 
 | NotType CSTRUCT newId NotType { $$ = handleStruct ($3); } 
 | NotType CUNION  newId NotType { $$ = handleUnion ($3); }

NotType
 : { g_expectingTypeName = FALSE; }

structDeclList
 : structDecl 
 | macroDef { $$ = uentryList_undefined; /* bogus! */ }
 | structDeclList structDecl { $$ = uentryList_mergeFields ($1, $2); }

structDecl
 : completeTypeSpecifier NotType structNamedDeclList IsType TSEMI 
   { $$ = fixUentryList ($3, $1); }
 | completeTypeSpecifier IsType TSEMI 
   { $$ = fixUnnamedDecl ($1); }

structNamedDeclList 
 : structNamedDecl NotType                            
   { $$ = idDeclList_singleton ($1); }
 | structNamedDeclList TCOMMA structNamedDecl NotType
   { $$ = idDeclList_add ($1, $3); }

structNamedDecl  /* hack to get around namespace problems */ 
 : namedDecl                            { $$ = $1; }
 | TCOLON IsType constantExpr           { $$ = idDecl_undefined; }
 | namedDecl TCOLON IsType constantExpr { $$ = $1; }
   /* Need the IsType in case there is a cast in the constant expression. */

enumSpc
 : NotType CENUM TLBRACE enumeratorList TRBRACE IsType 
   { $$ = declareUnnamedEnum ($4); }
 | NotType CENUM newId TLBRACE { context_pushLoc (); } enumeratorList TRBRACE IsType
   { context_popLoc (); $$ = declareEnum ($3, $6); }
 | NotType CENUM newId IsType { $$ = handleEnum ($3); }

enumeratorList
 : enumerator 
   { $$ = enumNameList_single ($1); }
 | enumeratorList TCOMMA enumerator 
   { $$ = enumNameList_push ($1, $3); }
 | enumeratorList TCOMMA

enumerator
 : newId 
   { uentry ue = uentry_makeEnumConstant ($1, ctype_unknown);
     usymtab_supGlobalEntry (ue);
     $$ = $1;
   }
 | newId TASSIGN IsType constantExpr 
   { uentry ue = uentry_makeEnumInitializedConstant ($1, ctype_unknown, $4);
     usymtab_supGlobalEntry (ue);
     $$ = $1; 
   }

optNamedDecl
 : namedDeclBase
 | optAbstractDeclBase   { $$ = idDecl_create (cstring_undefined, qtype_create ($1)); }
 | pointers TYPE_NAME    
   { 
     qtype qt = qtype_unknown ();

     qtype_adjustPointers ($1, qt);
     $$ = idDecl_create (cstring_copy (LastIdentifier ()), qt);
   }
 | pointers optNamedDecl 
   { $$ = $2; qtype_adjustPointers ($1, idDecl_getTyp ($$)); }

namedDecl
 : namedDeclBase
 | pointers namedDeclBase 
   { $$ = $2; qtype_adjustPointers ($1, idDecl_getTyp ($$)); }

genericParamList
 : paramTypeList       { $$ = handleParamTypeList ($1); }
 | NotType paramIdList { $$ = handleParamIdList ($2); }  

innerMods
 : QCONST    { /* ignored for now */; }
 | QVOLATILE { ; }

innerModsList
 : innerMods { ; }
 | innerModsList innerMods { ; }

pointers
 : TMULT { $$ = 1; }
 | TMULT innerModsList { $$ = 1; }
 | TMULT pointers { $$ = 1 + $2; }
 | TMULT innerModsList pointers { $$ = 1 + $3; }

paramIdList
 : idList 
 | idList TCOMMA CTOK_ELIPSIS { $$ = uentryList_add ($1, uentry_makeElipsisMarker ()); }

idList
 : newId { $$ = uentryList_single (uentry_makeVariableLoc ($1, ctype_int)); }
 | idList TCOMMA newId { $$ = uentryList_add ($1, uentry_makeVariableLoc ($3, ctype_int)); }

paramTypeList
 : CTOK_ELIPSIS { $$ = uentryList_single (uentry_makeElipsisMarker ()); }
 | paramList 
 | paramList TCOMMA CTOK_ELIPSIS { $$ = uentryList_add ($1, uentry_makeElipsisMarker ()); }

paramList
 : { storeLoc (); } paramDecl { $$ = uentryList_single ($2); }
 | paramList TCOMMA { storeLoc (); } paramDecl 
   { $$ = uentryList_add ($1, $4); }

paramDecl
 : IsType completeTypeSpecifier optNamedDecl IsType
   { 
     if (isFlipOldStyle ()) 
       { 
	 llparseerror (cstring_makeLiteral ("Inconsistent function parameter syntax (mixing old and new style declaration)")); 
       }
     else 
       { 
	 setNewStyle (); 
       }
     $$ = makeCurrentParam (idDecl_fixParamBase ($3, $2)); 
   }
 | newId /* its an old-style declaration */
   { 
     idDecl tparam = idDecl_create ($1, qtype_unknown ());

     if (isNewStyle ()) 
       {
	 llparseerror (message ("Inconsistent function parameter syntax: %q",
				idDecl_unparse (tparam))); 
       }

     setFlipOldStyle ();
     $$ = makeCurrentParam (tparam);
     idDecl_free (tparam);
   } 

typeExpression
 : completeType
 | completeType abstractDecl  { $$ = qtype_newBase ($1, $2); }

abstractDecl
 : pointers { $$ = ctype_adjustPointers ($1, ctype_unknown); }
 | abstractDeclBase
 | pointers abstractDeclBase { $$ = ctype_adjustPointers ($1, $2); }

optAbstractDeclBase
 : /* empty */ { $$ = ctype_unknown; }
 | abstractDeclBase 

abstractDeclBase
 : IsType TLPAREN NotType abstractDecl TRPAREN 
   { $$ = ctype_expectFunction ($4); }
 | TLSQBR TRSQBR { $$ = ctype_makeArray (ctype_unknown); }
 | TLSQBR constantExpr TRSQBR 
   { $$ = ctype_makeFixedArray (ctype_unknown, exprNode_getLongValue ($2)); }
 | abstractDeclBase TLSQBR TRSQBR { $$ = ctype_makeArray ($1); }
 | abstractDeclBase TLSQBR constantExpr TRSQBR 
   { $$ = ctype_makeFixedArray ($1, exprNode_getLongValue ($3)); }
 | IsType TLPAREN TRPAREN 
   { $$ = ctype_makeFunction (ctype_unknown, uentryList_makeMissingParams ()); }
 | IsType TLPAREN paramTypeList TRPAREN 
   { $$ = ctype_makeParamsFunction (ctype_unknown, $3); }
 | abstractDeclBase IsType TLPAREN TRPAREN 
   { $$ = ctype_makeFunction ($1, uentryList_makeMissingParams ()); }  
 | abstractDeclBase IsType TLPAREN paramTypeList TRPAREN 
   { $$ = ctype_makeParamsFunction ($1, $4); }  

/* statement */

stmt
 : labeledStmt 
 | caseStmt 
 | defaultStmt
 | compoundStmt 
 | expressionStmt
 | selectionStmt 
 | iterationStmt 
 | iterStmt
 | jumpStmt 
/* | lclintassertion {$$ = $1; printf ("Doing stmt lclintassertion\n"); }*/

/*
lclintassertion
 : QSETBUFFERSIZE id CCONSTANT QENDMACRO { printf(" QSETBUFFERSIZE id CCONSTANT HEllo World\n");  uentry_setBufferSize($2, $3); $$ = exprNode_createTok ($4);
  }
 | QSETSTRINGLENGTH id CCONSTANT QENDMACRO { printf(" QSETSTRINGLENGTH id CCONSTANT HEllo World\n");  uentry_setStringLength($2, $3); $$ = exprNode_createTok ($4);
  }
 | QTESTINRANGE id CCONSTANT QENDMACRO {printf(" QTESTINRANGE\n");  uentry_testInRange($2, $3); $$ = exprNode_createTok ($4);
  }

/* | QSETBUFFERSIZE id id  {$$ = $2; printf(" QSETBUFFERSIZE id id HEllo World\n");} */

iterBody
 : iterDefStmtList { $$ = $1; }

endBody
 : iterBody

iterDefStmtList
 : iterDefStmt                 
 | iterDefStmtList iterDefStmt 
   { $$ = exprNode_concat ($1, $2); }

iterDefIterationStmt
 : iterWhilePred iterDefStmtList         
   { $$ = exprNode_while ($1, $2); }
 | doHeader stmtErr WHILE TLPAREN expr TRPAREN TSEMI 
   { $$ = exprNode_doWhile ($2, $5); }
 | doHeader stmtErr WHILE TLPAREN expr TRPAREN
   { $$ = exprNode_doWhile ($2, $5); }
 | forPred iterDefStmt
   { $$ = exprNode_for ($1, $2); } 

forPred
 : CFOR TLPAREN optExpr TSEMI optExpr TSEMI 
   { context_setProtectVars (); } optExpr { context_sizeofReleaseVars (); }
   TRPAREN 
   { $$ = exprNode_forPred ($3, $5, $8); 
     context_enterForClause ($5); }

partialIterStmt
 : ITER_NAME CreateInnerScope TLPAREN 
   { setProcessingIterVars ($1); } 
   iterArgList TRPAREN 
   { $$ = exprNode_iterStart ($1, $5); }
 | ITER_ENDNAME { $$ = exprNode_createId ($1); }

iterDefStmt
 : labeledStmt 
 | caseStmt 
 | defaultStmt
 | openScope initializerList { $$ = $1; DPRINTF (("def stmt: %s", exprNode_unparse ($$))); }
 | openScope
 | closeScope
 | expressionStmt
 | iterSelectionStmt 
 | iterDefIterationStmt 
 | partialIterStmt
 | jumpStmt 
 | TLPAREN iterDefStmt TRPAREN { $$ = $2; }
 | error { $$ = exprNode_makeError (); }

iterSelectionStmt
 : ifPred iterDefStmt 
   { /* don't: context_exitTrueClause ($1, $2); */
     $$ = exprNode_if ($1, $2); 
   }

openScope
 : CreateInnerScope TLBRACE { $$ = exprNode_createTok ($2); }

closeScope
 : DeleteInnerScopeSafe TRBRACE { $$ = exprNode_createTok ($2); }

macroBody
 : stmtErr    
 | stmtListErr
 
stmtErr
 : labeledStmt
 | caseStmt 
 | defaultStmt 
 | compoundStmtErr
 | expressionStmtErr
 | selectionStmt 
 | iterStmt
 | iterationStmtErr
 | TLPAREN stmtErr TRPAREN { $$ = exprNode_addParens ($1, $2); }
 | jumpStmt 
 | error { $$ = exprNode_makeError (); }

labeledStmt
 : newId TCOLON      { $$ = exprNode_labelMarker ($1); }
 | QNOTREACHED stmt  { $$ = exprNode_notReached ($2); }

/* Note that we can semantically check that the object to the case is
 indeed constant. In this case, we may not want to go through this effort */

caseStmt
 : CASE constantExpr { context_enterCaseClause ($2); } 
   TCOLON            { $$ = exprNode_caseMarker ($2, FALSE); }
 | QFALLTHROUGH CASE constantExpr { context_enterCaseClause ($3); } 
   TCOLON            { $$ = exprNode_caseMarker ($3, TRUE); }

defaultStmt
 : DEFAULT { context_enterCaseClause (exprNode_undefined); } 
   TCOLON { $$ = exprNode_defaultMarker ($1, FALSE); }
 | QFALLTHROUGH DEFAULT { context_enterCaseClause (exprNode_undefined); } 
   TCOLON { $$ = exprNode_defaultMarker ($2, TRUE); }

compoundStmt
 : TLPAREN compoundStmt TRPAREN { $$ = $2; }
 | CreateInnerScope compoundStmtAux 
   { $$ = $2; context_exitInner ($2); }

compoundStmtErr
 : CreateInnerScope compoundStmtAuxErr DeleteInnerScope { $$ = $2; }

CreateInnerScope
 : { context_enterInnerContext (); }

DeleteInnerScope
 : { context_exitInnerPlain (); }

CreateStructInnerScope
 : { context_enterStructInnerContext (); }

DeleteStructInnerScope
 : { context_exitStructInnerContext (); }

DeleteInnerScopeSafe
 : { context_exitInnerSafe (); }

compoundStmtRest
 : TRBRACE { $$ = exprNode_createTok ($1); }
 | QNOTREACHED TRBRACE { $$ = exprNode_notReached (exprNode_createTok ($2)); }
 | stmtList TRBRACE { $$ = exprNode_updateLocation ($1, lltok_getLoc ($2)); }
 | stmtList QNOTREACHED TRBRACE 
   { $$ = exprNode_notReached (exprNode_updateLocation ($1, lltok_getLoc ($3))); }
 | initializerList TRBRACE { $$ = exprNode_updateLocation ($1, lltok_getLoc ($2)); }
 | initializerList QNOTREACHED TRBRACE 
   { $$ = exprNode_notReached (exprNode_updateLocation ($1, lltok_getLoc ($3))); }
 | initializerList stmtList TRBRACE
   { $$ = exprNode_updateLocation (exprNode_concat ($1, $2), lltok_getLoc ($3)); }
 | initializerList stmtList QNOTREACHED TRBRACE
   { $$ = exprNode_notReached (exprNode_updateLocation (exprNode_concat ($1, $2), 
							lltok_getLoc ($3))); 
   }


compoundStmtAux
 : TLBRACE compoundStmtRest 
   { $$ = exprNode_makeBlock ($2); }

compoundStmtAuxErr
 : TLBRACE TRBRACE 
   { $$ = exprNode_createTok ($2); }
 | TLBRACE stmtListErr TRBRACE 
   { $$ = exprNode_updateLocation ($2, lltok_getLoc ($3)); }
 | TLBRACE initializerList TRBRACE 
   { $$ = exprNode_updateLocation ($2, lltok_getLoc ($3)); }
 | TLBRACE initializerList stmtList TRBRACE 
   { $$ = exprNode_updateLocation (exprNode_concat ($2, $3), lltok_getLoc ($4)); }

stmtListErr
 : stmtErr 
 | stmtListErr stmtErr { $$ = exprNode_concat ($1, $2); }

initializerList
 : initializer { $$ = $1; }
 | initializerList initializer { $$ = exprNode_concat ($1, $2); }

stmtList
 : stmt { $$ = $1; }
 | stmtList stmt { $$ = exprNode_concat ($1, $2); }
 
expressionStmt 
 : TSEMI { $$ = exprNode_createTok ($1); }
 | expr TSEMI { $$ = exprNode_statement ($1, $2); }

expressionStmtErr
 : TSEMI { $$ = exprNode_createTok ($1); }
 | expr TSEMI { $$ = exprNode_statement ($1, $2); }
 | expr { $$ = exprNode_checkExpr ($1); } 

ifPred
 : CIF TLPAREN expr TRPAREN 
   { $$ = $3; exprNode_produceGuards ($3); context_enterTrueClause ($3); }
 /*
 ** not ANSI: | CIF TLPAREN compoundStmt TRPAREN 
 **             { $$ = $3; context_enterTrueClause (); } 
 */

selectionStmt
 : ifPred stmt 
   { 
     context_exitTrueClause ($1, $2);
     $$ = exprNode_if ($1, $2); 
   }
 | ifPred stmt CELSE { context_enterFalseClause ($1); } stmt 
   {
     context_exitClause ($1, $2, $5);
     $$ = exprNode_ifelse ($1, $2, $5); 
   }
 | SWITCH TLPAREN expr { context_enterSwitch ($3); } 
   TRPAREN stmt        { $$ = exprNode_switch ($3, $6); }
 
whilePred
 : WHILE TLPAREN expr TRPAREN 
   { $$ = exprNode_whilePred ($3); context_enterWhileClause ($3); }
   /* not ANSI: | WHILE TLPAREN compoundStmt TRPAREN stmt { $$ = exprNode_while ($3, $5); } */

iterWhilePred
 : WHILE TLPAREN expr TRPAREN { $$ = exprNode_whilePred($3); }

iterStmt
 : ITER_NAME { context_enterIterClause (); } 
   CreateInnerScope TLPAREN { setProcessingIterVars ($1); } 
   iterArgList TRPAREN 
   compoundStmt endIter DeleteInnerScope
   { 
     $$ = exprNode_iter ($1, $6, $8, $9); 

   } 
 
iterArgList 
 : iterArgExpr { $$ = exprNodeList_singleton ($1); }
 | iterArgList { nextIterParam (); } TCOMMA iterArgExpr 
   { $$ = exprNodeList_push ($1, $4); }

iterArgExpr
  : assignIterExpr  { $$ = exprNode_iterExpr ($1); }
  | id              { $$ = exprNode_iterId ($1); }
  | TYPE_NAME_OR_ID { uentry ue = coerceIterId ($1);

		      if (uentry_isValid (ue)) 
			{
			  $$ = exprNode_iterId (ue);
			}
		      else
			{
			  $$ = exprNode_iterNewId (cstring_copy (LastIdentifier ()));
			}
		    }
  | NEW_IDENTIFIER  { $$ = exprNode_iterNewId ($1); }

/*
** everything is the same, EXCEPT it cannot be a NEW_IDENTIFIER 
*/

cconstantExpr
 : CCONSTANT
 | cconstantExpr CCONSTANT { $$ = exprNode_combineLiterals ($1, $2); }  

primaryIterExpr
 : cconstantExpr 
 | TLPAREN expr TRPAREN { $$ = exprNode_addParens ($1, $2); }
 
postfixIterExpr
 : primaryIterExpr 
 | postfixExpr TLSQBR expr TRSQBR { $$ = exprNode_arrayFetch ($1, $3); }
 | postfixExpr TLPAREN TRPAREN { $$ = exprNode_functionCall ($1, exprNodeList_new ()); }
 | postfixExpr TLPAREN argumentExprList TRPAREN { $$ = exprNode_functionCall ($1, $3); }
 | VA_ARG TLPAREN assignExpr TCOMMA typeExpression TRPAREN
       { $$ = exprNode_vaArg ($1, $3, $5); }
 | postfixExpr NotType TDOT newId IsType { $$ = exprNode_fieldAccess ($1, $3, $4); }
 | postfixExpr NotType ARROW_OP newId IsType { $$ = exprNode_arrowAccess ($1, $3, $4); }
 | postfixExpr INC_OP { $$ = exprNode_postOp ($1, $2); }
 | postfixExpr DEC_OP { $$ = exprNode_postOp ($1, $2); }
 
unaryIterExpr
 : postfixIterExpr 
 | INC_OP unaryExpr    { $$ = exprNode_preOp ($2, $1); }
 | DEC_OP unaryExpr    { $$ = exprNode_preOp ($2, $1); }
 | TAMPERSAND castExpr { $$ = exprNode_preOp ($2, $1); }
 | TMULT castExpr      { $$ = exprNode_preOp ($2, $1); }
 | TPLUS castExpr      { $$ = exprNode_preOp ($2, $1); }
 | TMINUS castExpr     { $$ = exprNode_preOp ($2, $1); }
 | TTILDE castExpr     { $$ = exprNode_preOp ($2, $1); }
 | TEXCL castExpr      { $$ = exprNode_preOp ($2, $1); }
 | sizeofExpr          { $$ = $1; }

castIterExpr
 : unaryIterExpr 
 | TLPAREN typeExpression TRPAREN castExpr { $$ = exprNode_cast ($1, $4, $2); } 
 
timesIterExpr
 : castIterExpr 
 | timesExpr TMULT castExpr { $$ = exprNode_op ($1, $3, $2); }
 | timesExpr TDIV castExpr { $$ = exprNode_op ($1, $3, $2); }
 | timesExpr TPERCENT castExpr { $$ = exprNode_op ($1, $3, $2); }

plusIterExpr
 : timesIterExpr 
 | plusExpr TPLUS timesExpr { $$ = exprNode_op ($1, $3, $2); }
 | plusExpr TMINUS timesExpr { $$ = exprNode_op ($1, $3, $2); }

shiftIterExpr
 : plusIterExpr 
 | shiftExpr LEFT_OP plusExpr { $$ = exprNode_op ($1, $3, $2); }
 | shiftExpr RIGHT_OP plusExpr { $$ = exprNode_op ($1, $3, $2); }

relationalIterExpr
 : shiftIterExpr 
 | relationalExpr TLT shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 | relationalExpr TGT shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 | relationalExpr LE_OP shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 | relationalExpr GE_OP shiftExpr { $$ = exprNode_op ($1, $3, $2); }
 
equalityIterExpr 
 : relationalIterExpr 
 | equalityExpr EQ_OP relationalExpr { $$ = exprNode_op ($1, $3, $2); }
 | equalityExpr NE_OP relationalExpr { $$ = exprNode_op ($1, $3, $2); }

bitandIterExpr
 : equalityIterExpr 
 | bitandExpr TAMPERSAND equalityExpr { $$ = exprNode_op ($1, $3, $2); }

xorIterExpr
 : bitandIterExpr 
 | xorExpr TCIRC bitandExpr { $$ = exprNode_op ($1, $3, $2); }
; 

bitorIterExpr
 : xorIterExpr 
 | bitorExpr TBAR xorExpr { $$ = exprNode_op ($1, $3, $2); }

andIterExpr 
 : bitorIterExpr 
 | andExpr AND_OP bitorExpr { $$ = exprNode_op ($1, $3, $2); }

orIterExpr
 : andIterExpr 
 | orExpr OR_OP andExpr { $$ = exprNode_op ($1, $3, $2); }

conditionalIterExpr 
 : orIterExpr 
 | orExpr TQUEST { context_enterTrueClause ($1); } 
   expr TCOLON { context_enterFalseClause ($1); } conditionalExpr
   { $$ = exprNode_cond ($1, $4, $7); }

assignIterExpr
 : conditionalIterExpr 
 | unaryExpr TASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr MUL_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr DIV_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr MOD_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr ADD_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr SUB_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr LEFT_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr RIGHT_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr AND_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr XOR_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 
 | unaryExpr OR_ASSIGN assignExpr { $$ = exprNode_assign ($1, $3, $2); } 

endIter
 : ITER_ENDNAME { $$ = $1; }
 | /* empty */  { $$ = uentry_undefined; } 

doHeader
 : DO { context_enterDoWhileClause (); $$ = $1; }
  
iterationStmt 
 : whilePred stmt 
   { $$ = exprNode_while ($1, $2); context_exitWhileClause ($1, $2); }
 | doHeader stmt WHILE TLPAREN expr TRPAREN TSEMI 
   { $$ = exprNode_statement (exprNode_doWhile ($2, $5), $7); }
 | forPred stmt 
   { $$ = exprNode_for ($1, $2); context_exitForClause ($1, $2); }

iterationStmtErr 
 : whilePred stmtErr { $$ = exprNode_while ($1, $2); context_exitWhileClause ($1, $2); }
 | doHeader stmtErr WHILE TLPAREN expr TRPAREN TSEMI
   { $$ = exprNode_statement (exprNode_doWhile ($2, $5), $7); }
 | doHeader stmtErr WHILE TLPAREN expr TRPAREN 
   { $$ = exprNode_doWhile ($2, $5); }
 | forPred stmtErr { $$ = exprNode_for ($1, $2); context_exitForClause ($1, $2); }
 
jumpStmt
 : GOTO newId TSEMI         { $$ = exprNode_goto ($2); }
 | CONTINUE TSEMI           { $$ = exprNode_continue ($1, BADTOK); }
 | QINNERCONTINUE CONTINUE TSEMI    
                            { $$ = exprNode_continue ($1, QINNERCONTINUE); }
 | BREAK TSEMI              { $$ = exprNode_break ($1, BADTOK); }
 | QSWITCHBREAK BREAK TSEMI { $$ = exprNode_break ($2, QSWITCHBREAK); }
 | QLOOPBREAK BREAK TSEMI   { $$ = exprNode_break ($2, QLOOPBREAK); }
 | QINNERBREAK BREAK TSEMI  { $$ = exprNode_break ($2, QINNERBREAK); }
 | QSAFEBREAK BREAK TSEMI   { $$ = exprNode_break ($2, QSAFEBREAK); }
 | RETURN TSEMI             { $$ = exprNode_nullReturn ($1); }
 | RETURN expr TSEMI        { $$ = exprNode_return ($2); }
 
optSemi
 : 
 | TSEMI { ; } 

id
 : IDENTIFIER 

newId
 : NEW_IDENTIFIER 
 | ITER_NAME       { $$ = uentry_getName ($1); }
 | ITER_ENDNAME    { $$ = uentry_getName ($1); }
 | id              { $$ = uentry_getName ($1); }
 | TYPE_NAME_OR_ID { $$ = $1; } 

typeName
 : TYPE_NAME
 | TYPE_NAME_OR_ID { $$ = ctype_unknown; }

%%

/*@-redecl@*/ /*@-namechecks@*/
extern char *yytext;
/*@=redecl@*/ /*@=namechecks@*/

# include "bison.reset"

void yyerror (/*@unused@*/ char *s) 
{
  static bool givehint = FALSE;

  if (context_inIterDef ())
    {
      llerror (FLG_SYNTAX, message ("Iter syntax not parseable: %s", 
				    context_inFunctionName ()));
    }
  else if (context_inIterEnd ())
    {
      llerror (FLG_SYNTAX, message ("Iter finalizer syntax not parseable: %s", 
				    context_inFunctionName ()));
    }
  else if (context_inMacro ())
    {
      llerror (FLG_SYNTAX, message ("Macro syntax not parseable: %s", 
				    context_inFunctionName ()));
      
      if (context_inMacroUnknown ())
	{
	  if (!givehint)
	    {
	      llhint (cstring_makeLiteral 
		     ("Precede macro definition with /*@notfunction@*/ "
		      "to suppress checking and force expansion"));
	      givehint = TRUE;
	    }
	}

      swallowMacro ();
      context_exitAllClausesQuiet ();
    }
  else
    {
      llparseerror (cstring_undefined);
    }
}












