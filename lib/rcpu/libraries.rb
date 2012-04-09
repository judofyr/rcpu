module RCPU
  class ScreenExtension
    def initialize(array, start, options = {})
      @array = array
      @start = start
      @height = options[:height] || 16
      @width = options[:width] || 32
      @length = @height * @width
      @first = true
    end

    def map
      @length.times do |x|
        yield @start + x
      end
    end

    def color_to_ansi(bit)
      ((bit & 1) << 2) | (bit & 2) | ((bit & 4) >> 2)
    end

    def start
      if @first
        print "\e[?1049h\e[17;1H"
        @first = false
      end
    end

    def stop
      map { |a| self[a] = @array[a] }
    end

    def [](key)
      @array[key]
    end

    def []=(key, value)
      @array[key] = value
      idx = key - @start
      rows, cols = idx.divmod(@width)

      char = (value & 0x7F).chr
      args = []
      args << (value >> 15)
      if value > 0x7F
        args << color_to_ansi(value >> 12) + 30
        args << color_to_ansi(value >> 8)  + 40
      end

      char = " " if char.ord.zero?

      color = "\e[#{args*';'}m"
      print "\e7\e[#{rows+1};#{cols+1}H#{color}#{char}\e8"
    end
  end

  define :screen do
    extension 0x8000, ScreenExtension, :width => 32, :height => 16
  end

  class InputExtension
    def initialize(array, start)
      @array = array
      @start = start
    end

    def map
      yield @start
      yield @start + 1
    end

    def []=(key, value)
      # do nothing
    end
  end

  class StringInput < InputExtension
    def initialize(array, start, string)
      super(array, start)
      @string = string
    end

    def [](key)
      if key == @start
        @string.size
      else
        @string.slice!(0).ord
      end
    end
  end

  class StdinInput < InputExtension
    def initialize(array, start)
      super
      @buffer = []
    end

    def [](key)
      @buffer = fetch if @buffer.empty?

      if key == @start
        @buffer.size
      else
        @buffer.shift
      end
    end

    def fetch
      if line = $stdin.gets
        line.chars.map(&:ord)
      else
        []
      end
    end
  end

  define :input do
    block :read do
      label :write
      # We are only allowed to read i characters.
      IFE a, 0
        SET pc, pop

      # There are no characters left in the stream.
      IFE [b], 0
        SET pc, pop

      SET [c], [b+1]
      ADD c, 1
      SUB a, 1

      # Next char.
      SET pc, :write
    end

    block :readline do
      SET push, j

      label :write

      # We are only allowed to read i characters.
      IFE a, 0
        SET pc, :done

      # There are no characters left in the stream.
      IFE [b], 0
        SET pc, :done

      SET j, [b+1]
      IFE j, 10 # newline
        SET pc, :done

      SET [c], j
      ADD c, 1
      SUB a, 1

      # Next char.
      SET pc, :write

      label :done
      SET j, pop
      SET pc, pop
    end
  end

  define :parse do
    block :parse_number do
      SET x, 0
      SET push, z

      # Loop through characters
      label :number_start
      SET o, 0
      IFE b, 0
        SET pc, :number_exit
      MUL x, a  # x *= base
      SET z, [c] # next char
      ADD c, 1
      SUB b, 1

      # convert 0-9, A-Z to 0-35

      # < '0'
      IFG "0".ord, z
        SET pc, :number_fail

      SUB z, "0".ord

      # <= '9'
      IFG 10, z
        SET pc, :number_add

      IFG 17, z # < 'A' (17 is 'A'-'0')
        SET pc, :number_fail

      SUB z, (17-10)

      label :number_add
      IFG z, a # bigger than base
        SET pc, :number_fail

      ADD x, z
      SET pc, :number_start

      label :number_fail
      SET o, 1

      label :number_exit
      SET z, pop
      SET pc, pop
    end
  end
end

