require 'glumly'

diagram = Glumly::Diagram.new("Factory Method") do
  def_class(:creator, "Creator") {
    m+ "factoryMethod() : Product"
  }
  def_class(:concrete_creator, "ConcreteCreator") {
    m+ "factoryMethod() : Product"
  }
  def_class(:product, "Product") {
  }

  inherit :concrete_creator, :creator
  depends :concrete_creator, :product
end

open("./factory_method.dot", "w") do |f|
  f.puts diagram.to_s
end

