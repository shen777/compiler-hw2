/*	Definition section */
%{
    #include "common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol(char* iden,int ScopeLevel,int type, int array,int lineno);
    static int lookup_symbol(char* iden,int ScopeLevel);
    static void dump_symbol(int ScopeLevel);

    char *intrger="int32";
    char *floatnum="float32";
    char *stringptr="string";
    char *boolen="bool";
    static char* printcharptr(int type)
    {
        if(type==1)
        {
            return intrger;
        }
        else if(type==2)
        {
            return floatnum;
        }
        else if(type==3)
        {
            return stringptr;
        }
        return boolen;
    }

    int symbolTableIndex[50];
    char* symbolTableName[50];
   
    int symbolTableType[50];// 1=int32 2=float32 3=string 4=bool 5=array
    int symbolTableAddress[50];
    int symbolTableLineno[50];
    int symbolTableElementType[50];//0=not array 1=int32 2=float32 3=string 4=bool
    int symbolTableScopeLevel[50];

    int currentScopeLevel=0;
    int currentAddress=0;
    int currentIndex=0;

    int arrayFlag=0;
    int currenttype;
    int printtype=0; //0=not array 1=int32 2=float32 3=string 4=bool
    int KeepTypeFlag=0;
    int conversion=0;
    int preType=0;
    int preIsLiteral=0;
    int isLiteral=0;
    int noPrintError=0;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    int b_val;
    /* ... */
}

/* Token without return */
%token VAR
%token INT FLOAT BOOL STRING
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token ELSE FOR EQL GEQ IF LAND LEQ LOR NEQ PRINT PRINTLN NEWLINE INC DEC TRUE FALSE

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <b_val> BOOL_LIT
%token <s_val> ID

/* Nonterminal with return, which need to sepcify type */
// %type <type> Type TypeName ArrayType

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : Stmt Stmts {create_symbol();}
;

Stmts
    : Stmt Stmts
    | {dump_symbol(currentScopeLevel); }
;

Stmt
    : declarestmt NEWLINE {isLiteral=0;}
    | blockstmt  NEWLINE {isLiteral=0;}
    | ifstmt NEWLINE {isLiteral=0;}
    | forstmt NEWLINE {isLiteral=0;}
    | printstmt NEWLINE {isLiteral=0;}
    | assignmentstmt NEWLINE {isLiteral=0;}
    | expression NEWLINE {isLiteral=0;}
    | indecstmt NEWLINE {isLiteral=0;}
    | NEWLINE  {isLiteral=0;}
;
/*
simplestmt
    : assignmentstmt
    | expression
    | indecstmt
;
*/

indecstmt
    : ID INC { if(KeepTypeFlag==0){
        printtype=symbolTableElementType[lookup_symbol($1,currentScopeLevel)];}
        if(lookup_symbol($1,currentScopeLevel)==-1){printf("error\n");}
        else{printf("IDENT (name=%s, address=%d)\n",$1,symbolTableAddress[lookup_symbol($1,currentScopeLevel)]);}
        printf("INC\n");
        }
    | ID DEC { if(KeepTypeFlag==0){
        printtype=symbolTableElementType[lookup_symbol($1,currentScopeLevel)];}
        if(lookup_symbol($1,currentScopeLevel)==-1){printf("error\n");}
        else{printf("IDENT (name=%s, address=%d)\n",$1,symbolTableAddress[lookup_symbol($1,currentScopeLevel)]);}
        printf("DEC\n");
        }
;

declarestmt
    : VAR ID DCLTYPE EXTENBDASSIGNMENT {insert_symbol($2,currentScopeLevel,currenttype,arrayFlag,yylineno);arrayFlag=0;}
;

DCLTYPE
    : INT   {currenttype=1;}
    | FLOAT {currenttype=2;}
    | STRING   {currenttype=3;}
    | BOOL  {currenttype=4;}
    | '['  INT_LIT {printf("INT_LIT %d\n",$2);} ']' DCLTYPE {arrayFlag=1;}
;

EXTENBDASSIGNMENT
    : '=' ID {if(KeepTypeFlag==0){printtype=symbolTableElementType[lookup_symbol($2,currentScopeLevel)];}if(lookup_symbol($2,currentScopeLevel)==-1){printf("error\n");}else{printf("IDENT (name=%s, address=%d)\n",$2,symbolTableAddress[lookup_symbol($2,currentScopeLevel)]);}}
    | '=' expression
    |
