require 'strscan'

module RCPU
  class ASMParser
    def self.u(arr)
      Regexp.new('('+arr.map(&:to_s)*'|'+')\b', 'i')
    end

    BASIC = u(BasicInstruction::ALL)
    NONBASIC = u(NonBasicInstruction::ALL)
    REGS = u(Register::ALL)
    SPACE = /[ \t]*/
    NUMBER = /(0x[0-9a-fA-F]{1,4})|\d+/

    class SyntaxError < StandardError
      def initialize(msg, line, lineno, col)
        space = ""
        line.each_char do |char|
          break if space.size >= col
          space << (char == "\t" ? "\t" : " ")
        end
        super("#{msg}\nLine number: #{lineno}\n|#{line}\n|#{space}^")
      end
    end

    def initialize(lib, str)
      @lib = lib
      @str = StringScanner.new(str)
    end

    def parse
      parse_instruction until @str.empty?
    end

    def block(name)
      @block = @lib.blocks[name] = Block.new
    end

    def push(thing)
      block(:main) unless @block
      @block.ins << thing
    end

    def skip_crap!
      begin
        crap = false
        crap |= @str.skip(/\s+/)
        crap |= @str.skip(/;[^\n]+/)
      end while crap
    end

    def parse_instruction
      skip_crap!

      if @str.skip(/:/)
        name = @str.scan(/\w+/)
        push name.to_sym
        return
      end

      if name = @str.scan(BASIC)
        name = name.upcase.to_sym
        a = parse_value
        @str.skip(SPACE)
        @str.skip(/,/) or error("#{name} requires two arguments")
        b = parse_value
        push BasicInstruction.new(name, a, b)
        return
      end

      if name = @str.scan(NONBASIC)
        name = name.upcase.to_sym
        a = parse_value
        push NonBasicInstruction.new(name, a)
        return
      end

      if @str.scan(/dat\b/i)
        data = ""
        while true
          data << parse_data
          @str.skip(SPACE)
          @str.skip(/,/) or break
        end

        push StringData.new(data)
        return
      end

      if @str.scan(/\.library\b/)
        @str.skip(SPACE)
        name = @str.scan(/\w+/) or error("Unknown library")
        @lib.library(name.to_sym)
        return
      end

      skip_crap!
      error("Unknown instruction") unless @str.empty?
    end

    def parse_value(indirect = false)
      @str.skip(/ */)
      res = if reg = @str.scan(REGS)
        Register.new(reg.upcase.to_sym)
      elsif num = @str.scan(NUMBER)
        Literal.new(Integer(num))
      elsif @str.scan(/\[/)
        val = parse_value(true)
        @str.scan(/\]/) or error('Missing ]')
        val.is_a?(PlusRegister) ? val : Indirection.new(val)
      elsif label = @str.scan(/\w+/)
        Label.new(label.to_sym)
      else
        error("Unknown value")
      end
    ensure
      if indirect && @str.scan(/\+/)
        reg = parse_value
        case res
        when Literal
          res = res.value
        when Label
        else
          error("Left side must be a number or a label")
        end

        error("Right side must be registerer") unless reg.is_a?(Register)
        return PlusRegister.new(reg, res)
      end
    end

    def parse_data
      @str.skip(SPACE)

      if @str.scan(/"/)
        str = @str.scan_until(/"/) or error("Missing \"")
        str.chop
      elsif num = @str.scan(NUMBER)
        Integer(num).chr
      else
        error("Unknown data")
      end
    end

    def error(msg)
      parsed = @str.string[0, @str.pos]
      lineno = parsed.count("\n")
      line = parsed[(parsed.rindex("\n")+1)..-1]
      col = line.size
      line << @str.check(/[^\n]*/)
      raise SyntaxError.new(msg, line, lineno, col)
    end
  end
end

