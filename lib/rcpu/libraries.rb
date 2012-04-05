module RCPU
  class ScreenExtension
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
      idx = key - @start
      rows, cols = idx.divmod(@columns)
      print "\e7\e[#{rows+1};#{cols+1}H#{value.chr}\e8"
    end
  end

  Loader.define :screen do
    extension 0x8000..0x8400, ScreenExtension, 32
  end
end

