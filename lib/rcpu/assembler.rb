module RCPU
  class Block
    def initialize(&blk)
      @ins = []
      @data = {}
      instance_eval(&blk)
    end

    def data(name, data)
      label(name)
      if data.respond_to?(:to_ary)
        @ins << ByteData.new(data)
      elsif data.respond_to?(:to_int)
        @ins << ZeroData.new(data)
      elsif data.respond_to?(:to_str)
        @ins << StringData.new(data)
      else
        raise AssemblerError, "uknown data type"
      end
    end

    Register::ALL.each do |name|
      r = Register.new(name)
      define_method(name.to_s.downcase) { r }
    end

    BasicInstruction::ALL.each do |name|
      define_method(name) do |a, b|
        @ins << BasicInstruction.new(name.to_sym, normalize(a), normalize(b))
      end
    end

    NonBasicInstruction::ALL.each do |name|
      define_method(name) do |a|
        @ins << NonBasicInstruction.new(name.to_sym, normalize(a))
      end
    end

    def label(name)
      @ins << name
    end

    def normalize(value)
      case value
      when Register
        value
      when PlusRegister
        value.value = normalize(value.value)
        value
      when Fixnum
        Literal.new(value)
      when Array
        Indirection.new(normalize(value[0]))
      when Symbol
        if value.to_s[0] == ?_
          External.new(value.to_s[1..-1].to_sym)
        else
          Label.new(value)
        end
      else
        raise "Missing: #{value}"
      end
    end

    def to_machine(mem = [])
      labels = {}
      @ins.each do |i|
        case i
        when Symbol
          labels[i] = mem.size
        else
          i.to_machine(mem)
        end
      end
      [mem, labels]
    end
  end

  class Library
    attr_reader :blocks, :extensions

    def initialize
      @blocks = {}
      @extensions = []
    end

    def block(name, &blk)
      @blocks[name] = Block.new(&blk)
    end

    def lookup(name)
      if @blocks.has_key?(name)
        return self, name
      end
    end

    def extension(location, klass, *args, &blk)
      @extensions << [location, klass, args, blk]
    end
  end

  class Linker
    attr_reader :extensions

    def initialize
      @memory = []
      @blocks = {}
      @seen = {}
      @seen_libs = {}
      @extensions = []
    end

    def compile(library, name = :main)
      @seen[name] = @memory.size

      @extensions.concat(library.extensions) unless @seen_libs[library]
      @seen_libs[library] = true

      pending = []
      block = library.blocks[name] or raise AssemblerError, "no block: #{name}"
      m, labels = block.to_machine
      start = @memory.size
      m.each do |word|
        case word
        when External
          name = word.name
          pending << name unless @seen[name]
          @memory << name
        when Label
          location = labels[word.name] or raise AssemblerError, "no label: #{word.name}"
          @memory << location + start
        else
          @memory << word
        end
      end

      pending.each do |ext|
        lib, name = library.lookup(ext)
        raise AssemblerError, "no external label: #{ext}" if lib.nil?
        compile(lib, name)
      end
    end

    def finalize
      @memory.map do |word|
        if word.is_a?(Symbol)
          @seen[word]
        else
          word
        end
      end
    end

    def dump
      finalize.each_slice(8).each_with_index do |r, i|
        print "#{(i*8).to_s(16).rjust(4, '0')}: "
        puts r.map { |x| x.to_s(16).rjust(4, '0') }.join(" ")
      end
    end
  end
end

