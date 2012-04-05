module RCPU
  class Emulator
    # An Array with bound checking
    class Memory
      SIZE = 0x10000

      def initialize(source)
        @array = []
        @array.concat(source)
        # Make sure it's always filled with zeros
        @array.concat(Array.new(SIZE - @array.size, 0))
        @extensions = Hash.new(@array)
      end

      def add_extensions(list)
        list.each do |(location, klass, args, blk)|
          ext = klass.new(@array, *args, &blk)
          Array(location).each do |loc|
            @extensions[loc] = ext
          end
        end
      end

      def [](key)
        raise "out of bounds: #{key}" if key >= SIZE
        @extensions[key][key]
      end

      def []=(key, value)
        raise "out of bounds: #{key}" if key >= SIZE
        @extensions[key][key] = value
      end

      def slice(*a) @array.slice(*a) end
    end

    attr_reader :memory, :registers, :next_instruction

    class Immediate < Struct.new(:value)
    end

    def initialize(program)
      @size = program.size
      @memory = Memory.new(program)
      @registers = Hash.new(0)
      @next_instruction = send(*dispatch)
    end

    def hex(i)
      i.to_s(16).rjust(4, '0').upcase
    end

    def dump
      @memory.slice(0, @size).each_slice(8).each_with_index do |r, i|
        print "0x#{hex(i*8)}: "
        puts r.map { |x| hex(x) }.join(" ")
      end
      @registers.each do |name, value|
        puts "  %3s:  0x%s" % [name, hex(value)]
      end
      if @registers[:SP].zero?
        puts "Stack:  (null)  <- bottom"
      else
        puts "Stack:  0x#{hex(@memory[0xFFFF])}  <- bottom"

        0xFFFE.downto(@registers[:SP]) do |x|
          puts "        0x#{hex(@memory[x])}"
        end
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
        [:non_basic, op, value(a)]
      else
        a = (ins >> 4) & 0x3F
        b = (ins >> 10) & 0x3F
        [:basic, op, value(a), value(b)]
      end
    end

    # Run one instruction
    def tick
      @next_instruction.execute(self)
      @next_instruction = send(*dispatch)
    end

    # Skip one instruction
    def skip
      dispatch
    end

    def run
      begin
        current = self[:PC]
        tick
      end until current == self[:PC]
    end

    def run_forever
      tick while true
    end

    def basic(op, a, b)
      BasicInstruction.from_code(op, a, b)
    end

    def non_basic(op, a)
      NonBasicInstruction.from_code(op, a)
    end

    def [](k)
      case k
      when Register
        self[k.execute(self)]
      when PlusRegister
        @memory[@registers[k.register.name] + k.value]
      when Indirection
        @memory[self[k.location]]
      when Literal
        k.value
      when Fixnum
        @memory[k]
      when Symbol
        @registers[k]
      else
        raise "Missing get: #{k}"
      end
    end

    def []=(k, v)
      v &= 0xFFFF
      case k
      when Register
        self[k.execute(self)] = v
      when PlusRegister
        @memory[@registers[k.register.name] + k.value] = v
      when Indirection
        @memory[self[k.location]] = v
      when Fixnum
        @memory[k] = v
      when Symbol
        @registers[k] = v
      else
        raise "Missing set: #{k}"
      end
    end

    def value(v)
      case v
      when 0x00..0x07 # register
        Register.from_code(v)
      when 0x08..0x0f # [register]
        reg = Register.from_code(v - 0x08)
        Indirection.new(reg)
      when 0x10..0x17 # [register + next word]
        reg = Register.from_code(v - 0x10)
        PlusRegister.new(reg, @memory[next_word])
      when 0x18 # POP
        Register.new(:POP)
      when 0x19 # PEEK
        Register.new(:PEEK)
      when 0x1A
        Register.new(:PUSH)
      when 0x1B
        Register.new(:SP)
      when 0x1C
        Register.new(:PC)
      when 0x1D
        Register.new(:O)
      when 0x1E
        Indirection.new(Literal.new(@memory[next_word]))
      when 0x1F
        Literal.new(@memory[next_word])
      when 0x20..0x3F
        Literal.new(v - 0x20)
      else
        raise "Missing value: 0x#{v.to_s(16)}"
      end
    end
  end
end

