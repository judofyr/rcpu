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
end

require 'rcpu/assembler'
require 'rcpu/emulator'


