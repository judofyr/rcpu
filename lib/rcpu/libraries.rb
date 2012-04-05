module RCPU
  class ScreenExtension
    # Guessed from: http://i.imgur.com/XIXc4.jpg
    COLORS = Hash.new("\e[0m").update(
      0b011100000 => "\033[1;37;40m", # White on black
      0b111000011 => "\033[1;33;44m"  # Yellow on blue
    )

    def initialize(array, addr, columns)
      @array = array
      @addr = addr
      @start = addr.first
      @columns = columns
    end

    def start
      print "\e7\e[H\e[2J\e8"
      @addr.each { |a| self[a] = @array[a] }
    end

    def stop
      print "\e[17;1H"
    end

    def [](key)
      @array[key]
    end

    def []=(key, value)
      @array[key] = value
      char = (value & 0x7F).chr
      color = COLORS[value >> 7]
      idx = key - @start
      rows, cols = idx.divmod(@columns)
      print "\e7\e[#{rows+1};#{cols+1}H#{color}#{char}\e8"
    end
  end

  Loader.define :screen do
    extension 0x8000..0x8400, ScreenExtension, 32
  end
end

