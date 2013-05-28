require 'glumly'

diagram = Glumly::Diagram.new("Factory Method") do
  def_class(:client, "Client") {
  }

  def_package(:pkg_element, "element") {
    def_class(:element, "Element") {
      m+ "accept(visitor : Visitor) : void"
    }
    def_class(:concrete_element, "ConcreteElement") {
      m+ "accept(visitor : Visitor) : void"
    }
    inherit :concrete_element, :element
  }

  def_package(:pkg_visitor, "visitor") {
    def_class(:visitor, "<<interface>> Visitor") {
      m+ "visit(element : ConcreteElement) : void"
    }
    def_class(:concrete_visitor, "ConcreteVisitor") {
      m+ "visit(element : ConcreteElement) : void"
    }
    inherit :concrete_visitor, :visitor
  }

  depends :client, :element
  depends :client, :visitor
end

open("./visitor.dot", "w") do |f|
  f.puts diagram.to_s
end

