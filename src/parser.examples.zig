const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const Allocator = mem.Allocator;

use @import("parser.zig");

const TreeNode = struct { 
    symbol: u8, 
    left: &Tree, 
    right: &Tree
};

const Visitor = struct {
    const Self = this;

    visitLeaf: fn(self: &Self, leaf: i64) -> %void,
    visitNode: fn(self: &Self, node: &TreeNode) -> %void,
    visitPar: fn(self: &Self, child: &Tree) -> %void,

    fn visit(self: &Self, tree: &Tree) -> %void {
        switch (*tree) {
            Tree.Leaf => | leaf| return self.visitLeaf(self, leaf),
            Tree.Node => |*node| return self.visitNode(self, node),
            Tree.Par  => |child| return self.visitPar(self, child),
        }
    }
};

const Tree = union(enum) {
    const Self = this;

    Leaf: i64,
    Par: &Tree,
    Node: TreeNode,

    pub fn destroy(self: &const Self, allocator: &Allocator) {
        switch (*self) {
            Self.Node => |node| {
                node.left.destroy(allocator);
                node.right.destroy(allocator);
            },
            Self.Par => |child| {
                child.destroy(allocator);
            },
            else => { }
        }
        
        allocator.destroy(self);
    }

    pub fn createLeaf(allocator: &Allocator, value: i64) -> %&Tree {
        const result = %return allocator.create(Tree);
        *result = Tree { .Leaf = value };
        return result;
    }

    pub fn createNode(allocator: &Allocator, symbol: u8, left: &Tree, right: &Tree) -> %&Tree {
        const result = %return allocator.create(Tree);
        *result = Tree { .Node = TreeNode { .symbol = symbol, .left = left, .right = right } };
        return result;
    }

    pub fn createPar(allocator: &Allocator, child: &Tree) -> %&Tree {
        const result = %return allocator.create(Tree);
        *result = Tree { .Par = child };
        return result;
    }
};

fn toLeaf(str: &const []u8, allocator: &Allocator, cleanUp: CleanUp([]u8)) -> %&Tree {
    defer cleanUp(str, allocator);

    const i = %return std.fmt.parseInt(i64, *str, 10);
    return Tree.createLeaf(allocator, i);
}

fn toPar(tree: &const &Tree, allocator: &Allocator, cleanUp: CleanUp(&Tree)) -> %&Tree {
    %defer cleanUp(tree, allocator);
    return Tree.createPar(allocator, *tree);
}

fn treeCleanUp(tree: &const &Tree, allocator: &Allocator) {
    (*tree).destroy(allocator);
}

fn apply(allocator: &Allocator, treeClean: CleanUp(&Tree), opClean: CleanUp(u8), 
    left: &const &Tree, right: &const &Tree, op: &const u8) -> %&Tree {
    %defer {
        treeClean(left , allocator);
        treeClean(right, allocator);
    }
    defer opClean(op, allocator);

    const result = %return Tree.createNode(allocator, *op, *left, *right);
    return result;
}

fn getPrecedence(symbol: u8) -> u8 {
    switch (symbol) {
        '+', '-' => return 4,
        '*', '/' => return 3,
        else => unreachable
    }
}

fn printLeaf(self: &Visitor, leaf: i64) -> %void {
    debug.warn("{}", leaf);
}


fn printPar(self: &Visitor, child: &Tree) -> %void {
    debug.warn("(");
    %return self.visit(child);
    debug.warn(")");
}

fn printNode(self: &Visitor, node: &TreeNode) -> %void {
    %return self.visit(node.left);
    debug.warn(" {} ", [1]u8{ node.symbol });
    %return self.visit(node.right);
}

fn precedenceLeaf(self: &Visitor, leaf: i64) -> %void { }
fn precedencePar(self: &Visitor, par: &Tree) -> %void { return self.visit(par); }

fn precedenceNodeLeft(self: &Visitor, node: &TreeNode) -> %void {
    %return self.visit(node.left);
    switch (*node.left) {
        Tree.Node => |*left| {
            if (getPrecedence(left.symbol) > getPrecedence(node.symbol)) {
                return error.ParserError;
            }
        },
        else => {}
    }

    %return self.visit(node.right);
    switch (*node.right) {
        Tree.Node => |*right| {
            if (getPrecedence(right.symbol) >= getPrecedence(node.symbol)) {
                return error.ParserError;
            }
        },
        else => {}
    }
}

