module ActionController
  class MiddlewareStack < Array
    class Middleware
      def self.new(klass, *args, &block)
        if klass.is_a?(self)
          klass
        else
          super
        end
      end

      attr_reader :args, :block

      def initialize(klass, *args, &block)
        @klass = klass

        options = args.extract_options!
        if options.has_key?(:if)
          @conditional = options.delete(:if)
        else
          @conditional = true
        end
        args << options unless options.empty?

        @args = args
        @block = block
      end

      def klass
        if @klass.is_a?(Class)
          @klass
        else
          @klass.to_s.constantize
        end
      rescue NameError
        @klass
      end

      def active?
        if @conditional.respond_to?(:call)
          @conditional.call
        else
          @conditional
        end
      end

      def ==(middleware)
        case middleware
        when Middleware
          klass == middleware.klass
        when Class
          klass == middleware
        else
          klass == middleware.to_s.constantize
        end
      end

      def inspect
        str = klass.to_s
        args.each { |arg| str += ", #{arg.inspect}" }
        str
      end

      def build(app)
        if block
          klass.new(app, *args, &block)
        else
          klass.new(app, *args)
        end
      end
    end

    def initialize(*args, &block)
      super(*args)
      block.call(self) if block_given?
    end

    def insert(index, *objs)
      index = self.index(index) unless index.is_a?(Integer)
      objs = objs.map { |obj| Middleware.new(obj) }
      super(index, *objs)
    end

    alias_method :insert_before, :insert

    def insert_after(index, *objs)
      index = self.index(index) unless index.is_a?(Integer)
      insert(index + 1, *objs)
    end

    def use(*args, &block)
      middleware = Middleware.new(*args, &block)
      push(middleware)
    end

    def active
      find_all { |middleware| middleware.active? }
    end

    def build(app)
      active.reverse.inject(app) { |a, e| e.build(a) }
    end
  end
end
