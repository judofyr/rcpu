module RCPU
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

    def labels
      [*a.labels, *b.labels]
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

    def labels
      a.labels
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

    def labels
      []
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
        [0x1E, location.name]
      else
        raise "Missing: #{location}"
      end
    end

    def labels
      location.labels
    end
  end

  class PlusRegister < Struct.new(:register, :value)
    def code
      [0x10 + register.code, value]
    end

    def labels
      []
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

    def labels
      []
    end
  end

  class Label < Struct.new(:name)
    def code
      [0x1F, name]
    end

    def labels
      [name]
    end
  end

  class External < Label
    def labels
      []
    end
  end

  class Program
    def initialize(&blk)
      @blocks = []
      @data = {}
      instance_eval(&blk)
    end

    def __data__
      @data
    end

    def block(name)
      @ins = []
      yield
      @blocks << [name, @ins]
    end

    def data(name, size)
      @data[name] = size
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

    def normalize(value)
      case value
      when Register, PlusRegister
        value
      when Fixnum
        Literal.new(value)
      when Array
        Indirection.new(normalize(value[0]))
      when Symbol
        if value.to_s[0] == ?_
          External.new(value)
        else
          Label.new(value)
        end
      else
        raise "Missing: #{value}"
      end
    end

    def to_machine(mem = [])
      labels = {}

      @blocks.each do |name, iseq|
        labels[name] = mem.size

        iseq.each do |ins|
          ins.to_machine(mem)
        end
      end

      [mem, labels]
    end
  end

  class Linker
    def initialize
      @memory = []
      @programs = {}
    end

    def program(name, &blk)
      self[:"_#{name}"] = Program.new(&blk)
    end

    def []=(name, program)
      @programs[name] = @memory.size
      m, labels = program.to_machine
      codestart = @memory.size
      datastart = m.size
      data = {}

      program.__data__.each do |key, value|
        size = value.respond_to?(:to_a) ? value.to_a.size : value
        data[key] = datastart
        datastart += size
      end

      m.each do |word|
        # Resolve internal labels
        if word.is_a?(Symbol) && (internal = labels[word] || data[word])
          @memory << internal + codestart
        else
          @memory << word
        end
      end

      program.__data__.each do |key, value|
        if value.respond_to?(:to_a)
          @memory.concat(value.to_a)
        else
          value.times { @memory << 0 }
        end
      end
    end

    def finalize
      @memory.map do |word|
        if word.is_a?(Symbol)
          @programs[word] or raise "Can't resolve #{word}"
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

