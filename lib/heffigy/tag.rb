module Heffigy
  class Tag
    attr_reader :data, :node

    def initialize(node)
      @node = node
      @inner = proc { |c| c }
      @outer = proc { |c| c }
      @data = {}
    end

    def wrap(blk)
      proc { |x| yield blk[x] }
    end

    def inner(&blk)
      if blk
        @inner = wrap(@inner, &blk)
      else
        @inner
      end
    end

    def outer(&blk)
      if blk
        @outer = wrap(@outer, &blk)
      else
        @outer
      end
    end
  end
end

