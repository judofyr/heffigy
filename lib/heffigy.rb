require 'temple'
require 'nokogiri'

module Heffigy
  class HTMLGenerator < Temple::Engine
    use Temple::HTML::Fast
    filter :ControlFlow
    filter :MultiFlattener
    filter :StaticMerger
    filter :DynamicInliner
    generator :ArrayBuffer
  end
end

require 'heffigy/document'
require 'heffigy/context'
require 'heffigy/scope'
require 'heffigy/filter'
require 'heffigy/tag'

