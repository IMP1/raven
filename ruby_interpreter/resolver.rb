require_relative 'visitor'

# http://craftinginterpreters.com/resolving-and-binding.html

class Resolver < Visitor

    def initialize(interpreter)
        @interpreter = interpreter
        @scopes = []
    end

    def begin_scope
        @scopes.push({})
    end

    def end_scope
        @scopes.pop
    end

    def declare(name_token)
        return if @scopes.empty?
        @scopes.last[name_token.lexeme] = false
    end

    def define(name_token)
        return if @scopes.empty?
        @scopes.last[name_token.lexeme] = true
    end

    def resolve_expression(expr)
        expr.accept(self)
    end

    def resolve_statement(stmt)
        stmt.accept(self)
    end

    def resolve_local(expr, name_token)
        (@scopes.size - 1).downto(0) do |i|
            if @scopes[i].has_key?(name_token.lexeme)
                interpreter.resolve(expr, @scopes.size - 1 - i)
                return
            end
        end
        # Not found. Assume it is global.
    end

    def resolve_block(statements)
        statements.each { |s| resolve_statement(s) }
    end

    def resolve_function(stmt)
        begin_scope
        stmt.parameter_names.each do |param| 
            declare(param)
            define(param)
        end
        resolve(stmt.body)
        end_scope
    end

    #---------------------------------------#

    def visit_BlockStatement(stmt)
        begin_scope
        resolve_block(stmt.statements)
        end_scope
    end

    def visit_VariableDeclarationStatement(stmt)
        # TODO: check if function
        # public Void visitFunctionStmt(Stmt.Function stmt) {
        #     declare(stmt.name);
        #     define(stmt.name);
        #     resolveFunction(stmt);
        #     return null;
        # }
        #
        if stmt.type 
        declare(stmt.name)
        if !stmt.initialiser.nil?
            resolve_expression(stmt.initialiser)
        end
        define(stmt.name)
    end

    def visit_AssignmentStatement(stmt)
        resolve(stmt.value)
        resolve_local(stmt, stmt.name)
    end

    def visit_VariableExpression(expr)
        if !@scopes.empty? && !@scopes.last[expr.name.lexeme]
            # TODO: error: "Cannot read local variable in its own initializer."
        end
        resolve_local(expr, expr.name)
    end

end