;

expression
    :  expression {preType=printtype;}  LOR llpexpression  {
        if(printtype!=4||preType!=4)
        {
            printf("error:%d: invalid operation: (operator LOR not defined on int32)\n",yylineno);
        }
        printf("LOR\n");if(KeepTypeFlag==0){printtype=4;}}
    | llpexpression
    | '"' STRING_LIT '"' {printf("STRING_LIT %s\n",$2);}
;

hpexpression
    : hpexpression {preType=printtype;} '*' hpexpression  {
        if((printtype!=preType)&&(conversion==0)){
            printf("error:%d: invalid operation: MUL (mismatched types %s and %s)\n",yylineno,printcharptr(preType),printcharptr(printtype));
            }
        printf("MUL\n");
        }
    | hpexpression '/' hpexpression  {printf("QUO\n");}
    | hpexpression {preType=printtype;}  '%' hpexpression  {
        if(preType==2||printtype==2)
        {
            printf("error:%d: invalid operation: (operator REM not defined on float32)\n",yylineno);
        }
        printf("REM\n");}
    | unaryExpr
;

mpexpression 
    : mpexpression  {preType=printtype;} '+' hpexpression  {
        if((printtype!=preType)&&(conversion==0)){
            printf("error:%d: invalid operation: ADD (mismatched types %s and %s)\n",yylineno,printcharptr(preType),printcharptr(printtype));}
            printf("ADD\n");}
    | mpexpression {preType=printtype;} '-' hpexpression  {
        if((printtype!=preType)&&(conversion==0)){
        printf("error:%d: invalid operation: SUB (mismatched types %s and %s)\n",yylineno,printcharptr(preType),printcharptr(printtype));}
        printf("SUB\n");}
    | hpexpression
;

lpexpression
    : lpexpression EQL mpexpression  {printf("EQL\n");if(KeepTypeFlag==0){printtype=4;}}
    | lpexpression NEQ mpexpression  {printf("NEQ\n");if(KeepTypeFlag==0){printtype=4;}}
    | lpexpression LEQ mpexpression  {printf("LEQ\n");if(KeepTypeFlag==0){printtype=4;}}
    | lpexpression GEQ mpexpression  {printf("GEQ\n");if(KeepTypeFlag==0){printtype=4;}}
    | lpexpression '<' mpexpression  {printf("LSS\n");if(KeepTypeFlag==0){printtype=4;}}
    | lpexpression '>' mpexpression  {printf("GTR\n");if(KeepTypeFlag==0){printtype=4;}}
    | mpexpression
;

llpexpression
    : llpexpression  {preType=printtype;} LAND lpexpression {
        if(printtype!=4||preType!=4)
        {
            printf("error:%d: invalid operation: (operator LAND not defined on int32)\n",yylineno);
        }
        printf("LAND\n");if(KeepTypeFlag==0){printtype=4;}}
    | lpexpression
;


unaryExpr
    : primaryExpr
    | unaryOp unaryExpr
    | '!' unaryExpr {printf("NOT\n");}
;

unaryOp
    : '+' {printf("ADD\n");}
    | '-' {printf("SUB\n");}
;

primaryExpr
    : literal
    | ID { int flag1=0;
        
        if(KeepTypeFlag==0){ 
            flag1=lookup_symbol($1,currentScopeLevel);
            noPrintError=flag1;
            printtype=symbolTableElementType[flag1];
            } 
        if(flag1!=-1){printf("IDENT (name=%s, address=%d)\n",$1,symbolTableAddress[flag1]);}}
    | '(' expression ')' 
    | primaryExpr '[' {KeepTypeFlag=1;} expression ']' {KeepTypeFlag=0;}
    | INT '(' llpexpression ')'   {printf("F to I\n");conversion=1;}
    | FLOAT '(' llpexpression ')' {printf("I to F\n");conversion=1;}
;


