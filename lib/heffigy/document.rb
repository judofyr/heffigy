module Heffigy
  class Document
    attr_reader :nodes, :node, :scope
    attr_accessor :id

    def initialize(node, options = {})
      @node = node
      @id = 0
      @nodes = Hash.new { |h, k| h[k] = [] }

      @context_id = 0
      @context = in_context(node.search(':root'))

      @filter = (options[:filter] || Filter).new(:doc => self)
      @generator = HTMLGenerator.new

      @modified = true
    end

    def scope; @scope ||= @context.scope end

    def in_context(nodes)
      Context.new(@context_id, self, nodes)
    ensure
      @context_id += 1
    end

    def render(*args)
      recompile if @modified
      compiled_render(*args)
    end

    def compiled
      exp = @filter.call(@node)
      @generator.call(exp)
    end

    def compiled_method
      <<-RUBY
        def compiled_render(#{@context.method_params})
          #{compiled}
        end
      RUBY
    end

    def recompile
      @modified = false
      instance_eval compiled_method, __FILE__, __LINE__
    end

    def logged(scope)
      scope.nodes.each do |node|
        log = @nodes[node]
        log << scope unless log.include?(scope)
      end
      @modified = true
    end

    def find(*args) scope.find(*args) end
  end
end
