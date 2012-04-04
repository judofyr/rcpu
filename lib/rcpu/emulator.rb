module RCPU
  class Emulator
    # An Array with bound checking
    class BoundedArray < Array
      SIZE = 0x10000

      def initialize(source)
        super()
        concat(source)
        # Make sure it's always filled with zeros
        concat(Array.new(SIZE - size, 0))
      end

      def [](*keys)
        raise "out of bounds: #{keys[0]}" if keys.size == 1 && keys[0] >= SIZE
        super
      end

      def []=(key, value)
        raise "out of bounds: #{key}" if key >= SIZE
        super
      end
    end

    attr_reader :memory, :registers

    class Immediate < Struct.new(:value)
    end

    def initialize(program)
      @size = program.size
      @memory = BoundedArray.new(program)
      @registers = Hash.new(0)
      @registers[:SP] = 0xFFFF
    end

    def hex(i)
      i.to_s(16).rjust(4, '0').upcase
    end

    def dump
      @memory[0, @size].each_slice(8).each_with_index do |r, i|
        print "0x#{hex(i*8)}: "
        puts r.map { |x| hex(x) }.join(" ")
      end
      @registers.each do |name, value|
        puts "  %3s:  0x%s" % [name, hex(value)]
      end
      puts "Stack:  " +
        (@registers[:SP] == 0xFFFF ? '(null)' : "0x#{hex(@memory[0xFFFF])}") + 
        "  <- bottom"

      0xFFFE.downto(@registers[:SP] + 1) do |x|
        puts "        0x#{hex(@memory[x])}"
      end
    end

    def next_word
      @registers[:PC].tap do
        @registers[:PC] += 1
      end
    end

    def dispatch
      current = next_word

      ins = @memory[current]
      if (op = ins & 0xF).zero?
        op = (ins >> 4) & 0x3F
        a = (ins >> 10) & 0x3F
        p [a.to_s(2), op.to_s(2)]
        [:non_basic, op, value(a)]
      else
        a = (ins >> 4) & 0x3F
        b = (ins >> 10) & 0x3F
        [:basic, op, value(a), value(b)]
      end
    end

    # Run one instruction
    def tick
      send(*dispatch)
    end

    # Skip one instruction
    def skip
      dispatch
    end

    def run
      begin
        current = @registers[:PC]
        tick
      end until current == @registers[:PC]
    end

    def run_forever
      tick while true
    end

    def basic(op, a, b)
      case op
      when 0x1 # SET
        set(a, get(b))
      when 0x2 # ADD
        res = get(a) + get(b)
        @registers[:O] = res > 0xFFFF ? 1 : 0
        set(a, res & 0xFFFF)
      when 0x3 # SUB
        res = get(a) - get(b)
        @registers[:O] = res < 0 ? 0xFFFF : 0
        set(a, res & 0xFFFF)
      when 0x4 # MUL
        va, vb = get(a), get(b)
        @registers[:O] = ((va*vb)>>16)&0xffff
        set(a, (va * vb) & 0xFFFF)
      when 0x7 # SHL
        set(a, get(a) << get(b))
      when 0xD # IFN
        skip if get(a) == get(b)
      else
        raise "Missing basic: 0x#{op.to_s(16)}"
      end
    end

    def non_basic(op, a)
      case op
      when 0x01 # JSR
        # Store the next PC on stack
        @memory[@registers[:SP]] = @registers[:PC]
        @registers[:SP] -= 1
        # Set PC to a
        @registers[:PC] = get(a)
      else
        raise "Missing non-basic: 0x#{op.to_s(16)}"
      end
    end

    def set(k, v)
      case k
      when Symbol
        @registers[k] = v
      when Immediate
        raise "Can't set an immediate"
      else
        @memory[k] = v
      end
    end

    def get(v)
      case v
      when Symbol
        @registers[v]
      when Immediate
        v.value
      else
        @memory[v]
      end
    end

    # Converts a 6-bit value into something that you can use with #get and #set.
    def value(v)
      case v
      when 0x00..0x07 # register
        Register::REAL[v]
      when 0x08..0x0f # [register]
        reg = Register::REAL[v - 0x08]
        @registers[reg]
      when 0x10..0x17 # [register + next word]
        reg = Register::REAL[v - 0x10]
        @memory[next_word] + @registers[reg]
      when 0x18 # POP
        @registers[:SP] += 1
      when 0x19 # PEEK
        @registers[:SP] + 1
      when 0x1C
        :PC
      when 0x1D
        :O
      when 0x1E
        @memory[next_word]
      when 0x1F
        Immediate.new(@memory[next_word])
      when 0x20..0x3F
        Immediate.new(v - 0x20)
      else
        raise "Missing value: 0x#{v.to_s(16)}"
      end
    end
  end
end

