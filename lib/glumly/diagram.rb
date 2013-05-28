# coding : utf-8

module Glumly
  def self.escape(obj)
    obj.to_s.gsub("<", "&lt;").gsub(">", "&gt;")
  end

  class Element
    def desc(text)
      @description = text
    end
    def description
      @description ||= ""
    end
  end

  class DiagramBase < Element
    def initialize(parent, id)
      @parent, @id = parent, id
    end

    def id
      "#{@parent.id}::#{@id}" unless @parent.nil?
    end

    def classes
      @classes ||= []
    end
    def relationships 
      @relationships ||= []
    end
    def packages
      @packages ||= []
    end
    def notes
      @notes ||= {}
    end

    def def_relationship(*args)
      relationships << Glumly::Relationship.new(*args)
    end
    def inherit(source, target, *args)
      def_relationship([source, target], :inherit, *args)
    end
    def depends(source, target, *args)
      def_relationship([source, target], :depends, *args)
    end
    def depends_both(source, target, *args)
      def_relationship([source, target], :depends_both, *args)
    end
    def composition(source, target, *args)
      def_relationship([source, target], :composition, *args)
    end
    def aggregation(source, target, *args)
      def_relationship([source, target], :aggregation, *args)
    end

    def def_class(*args, &block)
      item = nil
      case args.first
      when Glumly::Class
        item = args.first
      when Symbol
        item = Glumly::Class.new(*args).tap{|cls|
          cls.instance_eval &block unless block.nil?
        }
      else
        p args and die
      end
      classes << item
    end
    alias cls def_class

    def def_package(*args, &block)
      Glumly::Package.new(self, *args).tap{|package|
        package.instance_eval &block unless block.nil?
        packages << package
      }
    end
    def note(target, *text)
      notes[id] ||= []

      note_id = "note#{id.gsub("::", "_")}_#{notes[id].size}"
      notes[id] << Note.new(note_id, target, *text)
    end

    def to_diagram
      [
        'graph [fontname="monospace", ranksep=1, nodesep=1];',
        'node [shape="record"];',
        classes.map{|c| "#{c.to_dot_node};"},
        packages.map{|package| "#{package}"},
        relationships.map{|relationship| "#{relationship};"},
        notes.map{|id, notes| notes.join("\n")},
      ].flatten.join("\n")
    end

    def all_packages(&block)
      if block_given?
        packages.each do |pkg|
          block.call(pkg)
          pkg.all_packages(&block)
        end
      else
        Enumerator.new do |y|
          all_packages do |pkg|
            y << pkg
          end
        end
      end
    end

    private
    module Relationships
      def self.build(&block)
        Symbol.class_eval {
          def >>(sym)
          end
          def <=>(sym)
          end
        }
        begin
        ensure
          Symbol.class_eval {
            undef_method :>>, :<=>, :>=
          }
        end
      end
      class RelationshipFactory
        def initialize(target, a, b, type)
          @target, @a, @b, @type = target, a, b, type
        end

        def [](*args)
          @target.def_relationship([@a, @b], @type, *args)
        end
      end
    end
  end

  class Diagram < DiagramBase
    def initialize(name, &block)
      super(nil, nil)
      @name = name
      self.instance_eval &block unless block.nil?
    end

    def to_s
      [
        "digraph \"#{@name}\" {",
        to_diagram,
        "}",
      ].join("\n")
    end
  end

  class Package < DiagramBase
    def initialize(parent, id, name)
      super(parent, id)
      @name = name
    end
    def to_s
      [
        "subgraph \"cluster_#{@id}\" {",
        "label=\"#{Glumly::escape @name}\"",
        "fontcolor=\"gray35\"",
        "color=\"gray35\"",
        to_diagram,
        "}",
      ].join("\n")
    end

    def to_independent_digraph
      [
        "digraph \"#{@id}\" {",
        to_s,
        "}",
      ].join("\n")
    end
  end

  class Class < Element
    def initialize(id, name)
      @id, @name = id, name
      @attributes = []
      @methods = []
    end
    def def_attribute(definition, visibility = :private)
      @attributes << to_label(definition, visibility)
    end
    def def_method(definition, visibility = :public)
      @methods << to_label(definition, visibility)
    end

    def to_s
      _, stereotype, definition =
        @name.rpartition(/^<<.+>>/).map{|s| s.strip}

      "{" + [
        Glumly::escape([stereotype, definition, description].reject(&:empty?).join("\\n")),
        ((@attributes.empty?) ? nil : (@attributes.map{|s| "#{s}\\l"}.join)),
        ((@methods.empty?) ? nil : (@methods.map{|s| "#{s}\\l"}.join)),
      ].compact.join("|") + "}"
    end

    def to_dot_node
      %!"#{Glumly::escape(@id)}" [label="#{self}"]!
    end

    def -(definition)
      def_attribute definition
    end
    def +(definition)
      def_metho definition
    end

    def m
      Definer.new(self, :method)
    end

    def a
      Definer.new(self, :attribute)
    end

    private
    def to_label(definition, visibility)
      mark = case visibility
             when :public
               "+"
             when :private
               "-"
             when :protected
               "#"
             end
      _, stereotype, definition =
        definition.rpartition(/^<<.+>>/).map{|s| s.strip}

      Glumly::escape("#{stereotype} #{mark}#{definition}").strip
    end

    class Definer
      def initialize(target, type)
        @target, @type = target, type
      end

      def +(definition)
        apply(definition, :public)
      end
      def -(definition)
        apply(definition, :private)
      end

      private
      def apply(definition, visibility)
        case @type
        when :attribute
          @target.def_attribute definition, visibility
        when :method
          @target.def_method definition, visibility
        else
          raise NoMethodError.new "no definition type: #{type}"
        end
      end
    end
  end

  class Relationship
    def initialize(items, type, options = {})
      options = options.clone
      @items = items
      @type = type
      @head = options.delete(:head)
      @tail = options.delete(:tail)
      @multiplicity = options.delete(:multiplicity)
      @options = options
    end

    def to_s
      @items.map{|item| %!"#{item}"!}.join(" -> ") + "[#{attributes.map{|k, v| %!"#{k}"="#{v}"!}.join(", ")}]"
    end

    private
    def attributes
      other_options = case @type
                      when :inherit
                        {
                          dir: "both",
                          arrowhead: "onormal",
                          arrowtail: "none",
                        }
                      when :composition
                        {
                          dir: "both",
                          arrowhead: "none",
                          arrowtail: "diamond",
                        }
                      when :aggregation
                        {
                          dir: "both",
                          arrowhead: "none",
                          arrowtail: "odiamond",
                        }
                      when :depends
                        {
                          arrowhead: "open",
                        }
                      when :depends_both
                        {
                          arrowhead: "none",
                          arrowtail: "none",
                        }
                      else
                        {}
                      end

      multiplicity = if @multiplicity.nil?
                       {
                         headlabel: (@head[:multiplicity] unless @head.nil?),
                         taillabel: (@tail[:multiplicity] unless @tail.nil?),
                       }
                     else
                       {
                         taillabel: @multiplicity.flatten[0],
                         headlabel: @multiplicity.flatten[1],
                       }
                     end

      @options.merge(other_options).merge({
        labeldistance: "2",
      }).merge(multiplicity)
    end

    # A -> B [dir=both, arrowhead="onormal", arrowtail="odiamond"];
    def arrow(hash)
    end
  end

  class Note
    def initialize(id, target, *text)
      @id, @target, @text = id, target, text.map{|s| s+'\l'}.join
    end

    def color
      "gray35"
    end

    def to_s
      [
        %!"#{@id}" [label="#{@text}", shape=note, color=#{color}, fontcolor=#{color}];\n!,
        %!"#{@id}" -> "#{@target}" [dir=none, style=dashed, color=#{color}];\n!,
      ].join("")
    end
  end
end

