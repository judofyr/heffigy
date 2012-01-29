module Heffigy
  class Filter
    def initialize(options = {})
      @doc = options[:doc]
    end

    def call(node)
      if @doc.nodes.has_key?(node)
        tag = Tag.new(node)

        @doc.nodes[node].each do |scope|
          scope.logs.each do |type, variations|
            variations.each do |args, id|
              send("on_#{type}", tag, scope, scope.context.var(id), *args)
            end
          end
        end

        compile_tag(tag)
      else
        case
        when node.xml? || node.html?
          compile_children(node)
        when node.element?
          compile_node(node)
        when node.text?
          [:static, node.to_s]
        when node.is_a?(Nokogiri::XML::DTD)
          [:static, "<!DOCTYPE #{node.name} PUBLIC \"#{node.external_id}\" \"#{node.system_id}\">"]
        else
          raise "Unknown thing: #{node.class}"
        end
      end
    end

    def compile_children(node)
      node.children.inject([:multi]) do |exp, ele|
        exp << call(ele)
      end
    end

    def compile_node(node)
      content = compile_children(node)
      attrs = compile_node_attributes(node)
      [:html, :tag, node.name, attrs, content]
    end

    def compile_node_attributes(node)
      attrs = [:html, :attrs]
      node.attributes.each do |name, value|
        attrs << [:html, :attr, name, [:static, value.to_s]]
      end
      attrs
    end

    def compile_attributes(tag)
      compile_node_attributes(tag.node)
    end

    def compile_tag(tag)
      content = compile_children(tag.node)
      content = tag.inner[content]

      attrs = compile_attributes(tag)

      exp = [:html, :tag, tag.node.name, attrs, content]
      tag.outer[exp]
    end
  end
end