fn precedenceNodeRight(self: &Visitor, node: &TreeNode) -> %void {
    %return self.visit(node.left);
    switch (*node.left) {
        Tree.Node => |*left| {
            if (getPrecedence(left.symbol) >= getPrecedence(node.symbol)) {
                return error.ParserError;
            }
        },
        else => {}
    }

    %return self.visit(node.right);
    switch (*node.right) {
        Tree.Node => |*right| {
            if (getPrecedence(right.symbol) > getPrecedence(node.symbol)) {
                return error.ParserError;
            }
        },
        else => {}
    }
}

const operators = 
    \\1 + (1 - 2) *
    \\1 - (1 + 2) /
    \\1 + (1 - 2) *
    \\1 - (1 + 2)
;

const number      = comptime digit.atLeastOnce().trim().convertWithCleanUp(&Tree, toLeaf, treeCleanUp);
const addSubChars = comptime char('+').orElse(char('-')).trim();
const mulDivChars = comptime char('*').orElse(char('/')).trim();

const Left = struct {
    fn exprRef() -> &const ParserWithCleanup(&Tree, treeCleanUp) {
        return expr;
    }

    const program     = expr.voidAfter(end);
    const expr        = comptime chainOperatorLeft(&Tree, u8, treeCleanUp, defaultCleanUp(u8), term, addSubChars, apply);
    const term        = comptime chainOperatorLeft(&Tree, u8, treeCleanUp, defaultCleanUp(u8), factor, mulDivChars, apply);
    const factor      = comptime number.orElse(
        ref(&Tree, treeCleanUp, exprRef)
            .voidSurround(
                char('(').discard(),
                char(')').discard())
            .convertWithCleanUp(&Tree, toPar, treeCleanUp)
    );
};

test "parser.Example: Left Precedence Expression Parser" {
    var input = Input.init(operators);
    var res = Left.program.parse(debug.global_allocator, &input) %% unreachable;
    var leftVisitor = Visitor {
        .visitLeaf = precedenceLeaf,
        .visitNode = precedenceNodeLeft,
        .visitPar = precedencePar,
    };
    
    leftVisitor.visit(res) %% unreachable;

    var rightVisitor = Visitor {
        .visitLeaf = precedenceLeaf,
        .visitNode = precedenceNodeRight,
        .visitPar = precedencePar,
    };
    
    if (rightVisitor.visit(res)) |v| {
        unreachable;
    } else |err| { }
}

const Right = struct {
    fn exprRef() -> &const ParserWithCleanup(&Tree, treeCleanUp) {
        return expr;
    }

    const program     = expr.voidAfter(end);
    const expr        = comptime chainOperatorRight(&Tree, u8, treeCleanUp, defaultCleanUp(u8), term, addSubChars, apply);
    const term        = comptime chainOperatorRight(&Tree, u8, treeCleanUp, defaultCleanUp(u8), factor, mulDivChars, apply);
    const factor      = comptime number.orElse(
        ref(&Tree, treeCleanUp, exprRef)
            .voidSurround(
                char('(').discard(),
                char(')').discard())
            .convertWithCleanUp(&Tree, toPar, treeCleanUp)
    );
};

test "parser.Example: Right Precedence Expression Parser" {
    var input = Input.init(operators);
    var res = Right.program.parse(debug.global_allocator, &input) %% unreachable;
    var leftVisitor = Visitor {
        .visitLeaf = precedenceLeaf,
        .visitNode = precedenceNodeLeft,
        .visitPar = precedencePar,
    };
    
    if (leftVisitor.visit(res)) |v| {
        unreachable;
    } else |err| { }

    var rightVisitor = Visitor {
        .visitLeaf = precedenceLeaf,
        .visitNode = precedenceNodeRight,
        .visitPar = precedencePar,
    };
    
    rightVisitor.visit(res) %% unreachable;
}


