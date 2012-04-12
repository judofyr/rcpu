module RCPU
  class Emulator
    # An Array with bound checking
    class Memory
      attr_reader :array
      SIZE = 0x10000

      def initialize(source)
        if source.size > SIZE
          fail "source size (#{source.size}) larger than memory size (#{SIZE})"
        end
        @array = []
        @array.concat(source)
        # Make sure it's always filled with zeros
        @array.concat(Array.new(SIZE - @array.size, 0))
        @mapping = Hash.new(@array)
        @extensions = []
      end

      def to_s; @array.pack('v*') end

      def add_extensions(list)
        list.each do |(location, klass, args, blk)|
          ext = klass.new(@array, location, *args, &blk)
          @extensions << ext
          ext.map do |addr|
            @mapping[addr] = ext
          end
        end
      end

      def start
        @extensions.each do |ext|
          ext.start if ext.respond_to?(:start)
        end
      end

      def stop
        @extensions.each do |ext|
          ext.stop if ext.respond_to?(:stop)
        end
      end

      def [](key)
        raise "out of bounds: #{key}" if key >= SIZE
        @mapping[key][key]
      end

      def []=(key, value)
        raise "out of bounds: #{key}" if key >= SIZE
        @mapping[key][key] = value
      end

      def slice(*a) @array.slice(*a) end
    end

    attr_reader :memory, :registers
    attr_accessor :cycle

    class Immediate < Struct.new(:value)
    end

    def initialize(program)
      @size = program.size
      @memory = Memory.new(program)
      @decoder = InstructionDecoder.new(@memory)
      @registers = Hash.new(0)
      @cycle = 0
      @instruction_count = 0
    end

    def start; @memory.start end
    def stop;  @memory.stop  end

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
      puts "Cycle: #{@cycle}"
      puts " Inst: #{@instruction_count}"
    end

    # Run one instruction
    def tick
      @instruction_count += 1
      inst, @registers[:PC], cycles = @decoder.decode @registers[:PC]
      inst.execute(self)
      @cycle += cycles
    end

    # Skip one instruction
    def skip
      _, @registers[:PC], _ = @decoder.decode @registers[:PC]
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

    def [](k)
      case k
      when Register
        self[k.execute(self)]
      when PlusRegister
        @memory[(@registers[k.register.name] + k.value) & 0xFFFF]
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
        @memory[(@registers[k.register.name] + k.value) & 0xFFFF] = v
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
  end
end

