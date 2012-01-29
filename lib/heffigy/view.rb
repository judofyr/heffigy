require 'heffigy'
require 'cgi'

module Heffigy
  class View
    class << self
      def doc
        @doc || raise("No document available")
      end

      def file(name)
        template(File.open(name))
      end

      def template(str)
        @doc = Heffigy::Document.new(Nokogiri::HTML(str), :filter => Filter)
      end
    end

    def render
      @_values = []
      transform
      self.class.doc.render(*@_values)
    end

    def transform
    end

    def scope
      @_scope ||= self.class.doc.scope
    end

    def with_context(scope)
      prev = [@_scope, @_values]
      @_scope = scope.in_context.scope
      yield
    ensure
      @_scope, @_values = prev
    end

    def find(selector)
      if block_given?
        begin
          prev, @_scope = scope, scope.find(selector)
          yield
        ensure
          @_scope = prev
        end
      else
        Selection.new(self, selector)
      end
    end

    class Selection
      def initialize(view, selector)
        @view     = view
        @selector = selector
      end

      def method_missing(method, *args, &block)
        @view.send(method, @selector, *args, &block)
        self
      end
    end

    def text(selector, value)
      html(selector, CGI.escapeHTML(value))
    end

    def html(selector, value)
      id = scope.find(selector).log(:html)
      @_values[id] = value
    end

    def append(selector, value)
      id = scope.find(selector).log(:append)
      @_values[id] = value
    end

    def attr(selector, attrs)
      attrs.each do |key, value|
        key = key.to_sym
        id = scope.find(selector).log(:attr, key)
        @_values[id] = value
      end
    end

    def remove(selector)
      id = scope.find(selector).log(:remove)
      @_values[id] = true
    end

    def replace_each(selector, enum)
      s = scope.find(selector)
      result = []

      with_context(s) do
        enum.each do |*args|
          @_values = []
          yield *args
          result << @_values
        end
      end

      id = s.log(:replace_each)
      @_values[id] = result
    end

    class Filter < Heffigy::Filter
      def on_html(tag, scope, var)
        tag.inner do |content|
          [:if, var, [:dynamic, var], content]
        end
      end

      def on_append(tag, scope, var)
        tag.inner do |content|
          [:multi, content, [:dynamic, var]]
        end
      end

      def on_attr(tag, scope, var, key)
        tag.data[:replace_attrs] ||= {}
        tag.data[:replace_attrs][key] = var
      end

      def on_remove(tag, scope, var)
        tag.outer do |ele|
          [:if, "not #{var}", ele]
        end
      end

      def on_replace_each(tag, scope, var)
        tag.outer do |ele|
          vars = scope.in_context.block_params
          [:block, "(#{var} || [[]]).each do |#{vars}|", ele]
        end
      end

      def compile_attributes(tag)
        node = tag.node
        exp = [:html, :attrs]
        r = tag.data[:replace_attrs] || {}

        r.each do |key, var|
          else_clause =
            if node[key]
              [:html, :attr, key, [:static, node[key].to_s]]
            else
              [:multi]
            end

          exp << [:if, var,
            [:html, :attr, key, [:dynamic, var]],
            else_clause
          ]
        end

        node.attributes.each do |key, value|
          if !r.has_key?(key.to_sym)
            exp << [:html, :attr, key, [:static, value.to_s]]
          end
        end

        exp
      end
    end
  end
end