literal
    : signLiteral
    | INT_LIT {printf("INT_LIT %d\n",$1);if(KeepTypeFlag==0){printtype=1;} isLiteral=1;}
    | FLOAT_LIT {printf("%s %f\n", "FLOAT_LIT",$1);if(KeepTypeFlag==0){printtype=2;}}
    | BOOL_LIT  {printf("%s\n", "BOOL_LIT"); printf($1?"true":"false");if(KeepTypeFlag==0){printtype=4;}}
    | '"' STRING_LIT '"'  {printf("STRING_LIT %s\n",$2); if(KeepTypeFlag==0){printtype=3;}}
    | TRUE {printf("TRUE\n");if(KeepTypeFlag==0){printtype=4;}}
    | FALSE {printf("FALSE\n");if(KeepTypeFlag==0){printtype=4;}}
;

signLiteral
    : '+' INT_LIT {printf("INT_LIT %d\nPOS\n",$2);}
    | '-' INT_LIT {printf("INT_LIT %d\nNEG\n",$2);}
    | '+' FLOAT_LIT {printf("FLOAT_LIT %f\nPOS\n",$2);}
    | '-' FLOAT_LIT {printf("FLOAT_LIT %f\nNEG\n",$2);}




assignmentstmt
    : expression {preIsLiteral=isLiteral;isLiteral=0;} ADD_ASSIGN expression {
        if(preIsLiteral)
        {
            printf("error:%d: cannot assign to int32\n",yylineno);
        }
        printf("ADD_ASSIGN\n");}
    | expression  SUB_ASSIGN expression {printf("SUB_ASSIGN\n");}
    | expression  MUL_ASSIGN expression {printf("MUL_ASSIGN\n");}
    | expression  QUO_ASSIGN expression {printf("QUO_ASSIGN\n");}
    | expression  REM_ASSIGN expression {printf("REM_ASSIGN\n");}
    | expression {preType=printtype;} '=' expression { if((printtype!=preType)&&(conversion==0)&&(noPrintError!=-1)){
            printf("error:%d: invalid operation: ASSIGN (mismatched types %s and %s)\n",yylineno,printcharptr(preType),printcharptr(printtype));
            }
            printf("ASSIGN\n");} 
;



blockstmt
    : '{' NEWLINE {currentScopeLevel++;} Stmts '}' { currentScopeLevel--;}
;


ifstmt
    : IF condition {if(printtype!=4){printf("error:%d: non-bool (type %s) used as for condition\n",yylineno+1,printcharptr(printtype));}} blockstmt elsestmt
;

condition
    : expression
;

elsestmt
    : ELSE ifstmt
    | ELSE blockstmt
    |
;

forstmt
    : FOR condition {if(printtype!=4){printf("error:%d: non-bool (type %s) used as for condition\n",yylineno+1,printcharptr(printtype));}} blockstmt
    | FOR forclause blockstmt
;

forclause
    : initstmt ';' condition ';' poststmt
;

initstmt
    : assignmentstmt
    | expression
    | indecstmt
;

poststmt
    : assignmentstmt
    | expression
    | indecstmt
;

printstmt
    : PRINT {printtype=3;} expression  {
        if(printtype==1)
        {
            printf("PRINT int32\n");
        }
        else if(printtype==2)
        {
            printf("PRINT float32\n");
        }
        else if(printtype==3)
        {
            printf("PRINT string\n");
        }
        else if(printtype==4)
        {
            printf("PRINT bool\n");
        }
        else
        {
             printf("PRINT error\n");
        }
    }
    | PRINTLN {printtype=3;} expression  {
        if(printtype==1)
        {
            printf("PRINTLN int32\n");
        }
        else if(printtype==2)
        {
            printf("PRINTLN float32\n");
        }
        else if(printtype==3)
        {
            printf("PRINTLN string\n");
        }
        else if(printtype==4)
        {
            printf("PRINTLN bool\n");
        }
        else
        {
             printf("PRINTLN error\n");
        }
    }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 0;
    yyparse();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
   return;
}