/// TODO: This is not done. As long as nothing is used from inside ZigSyntax, all tests
///       should still compile
const ZigSyntax = struct {
    // Root = many(TopLevelItem) EOF
    pub const root = comptime 
        topLevelItem.many()
            .then(end);

    // TopLevelItem = ErrorValueDecl | CompTimeExpression(Block) | TopLevelDecl | TestDecl
    pub const topLevelItem = 
        errorValueDecl
            .orElse(compTimeExpression)
            .orElse(topLevelDecl)
            .orElse(testDecl);
    
    // TestDecl = "test" String Block
    pub const testDecl = 
        string("test")
            .then(stringLit)
            .then(block);

    // TopLevelDecl = option("pub") (FnDef | ExternDecl | GlobalVarDecl | UseDecl)
    pub const topLevelDecl =
        string("pub").optional()
            .then(
                fnDef
                    .orElse(externDecl)
                    .orElse(globalVarDecl)
                    .orElse(useDecl)
            );

    // ErrorValueDecl = "error" Symbol ";"
    pub const errorValueDecl =
        string("error")
            .then(symbol)
            .then(char(';'));

    // GlobalVarDecl = option("export") VariableDeclaration ";"
    pub const globalVarDecl =
        string("error").optional()
            .then(variableDeclaration)
            .then(char(';'));

    // LocalVarDecl = option("comptime") VariableDeclaration
    pub const localVarDecl = 
        string("comptime").optional()
            .then(variableDeclaration);

    // VariableDeclaration = ("var" | "const") Symbol option(":" TypeExpr) option("align" "(" Expression ")") option("section" "(" Expression ")") "=" Expression
    pub const variableDeclaration =
        string("var").orElse(string("const"))
            .then(symbol)
            .then(
                char(':')
                    .then(typeExpr)
                    .optional()
            )
            .then(
                string("align")
                    .then(char('('))
                    .then(expression)
                    .then(char(')'))
                    .optional()
            )
            .then(
                string("section")
                    .then(char('('))
                    .then(expression)
                    .then(char(')'))
                    .optional()
            )
            .then(char('='))
            .then(expression);

    // ContainerMember = (ContainerField | FnDef | GlobalVarDecl)
    pub const containerMember = 
        containerField
            .orElse(fnDef)
            .orElse(globalVarDecl);

    // UseDecl = "use" Expression ";"
    pub const useDecl =
        string("use")
            .then(expression)
            .then(char(';'));

    // ExternDecl = "extern" option(String) (FnProto | VariableDeclaration) ";"
    pub const externDecl =
        string("extern")
            .then(stringLit.optional())
            .then(fnProto.orElse(variableDeclaration))
            .then(char(';'));

    // FnProto = option("coldcc" | "nakedcc" | "stdcallcc" | "extern") "fn" option(Symbol) ParamDeclList option("align" "(" Expression ")") option("section" "(" Expression ")") option("-&gt;" TypeExpr)
    pub const fnProto =
        string("coldcc")
            .orElse(string("nakedcc"))
            .orElse(string("stdcallcc"))
            .orElse(string("extern"))
            .then(string("fn"))
            .then(symbol.optional())
            .then(paramDeclList)
            .then(
                string("align")
                    .then(char('('))
                    .then(expression)
                    .then(char(')'))
                    .optional()
            )
            .then(
                string("section")
                    .then(char('('))
                    .then(expression)
                    .then(char(')'))
                    .optional()
            )
            .then(
                string("->")
                    .then(typeExpr)
                    .optional()
            );

    // FnDef = option("inline" | "export") FnProto Block
    pub const fnDef = 
        string("inline")
            .orElse("export")
            .optional()
            .then(fnProto)
            .then(block);

    // ParamDeclList = "(" list(ParamDecl, ",") ")"
    pub const paramDeclList =
        char('(')
            .then(
                paramDecl
                    .then(char(','))
                    .many()
            )
            .then(char(')'));

    // ParamDecl = option("noalias" | "comptime") option(Symbol ":") (TypeExpr | "...")
    pub const paramDecl =
        string("noalias")
            .orElse(string("comptime"))
            .optional()
            .then(
                symbol
                    .then(char(':'))
                    .optional()
            )
            .then(typeExpr.orElse(string("...")));

    // Block = option(Symbol ":") "{" many(Statement) "}"
    pub const block =
        symbol
            .then(char(':'))
            .optional()
            .then(char('{'))
            .then(statement.many())
            .then(char('}'));

    // Statement = LocalVarDecl ";" | Defer(Block) | Defer(Expression) ";" | BlockExpression(Block) | Expression ";" | ";"
    pub const statement =
        localVarDecl.then(char(';'))
            .orElse(deferP(block))
            .orElse(deferP(expression).then(char(';')))
            .orElse(blockExpression(block))
            .orElse(expression.then(char(';')))
            .orElse(char(';'));

    // TypeExpr = PrefixOpExpression | "var"
    pub const typeExpr = 
        prefixOpExpression.orElse(string("var"));

    // BlockOrExpression = Block | Expression
    pub const blockOrExpression =
        block.orElse(expression);

    // Expression = ReturnExpression | BreakExpression | AssignmentExpression
    pub const expression = 
        ReturnExpression
            .orElse(breakExpression)
            .orElse(assignmentExpression);
            
    // AsmExpression = "asm" option("volatile") "(" String option(AsmOutput) ")"
    pub const asmExpression =
        string("asm")
            .then(string("volatile").optional())
            .then(char('('))
            .then(stringLit)
            .then(asmOutput.optional())
            .then(char(')'));

    // AsmOutput = ":" list(AsmOutputItem, ",") option(AsmInput)
    pub const asmOutput =
        char(':')
            .then(
                asmOutputItem
                    .then(char(','))
                    .many()
            )
            .then(asmInput);

    // AsmInput = ":" list(AsmInputItem, ",") option(AsmClobbers)
    pub const asmInput =
        char(':')
            .then(
                asmInputItem
                    .then(char(','))
                    .many()
            )
            .then(asmClobbers);

    // AsmOutputItem = "[" Symbol "]" String "(" (Symbol | "-&gt;" TypeExpr) ")"
    pub const asmOutputItem =
        char('[')
            .then(symbol)
            .then(char(']'))
            .then(stringLit)
            .then(char('('))
            .then(symbol.orElse(string("->").then(typeExpr)))
            .then(char(')'));

    // AsmInputItem = "[" Symbol "]" String "(" Expression ")"
    pub const asmInputItem =
        char('[')
            .then(symbol)
            .then(char(']'))
            .then(stringLit)
            .then(char('('))
            .then(expression)
            .then(char(')'));

    // AsmClobbers= ":" list(String, ",")
    pub const asmCloppers =
        char(':').then(
                stringLit
                    .then(char(','))
                    .many()
            );

    // UnwrapExpression = BoolOrExpression (UnwrapNullable | UnwrapError) | BoolOrExpression
    pub const unwrapExpression =
        BoolOrExpression
            .then(
                unwrapNullable
                    .orElse(unwrapError)
                    .optional()
            );

    // UnwrapNullable = "??" Expression
    pub const unwrapNullable =
        string("??").then(expression);
        
    // UnwrapError = "%%" option("|" Symbol "|") Expression
    pub const unwrapError =
        string("%%")
            .then(
                char('|')
                    .then(symbol)
                    .then(char('|'))
                    .optional()
            )
            .then(expression);
            
    // AssignmentExpression = UnwrapExpression AssignmentOperator UnwrapExpression | UnwrapExpression
    pub const assignmentExpression =
        unwrapExpression
            .then(assignmentOperator)
            .then(unwrapExpression)
            .orElse(UnwrapExpression);

    // AssignmentOperator = "=" | "*=" | "/=" | "%=" | "+=" | "-=" | "&lt;&lt;=" | "&gt;&gt;=" | "&amp;=" | "^=" | "|=" | "*%=" | "+%=" | "-%="
    pub const assigmentOperator =
        char('=')
            .orElse(string("*="))
            .orElse(string("/="))
            .orElse(string("%="))
            .orElse(string("+="))
            .orElse(string("-="))
            .orElse(string("<<="))
            .orElse(string(">>="))
            .orElse(string("&="))
            .orElse(string("^="))
            .orElse(string("|="))
            .orElse(string("*%="))
            .orElse(string("+%="))
            .orElse(string("-%="));

    //  BlockExpression(body) = Block | IfExpression(body) | TryExpression(body) | TestExpression(body) | WhileExpression(body) | ForExpression(body) | SwitchExpression | CompTimeExpression(body)
    pub fn blockExpression(comptime body: var) -> Parser(void) {
        return 
            block
                .orElse(ifExpression(body))
                .orElse(tryExpression(body))
                .orElse(testExpression(body))
                .orElse(whileExpression(body))
                .orElse(forExpression(body))
                .orElse(switchExpression)
                .orElse(comparisonExpression(body));
    }

    // CompTimeExpression(body) = "comptime" body
    pub fn compTimeExpression(comptime body: var) -> Parser(void) {
        return 
            string("comptime")
                .then(body);
    }

    // SwitchExpression = "switch" "(" Expression ")" "{" many(SwitchProng) "}"
    pub const switchExpression =
        string("string")
            .then(char('('))
            .then(expression)
            .then(char(')'))
            .then(char('{'))
            .then(switchProng.many())
            .then(char('}'));

    // SwitchProng = (list(SwitchItem, ",") | "else") "=&gt;" option("|" option("*") Symbol "|") Expression ","
    pub const switchProng =
        switchItem.then(char(',')).many()
            .orElse(string("else"))
            .then(string("=>"))
            .then(
                char('|')
                    .then(char('*').optional())
                    .then(symbol)
                    .then(char('|'))
                    .optional()
            )
            .then(expression)
            .then(char(','));

    // SwitchItem = Expression | (Expression "..." Expression)
    pub const switchItem =
        expression
            .orElse(
                expression
                    .then(string("..."))
                    .then(expression)
            );

    // ForExpression(body) = option(Symbol ":") option("inline") "for" "(" Expression ")" option("|" option("*") Symbol option("," Symbol) "|") body option("else" BlockExpression(body))
    pub fn forExpression(comptime body: var) -> Parser(void) {
        return
            symbol.then(char(':')).optional()
                .then(string("inline").optional)
                .then(string("for"))
                .then(char('('))
                .then(expression)
                .then(char(')'))
                .then(
                    char('|')
                        .then(char('*').optional())
                        .then(symbol)
                        .then(
                            char(',')
                                .then(symbol)
                                .optional()
                        )
                        .then(char('|'))
                        .optional()
                )
                .then(body)
                .then(
                    string("else")
                        .then(blockExpression(body))
                );
    }

    // BoolOrExpression = BoolAndExpression "or" BoolOrExpression | BoolAndExpression
    pub const boolOrExpression =
        BoolAndExpression
            .then(string("or"))
            .then(boolOrExpression)
            .orElse(boolAndExpression);

    // ReturnExpression = option("%") "return" option(Expression)
    pub const returnExpression =
        char('%').optional()
            .then(string("return"))
            .then(expression.optional());

    // BreakExpression = "break" option(":" Symbol) option(Expression)
    pub const breakExpression =
        string("break")
            .then(
                char(':')
                    .then(symbol)
                    .optional()
            )
            .then(expression.optional());

    // Defer(body) = option("%") "defer" body
    pub fn deferP(comptime body: var) -> Parser(void) {
        return
            char('%').optional()
                .then(string("defer"))
                .then(body);
    }

    // IfExpression(body) = "if" "(" Expression ")" body option("else" BlockExpression(body))
    pub fn ifExpression(comptime body: var) -> Parser(void) {
        return
            string("if")
                .then(char('('))
                .then(expression)
                .then(char(')'))
                .then(body)
                .then(
                    string("else")
                        .then(blockExpression(body))
                        .optional()
                );
    }

    // TryExpression(body) = "if" "(" Expression ")" option("|" option("*") Symbol "|") body "else" "|" Symbol "|" BlockExpression(body)
    pub fn tryExpression(comptime body: var) -> Parser(void) {
        return
            string("if")
                .then(char('('))
                .then(expression)
                .then(char(')'))
                .then(
                    char('|')
                        .then(char('*').optional())
                        .then(symbol)
                        .then(char('|'))
                        .optional()
                )
                .then(body)
                .then(string("else"))
                .then(char('|'))
                .then(symbol)
                .then(char('|'))
                .then(blockExpression(body));
    }

    // TestExpression(body) = "if" "(" Expression ")" option("|" option("*") Symbol "|") body option("else" BlockExpression(body))
    pub fn testExpression(comptime body: var) -> Parser(void) {
        return
            string("if")
                .then(char('('))
                .then(expression)
                .then(char(')'))
                .then(
                    char('|')
                        .then(char('*').optional())
                        .then(symbol)
                        .then(char('|'))
                        .optional()
                )
                .then(body)
                .then(
                    string("else")
                        .then(blockExpression(body))
                        .optional()
                );
    }

    // WhileExpression(body) = option(Symbol ":") option("inline") "while" "(" Expression ")" option("|" option("*") Symbol "|") option(":" "(" Expression ")") body option("else" option("|" Symbol "|") BlockExpression(body))
    pub fn whileExpression(comptime body: var) -> Parser(void) {
        return
            symbol
                .then(char(':'))
                .optional()
                .then(string("inline").optional())
                .then(string("while"))
                .then(char('('))
                .then(expression)
                .then(char(')'))
                .then(
                    char('|')
                        .then(char('*').optional())
                        .then(symbol)
                        .then(char('|'))
                        .optional()
                )
                .then(
                    char(':')
                        .then(char('('))
                        .then(expression)
                        .then(char(')'))
                )
                .then(body)
                .then(
                    string("else")
                        .then(
                            char('|')
                                .then(symbol)
                                .then(char('|'))
                                .optional()
                        )
                        .then(blockExpression(body))
                );
    }

    // BoolAndExpression = ComparisonExpression "and" BoolAndExpression | ComparisonExpression
    pub const boolAndExpression =
        comparisonExpression
            .then(string("and"))
            .then(boolAndExpression)
            .orElse(comparisonExpression);


    // ComparisonExpression = BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression
    pub const comparisonExpression =
        binaryOrExpression
            .then(comparisonOperator)
            .then(binaryOrExpression)
            .orElse(binaryOrExpression);

    // ComparisonOperator = "==" | "!=" | "&lt;" | "&gt;" | "&lt;=" | "&gt;="
    pub const comparisonOperator =
        string("==")
            .orElse(string("!="))
            .orElse(char('<'))
            .orElse(char('>'))
            .orElse(string("<="))
            .orElse(string(">="));

    // CompTimeExpression(body) = "comptime" body
    pub fn compTimeExpression(comptime body: var) -> Parser(void) {
        return
            string("comptime")
                .then(body);
    }

    // SwitchExpression = "switch" "(" Expression ")" "{" many(SwitchProng) "}"
    pub const switchExpression =
        string("string")
            .then(char('('))
            .then(expression)
            .then(char(')'))
            .then(char('{'))
            .then(switchProng.many())
            .then(char('}'));

    // SwitchProng = (list(SwitchItem, ",") | "else") "=&gt;" option("|" option("*") Symbol "|") Expression ","
    pub const switchProng =
        switchItem.then(char(',')).many() // TODO: Implement 'list'
            .orElse(string("else"))
            .then(string("=>"))
            .then(
                char('|')
                    .then(char('*').optional())
                    .then(symbol)
                    .then(char('|'))
                    .optional()
            )
            .then(expression)
            .then(char(','));

    // SwitchItem = Expression | (Expression "..." Expression)
    pub const switchItem =
        expression
            .then(string("..."))
            .then(expression)
            .orElse(expression);
            
    // ForExpression(body) = option(Symbol ":") option("inline") "for" "(" Expression ")" option("|" option("*") Symbol option("," Symbol) "|") body option("else" BlockExpression(body))
    pub fn forExpression(comptime body: var) -> Parser(void) {
        return 
            symbol.then(char(':')).optional()
                .then(string("inline").optional())
                .then(string("for"))
                .then(char('('))
                .then(expression)
                .then(char(')'))
                .then(
                    char('|')
                        .then(char('*').optional())
                        .then(symbol)
                        .then(char('|'))
                        .optional()
                )
                .then(body)
                .then(
                    string("else")
                        .then(blockExpression(body))
                        .optional()
                );
    }

    // BoolOrExpression = BoolAndExpression "or" BoolOrExpression | BoolAndExpression
    pub const boolOrExpression =
        boolAndExpression
            .then(string("or"))
            .then(boolOrExpression)
            .orElse(boolAndExpression);

    // ReturnExpression = option("%") "return" option(Expression)
    pub const returnExpression =
        char('%').optional()
            .then(string("return"))
            .then(expression.optional());

    // BreakExpression = "break" option(":" Symbol) option(Expression)
    pub const breakExpression =
        string("break")
            .then(
                char(':')
                    .then(symbol)
                    .optional()
            )
            .then(expression.optional());

    // Defer(body) = option("%") "defer" body
    pub fn deferP(comptime body: var) -> Parser(void) {
        char('%').optional()
            .then(string("return"))
            .then(body);
    }

    // IfExpression(body) = "if" "(" Expression ")" body option("else" BlockExpression(body))
    pub fn ifExpression(comptime body: var) -> Parser(void) {
        return
            string("if")
                .then(char('('))
                .then(expression)
                .then(char(')'))
                .then(body)
                .then(
                    string("else")
                        .then(blockExpression(body))
                        .optional()
                );
    }

    // BinaryOrExpression = BinaryXorExpression "|" BinaryOrExpression | BinaryXorExpression
    pub const binaryOrExpression =
        binaryXorExpression
            .then(char('|'))
            .then(binaryOrExpression)
            .orElse(binaryXorExpression);

    // BinaryXorExpression = BinaryAndExpression "^" BinaryXorExpression | BinaryAndExpression
    pub const binaryXorExpression =
        binaryAndExpression
            .then(char('^'))
            .then(binaryXorExpression)
            .orElse(binaryAndExpression);

    //BinaryAndExpression = BitShiftExpression "&amp;" BinaryAndExpression | BitShiftExpression
    pub const binaryAndExpression =
        bitShiftExpression
            .then(char('&'))
            .then(binaryAndExpression)
            .orElse(bitShiftExpression);

    //BitShiftExpression = AdditionExpression BitShiftOperator BitShiftExpression | AdditionExpression
    pub const bitShiftExpression =
        additionExpression
            .then(bitShiftOperator)
            .then(bitShiftExpression)
            .orElse(additionExpression);

    // BitShiftOperator = "&lt;&lt;" | "&gt;&gt;" | "&lt;&lt;"
    pub const bitShiftOperator =
        string("<<")
            .orElse(string(">>"));

    // AdditionExpression = MultiplyExpression AdditionOperator AdditionExpression | MultiplyExpression
    pub const additionExpression =
        multiplyExpression
            .then(additionOperator)
            .then(additionExpression)
            .orElse(multiplyExpression);

    // AdditionOperator = "+" | "-" | "++" | "+%" | "-%"
    pub const additionOperator =
        char('+')
            .orElse(char('-'))
            .orElse(string("++"))
            .orElse(string("+%"))
            .orElse(string("-%"));

    // MultiplyExpression = CurlySuffixExpression MultiplyOperator MultiplyExpression | CurlySuffixExpression
    pub const multiplyExpression =
        curlySuffixExpression
            .then(multiplyOperator)
            .then(multiplyExpression)
            .orElse(curlySuffixExpression);

    // MultiplyOperator = "*" | "/" | "%" | "**" | "*%"
    pub const additionOperator =
        char('*')
            .orElse(char('/'))
            .orElse(string("%"))
            .orElse(string("**"))
            .orElse(string("*%"));

    // CurlySuffixExpression = TypeExpr option(ContainerInitExpression)
    pub const curlySuffixExpression =
        typeExpr
            .then(containerInitExpression.optional());

    // PrefixOpExpression = PrefixOp PrefixOpExpression | SuffixOpExpression
    pub const prefixOpExpression = 
        prefixOp
            .then(prefixOpExpression)
            .orElse(suffixOpExpression);

    // SuffixOpExpression = PrimaryExpression option(FnCallExpression | ArrayAccessExpression | FieldAccessExpression | SliceExpression)
    pub const suffixOpExpression = 
        primaryExpression
            .then(
                fnCallExpression
                    .orElse(arrayAccessExpression)
                    .orElse(fieldAccessExpression)
                    .orElse(sliceExpression)
                    .optional()
            );

    // FieldAccessExpression = "." Symbol
    pub const fieldAccessExpression =
        char('.')
            .then(symbol);

    // FnCallExpression = "(" list(Expression, ",") ")"
    pub const fnCallExpression =
        char('(')
            .then(
                expression
                    .then(char(','))
                    .many()
            )
            .then(char(')'));

    // ArrayAccessExpression = "[" Expression "]"
    pub const arrayAccessExpression =
        char('[')
            .then(expression)
            .then(char(']'));

    // SliceExpression = "[" Expression ".." option(Expression) "]"
    pub const sliceExpression =
        char('[')
            .then(expression)
            .then(string(".."))
            .then(expression.optional())
            .then(char(']'));

    // ContainerInitExpression = "{" ContainerInitBody "}"
    pub const containerInitExpression =
        char('{')
            .then(containerInitBody)
            .then(char('}'));

    // ContainerInitBody = list(StructLiteralField, ",") | list(Expression, ",")
    pub const containerInitBody =
        structLiteralField.then(',').many()
            .orElse(
                expression
                    .then(char(','))
                    .many()
            );

    // StructLiteralField = "." Symbol "=" Expression
    pub const structLiteralField =
        char('.')
            .then(symbol)
            .then(char('='))
            .then(expression);

    // PrefixOp = "!" | "-" | "~" | "*" | ("&amp;" option("align" "(" Expression option(":" Integer ":" Integer) ")" ) option("const") option("volatile")) | "?" | "%" | "%%" | "??" | "-%"
    pub const prefixOp =
        char('!')
            .orElse(char('-'))
            .orElse(char('~'))
            .orElse(char('*'))
            .orElse(
                char('&')
                    .then(
                        string("align")
                            .then(char('('))
                            .then(expression)
                            .then(
                                char(':')
                                    .then(integer)
                                    .then(char(':'))
                                    .then(Integer)
                                    .optional()
                            )
                            .then(char(')'))
                            .optional()
                    )
                    .then(string("const").optional())
                    .then(string("volatile").optional())
            )
            .orElse(char('?'))
            .orElse(char('%'))
            .orElse(string("%%"))
            .orElse(string("??"))
            .orElse(string("-%"));

    // PrimaryExpression = Integer | Float | String | CharLiteral | KeywordLiteral | GroupedExpression | BlockExpression(BlockOrExpression) | Symbol | ("@" Symbol FnCallExpression) | ArrayType | FnProto | AsmExpression | ("error" "." Symbol) | ContainerDecl | ("continue" option(":" Symbol))
    pub const primaryExpression =
        integer
            .orElse(float)
            .orElse(stringLit)
            .orElse(charLit)
            .orElse(keywordLit)
            .orElse(groupedExpression)
            .orElse(blockExpression(blockOrExpression))
            .orElse(symbol)
            .orElse(
                char('@')
                    .then(symbol)
                    .then(fnCallExpression)
            )
            .orElse(arrayType)
            .orElse(fnProto)
            .orElse(asmExpression)
            .orElse(
                string("error")
                    .then(char('.'))
                    .then(symbol)
            )
            .orElse(containerDecl)
            .orElse(
                string("continue")
                    .then(
                        char(':')
                            .then(symbol)
                            .optional()
                    )
            );

    // ArrayType : "[" option(Expression) "]" option("align" "(" Expression option(":" Integer ":" Integer) ")")) option("const") option("volatile") TypeExpr
    pub const arrayType =
        char('[')
            .then(expression.optional())
            .then(char(']'))
            .then(
                string("align")
                    .then(char('('))
                    .then(expression)
                    .then(
                        char(':')
                            .then(integer)
                            .then(char(':'))
                            .then(integer)
                            .optional()
                    )
                    .then(char(')'))
                    .optional()
            )
            .then(string("const").optional())
            .then(string("volatile").optional())
            .then(typeExpr);

    // GroupedExpression = "(" Expression ")"
    pub const groupedExpression =
        char('(')
            .then(expression)
            .then(char(')'));

    // KeywordLiteral = "true" | "false" | "null" | "undefined" | "error" | "this" | "unreachable"
    pub const keywordLit =
        string("true")
            .orElse(string("false"))
            .orElse(string("null"))
            .orElse(string("undefined"))
            .orElse(string("error"))
            .orElse(string("this"))
            .orElse(string("unreachable"));

    // ContainerDecl = option("extern" | "packed") ("struct" option(GroupedExpression) | "union" option("enum" option(GroupedExpression) | GroupedExpression) | ("enum" option(GroupedExpression)))
    pub const containerDecl =
        string("extern")
            .orElse(string("packed"))
            .optional()
            .then(
                string("struct")
                    .then(groupedExpression.optional())
                    .orElse(
                        string("union")
                            .then(
                                string("enum")
                                    .then(groupedExpression.optional())
                                    .orElse(groupedExpression)
                                    .optional()
                            )
                    )
                    .orElse(
                        string("enum")
                            .then(groupedExpression.optional())
                    )
            );
};