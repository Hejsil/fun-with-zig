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

const ZigSyntax = struct {
    // Root = many(TopLevelItem) EOF
    pub const root = comptime topLevelItem.many().discard().then(end);

    // TopLevelItem = ErrorValueDecl | CompTimeExpression(Block) | TopLevelDecl | TestDecl
    pub const topLevelItem = 
        errorValueDecl
            .orElse(CompTimeExpression)
            .orElse(TopLevelDecl)
            .orElse(TestDecl);
    
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
        localVarDecl.then(char(';'));
};