static void insert_symbol(char* iden,int ScopeLevel,int type, int array,int lineno) {
    //printf("currentIndex=%d\n",currentIndex);
    //printf("currentSCOPELEVEL=%d\n",ScopeLevel);
    for(int i=0;i<currentIndex;i++)
    {
        if(strcmp(iden,symbolTableName[i])==0 && ScopeLevel==symbolTableScopeLevel[i])
        {
            printf("error:%d: %s redeclared in this block. previous declaration at line %d\n",yylineno,iden,symbolTableLineno[i]);
            return;
        }
    }
    symbolTableScopeLevel[currentIndex]=ScopeLevel;
    symbolTableName[currentIndex]=iden;
    symbolTableAddress[currentIndex]=currentAddress;
    currentAddress++;
    
    symbolTableIndex[currentIndex]=currentIndex;
    symbolTableLineno[currentIndex]=lineno;

    if(array==1)
    {
        //is array
        symbolTableType[currentIndex]=5;
        symbolTableElementType[currentIndex]=type;
    }
    else
    {
        symbolTableElementType[currentIndex]=type;
        symbolTableType[currentIndex]=type;
    }
    printf("> Insert {%s} into symbol table (scope level: %d)\n", symbolTableName[currentIndex], ScopeLevel);
    /*
    printf("> Insert symbol table (scope level: %d)\n", ScopeLevel);
    printf("%-10s%-10s%-10s%-10s%-10s%s\n",
           "Index", "Name", "Type", "Address", "Lineno", "Element type");
    printf("%-10d%-10s%-10d%-10d%-10d%d\n",
                    currentIndex, symbolTableName[currentIndex],symbolTableType[currentIndex], symbolTableAddress[currentIndex], symbolTableLineno[currentIndex], symbolTableElementType[currentIndex]);
    */
    currentIndex++;
    return;
}

static int lookup_symbol(char* iden,int ScopeLevel) {
    //printf("currentIndex=%d\n",currentIndex);
    for(int i=currentIndex-1;i>=0;i--)
    {
        if(strcmp(iden,symbolTableName[i])==0)
        {
            return i;
        }
    }
    printf("error:%d: undefined: %s\n",yylineno+1,iden);
    return -1;
}

static void dump_symbol(int ScopeLevel) {
    //printf("currentIndex=%d\n",currentIndex);
    //printf("currentSCOPELEVEL=%d\n",ScopeLevel);
    //printf("currentScopeLevel=%d    currentIndex=%d\n",ScopeLevel,currentIndex);
    printf("> Dump symbol table (scope level: %d)\n", ScopeLevel);
    printf("%-10s%-10s%-10s%-10s%-10s%s\n",
           "Index", "Name", "Type", "Address", "Lineno", "Element type");
    int flag=0;
    int newIndex=currentIndex;
    int printindex=-1;
    for(int i=0;i<currentIndex;i++)
    {
        if(symbolTableScopeLevel[i]==ScopeLevel)
        {
            printindex++;
            //printf("dump\n");
            if(flag==0)
            {
                flag=1;
                newIndex=i;
            }
            if(symbolTableType[i]==5)
            {
                //array
                if(symbolTableElementType[i]==1)
                {
                    //int32
                    printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "array", symbolTableAddress[i], symbolTableLineno[i], "int32");
                }
                else if(symbolTableElementType[i]==2)
                {
                    //float32
                     printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "array", symbolTableAddress[i], symbolTableLineno[i], "float32");
                }
                else if(symbolTableElementType[i]==3)
                {
                    //string
                     printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "array", symbolTableAddress[i], symbolTableLineno[i], "string");
                }
                else if(symbolTableElementType[i]==4)
                {
                    //bool
                     printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "array", symbolTableAddress[i], symbolTableLineno[i], "bool");
                }
                else
                {
                    printf("error!!!!!\n");
                }
            }
            else
            {
                if(symbolTableType[i]==1)
                {
                    //int32
                     printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "int32", symbolTableAddress[i], symbolTableLineno[i], "-");
                }
                else if(symbolTableType[i]==2)
                {
                    //float32
                     printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "float32", symbolTableAddress[i], symbolTableLineno[i], "-");
                }
                else if(symbolTableType[i]==3)
                {
                    //string
                     printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "string", symbolTableAddress[i], symbolTableLineno[i], "-");
                }
                else if(symbolTableType[i]==4)
                {
                    //bool
                     printf("%-10d%-10s%-10s%-10d%-10d%s\n",
                    printindex, symbolTableName[i], "bool", symbolTableAddress[i], symbolTableLineno[i], "-");
                }
                else
                {
                    printf("error!!!!!!\n");
                }
            }
             
        }
    }
   currentIndex=newIndex;
   //printf("currentIndex=%d\n",currentIndex);
}
