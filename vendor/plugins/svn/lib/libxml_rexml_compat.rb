# This adds some methods to the xml/libxml library to make it easier to re-use
# code written for the REXML api.

class XML::Node
  def text
    content
  end
  
  def attributes
    self
  end
  
  def add_attribute(key, val)
    self[key] = val
  end
  
  def elements
    REXMLCompat::Elements.new(self)
  end
  
  module REXMLCompat
    class Elements
      def initialize(node)
        @node = node
      end
    
      def [](key)
        @node.find_first(key)
      end
      
      def each(&proc)
        @node.each_child(&proc)
      end
    end
  end
end