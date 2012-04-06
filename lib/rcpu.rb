module RCPU
  class AssemblerError < StandardError; end

  class BasicInstruction < Struct.new(:name, :a, :b)
    ALL = %w[SET ADD SUB MUL DIV MOD SHL SHR AND BOR XOR IFE IFN IFG IFB].map(&:to_sym)

    def to_s
      "#{name} #{a}, #{b}"
    end

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

    def self.from_code(code, a, b)
      new(ALL[code-1], a, b)
    end

    def execute(emu)
      case name
      when :SET
        emu[a] = emu[b]

      when :ADD
        res = emu[a] + emu[b]
        emu[:O] = res > 0xFFFF ? 1 : 0
        emu[a] = res

      when :SUB
        res = emu[a] - emu[b]
        emu[:O] = res < 0 ? 0xFFFF : 0
        emu[a] = res

      when :MUL
        va, vb = emu[a], emu[b]
        emu[:O] = ((va*vb)>>16)&0xffff
        emu[a] = va * vb

      when :DIV # DIV
        va, vb = emu[a], emu[b]
        res = 0
        if vb.zero?
          emu[:O] = 0
        else
          res = va / vb
          emu[:O] = (va << 16) / vb
        end
        emu[a] = res

      when :MOD
        va, vb = emu[a], emu[b]
        emu[a] = vb.zero? ? 0 : va % vb

      when :SHL
        va, vb = emu[a], emu[b]
        emu[:O] = (va << vb) >> 16
        emu[a] = va << vb

      when :SHR
        va, vb = emu[a], emu[b]
        emu[:O] = (va << 16) >> vb
        emu[a] = va >> vb

      when :AND
        emu[a] = emu[a] & emu[b]

      when :BOR
        emu[a] = emu[a] | emu[b]

      when :XOR
        emu[a] = emu[a] ^ emu[b]

      when :IFE
        emu.skip unless emu[a] == emu[b]

      when :IFN
        emu.skip unless emu[a] != emu[b]

      when :IFG
        emu.skip unless emu[a] > emu[b]

      when :IFB
        emu.skip unless (emu[a] & emu[b]) != 0

      else
        raise "Missing basic: #{name}"
      end
    end
  end

  class NonBasicInstruction < Struct.new(:name, :a)
    ALL = %w[JSR].map(&:to_sym)

    def to_s
      "#{name} #{a}"
    end

    def code
      ALL.index(name) + 1
    end

    def to_machine(mem = [])
      acode, an = a.code
      mem << ((code << 4) | (acode << 10))
      mem << an if an
    end

    def self.from_code(code, a)
      new(ALL[code - 1], a)
    end

    def execute(emu)
      case name
      when :JSR
        emu[:SP] -= 1
        emu[emu[:SP]] = emu[:PC]
        emu[:PC] = emu[a]
      else
        raise "Missing non-basic: #{name}"
      end
    end
  end

  class Register < Struct.new(:name)
    BASIC   = %w[A B C X Y Z I J].map(&:to_sym)
    SPECIAL = %w[SP PC O].map(&:to_sym)
    KINDA   = %w[POP PEEK PUSH].map(&:to_sym)

    REAL    = BASIC + SPECIAL
    EXTRA   = KINDA + SPECIAL
    ALL     = BASIC + EXTRA

    def to_s
      name.to_s.downcase
    end

    def code
      case name
      when *BASIC
        BASIC.index(name)
      when *EXTRA
        EXTRA.index(name) + 0x18
      end
    end

    def self.from_code(op)
      new(BASIC[op])
    end

    def +(n)
      PlusRegister.new(self, n)
    end

    def execute(emu)
      case name
      when *REAL
        name
      when :POP
        (emu[:SP] += 1) - 1
      when :PEEK
        emu[:SP]
      when :PUSH
        emu[:SP] -= 1
      end
    end
  end

  class Indirection < Struct.new(:location)
    def to_s
      "[#{location}]"
    end

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
        raise AssemblerError, "Missing: #{location}"
      end
    end
  end

  class PlusRegister < Struct.new(:register, :value)
    def to_s
      "[#{register}+#{value}]"
    end

    def code
      [0x10 + register.code, value]
    end
  end

  class Literal < Struct.new(:value)
    def to_s
      "0x" + value.to_s(16).upcase
    end

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
      bytes.to_a.each do |byte|
        case byte
        when Fixnum
          mem << byte
        when String
          mem.concat(byte.chars.map(&:ord))
        when Symbol
          mem << Label.new(byte)
        else
          raise AssemblerError, "unknown data: #{byte.inspect}"
        end
      end
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
require 'rcpu/libraries'


