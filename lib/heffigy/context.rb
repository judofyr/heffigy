module Heffigy
  class Context
    attr_reader :id, :doc, :scope

    def initialize(id, doc, nodes)
      @context_id = id
      @doc = doc
      @scope = Scope.new(nodes, self)

      @id = 0
    end

    def method_params
      (0...@id).map { |id| "#{var(id)} = nil" }.join ", "
    end

    def block_params
      "(" + (0...@id).map { |id| "#{var(id)}, "}.join + ")"
    end

    def var(id)
      "_c#{@context_id}_#{id}"
    end

    def logged(scope)
      @doc.logged(scope)
      @id.tap { @id += 1 }
    end

    def find(*args) @scope.find(*args) end
  end
end

