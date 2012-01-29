module Heffigy
  class Scope
    attr_reader :nodes, :context, :logs

    def initialize(nodes, context)
      @nodes = nodes
      @context = context
      @logs = Hash.new { |h, k| h[k] = {} }
      @scopes ||= {}
    end

    def in_context
      @in_context ||= @context.doc.in_context(@nodes)
    end

    def find(selector)
      @scopes[selector] ||= Scope.new(child_search(selector), @context)
    end

    def child_search(sel)
      @nodes.inject([]) { |m, e| m.concat(e.search(sel)) }
    end

    def log(type, *args)
      @logs[type][args] ||= @context.logged(self)
    end
  end
end

