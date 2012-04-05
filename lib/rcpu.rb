module RCPU
  class AssemblerError < StandardError; end

  class BasicInstruction < Struct.new(:name, :a, :b)
    ALL = %w[SET ADD SUB MUL DIV MOD SHL SHR AND BOR XOR IFE IFN IFG IFB].map(&:to_sym)

    def code
      ALL.index(name) + 1
    end

    def to_machine(mem = [])
      acode, an = a.code
      bcode, bn = b.code
      mem << (code | (acode << 4) | (bcode << 10))
      mem << an if an
      mem << bn if bn
    end
  end

  class NonBasicInstruction < Struct.new(:name, :a)
    ALL = %w[JSR].map(&:to_sym)

    def code
      ALL.index(name) + 1
    end

    def to_machine(mem = [])
      acode, an = a.code
      mem << ((code << 4) | (acode << 10))
      mem << an if an
    end
  end

  class Register < Struct.new(:name)
    BASIC   = %w[A B C X Y Z I J].map(&:to_sym)
    SPECIAL = %w[SP PC O].map(&:to_sym)
    KINDA   = %w[POP PEEK PUSH].map(&:to_sym)

    REAL    = BASIC + SPECIAL
    EXTRA   = KINDA + SPECIAL
    ALL     = BASIC + EXTRA

    def code
      case name
      when *BASIC
        BASIC.index(name)
      when *EXTRA
        EXTRA.index(name) + 0x18
      end
    end

    def +(n)
      PlusRegister.new(self, n)
    end
  end

  class Indirection < Struct.new(:location)
    def code
      case location
      when Literal
        [0x1E, location.value]
      when PlusRegister
        location.code
      when Register
        location.code + 0x08
      when Label
        [0x1E, location]
      else
        raise "Missing: #{location}"
      end
    end
  end

  class PlusRegister < Struct.new(:register, :value)
    def code
      [0x10 + register.code, value]
    end
  end

  class Literal < Struct.new(:value)
    def code
      if value <= 0x1F
        value + 0x20
      else
        [0x1F, value]
      end
    end
  end

  class Label < Struct.new(:name)
    def code
      [0x1F, self]
    end
  end

  class External < Label
  end

  class ByteData < Struct.new(:bytes)
    def to_machine(mem = [])
      mem.concat(bytes.to_a)
    end
  end

  class ZeroData < Struct.new(:length)
    def to_machine(mem = [])
      length.times { mem << 0 }
    end
  end

  class StringData < Struct.new(:string)
    def to_machine(mem = [])
      mem.concat(string.chars.map(&:ord))
    end
  end

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
    attr_reader :blocks

    def initialize
      @blocks = {}
    end

    def block(name, &blk)
      @blocks[name] = Block.new(&blk)
    end

    def lookup(name)
      if @blocks.has_key?(name)
        return self, name
      end
    end
  end

  class Linker
    def initialize
      @memory = []
      @blocks = {}
      @seen = {}
    end

    def compile(library, name = :main)
      @seen[name] = @memory.size

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

