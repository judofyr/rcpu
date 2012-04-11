require 'strscan'

module RCPU
  class ASMParser
    def self.u(arr)
      Regexp.new('('+arr.map{|x|Regexp.escape(x.to_s)}*'|'+')\b', 'i')
    end

    def self.b(arr)
      Regexp.new('('+arr.map{|x|Regexp.escape(x.to_s)}*'|'+')', 'i')
    end

    BASIC = u(BasicInstruction::ALL)
    NONBASIC = u(NonBasicInstruction::ALL)
    REGS = u(Register::ALL)
    ALIAS = {
      "[SP++]" => :POP,
      "[SP]"   => :PEEK,
      "[--SP]" => :PUSH
    }
    ISH = b(ALIAS.keys)

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
        if name = @str.scan(/\w+/)
          name = name.to_sym
        elsif @str.skip(/"/)
          name = parse_string
        else
          error("Unknown library")
        end

        @lib.library(name)
        return
      end

      if @str.scan(/\.block\b/)
        @str.skip(SPACE)
        name = @str.scan(/\w+/) or error("Block name expected")
        block(name.to_sym)
        return
      end

      skip_crap!
      error("Unknown instruction") unless @str.empty?
    end

    def parse_value(indirect = false)
      @str.skip(/ */)
      res = if reg = @str.scan(REGS)
        Register.new(reg.upcase.to_sym)
      elsif ish = @str.scan(ISH)
        Register.new(ALIAS[ish.upcase])
      elsif num = @str.scan(NUMBER)
        Literal.new(Integer(num))
      elsif @str.scan(/\[/)
        val = parse_value(true)
        @str.scan(/\]/) or error('Missing ]')
        val.is_a?(PlusRegister) ? val : Indirection.new(val)
      elsif label = @str.scan(/\w+/)
        if label[0] == ?_
          External.new(label[1..-1].to_sym)
        else
          Label.new(label.to_sym)
        end
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

      if @str.skip(/"/)
        parse_string
      elsif num = @str.scan(NUMBER)
        Integer(num).chr
      else
        error("Unknown data")
      end
    end

    def parse_string
      str = @str.scan_until(/"/) or error("Missing \"")
      str.chop
    end

    def error(msg)
      parsed = @str.string[0, @str.pos]
      lineno = parsed.count("\n")
      start = (parsed.rindex("\n") || -1) + 1
      line = parsed[start..-1]
      col = line.size
      line << @str.check(/[^\n]*/)
      raise SyntaxError.new(msg, line, lineno, col)
    end
  end
end

