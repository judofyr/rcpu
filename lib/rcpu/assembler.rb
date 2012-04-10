require 'rcpu/macros'

module RCPU
  class Block
    include StandardMacros
    attr_reader :ins

    def initialize(&blk)
      @ins = []
      @data = {}
      @next_newlabel = 0
      instance_eval(&blk) if blk
    end

    def data(*args)
      data = args.pop
      if name = args.shift
        label(name)
      end

      if data.is_a?(String)
        @ins << StringData.new(data)
      elsif data.is_a?(Fixnum)
        @ins << ZeroData.new(data)
      elsif data.respond_to?(:each)
        @ins << ByteData.new(data)
      else
        raise AssemblerError, "unknown data type: #{data.inspect}"
      end
    end

    Register::ALL.each do |name|
      r = Register.new(name)
      define_method(name.to_s.downcase) { r }
    end

    BasicInstruction::ALL.each do |name|
      define_method(name) do |a, b|
        @ins << BasicInstruction.new(name.to_sym, normalize(a), normalize(b))
      end
    end

    NonBasicInstruction::ALL.each do |name|
      define_method(name) do |a|
        @ins << NonBasicInstruction.new(name.to_sym, normalize(a))
      end
    end

    def label(name)
      @ins << name
    end

    def newlabel
      :"newlabel_#{@next_newlabel}".tap do |sym|
        label sym
        @next_newlabel += 1
      end
    end

    def normalize(value)
      case value
      when Register
        value
      when PlusRegister
        value.value = normalize(value.value) unless value.value.is_a?(Fixnum)
        value
      when Fixnum
        Literal.new(value)
      when Array
        Indirection.new(normalize(value[0]))
      when Symbol
        if value.to_s[0] == ?_
          External.new(value.to_s[1..-1].to_sym)
        else
          Label.new(value)
        end
      else
        raise AssemblerError, "Missing: #{value.inspect}"
      end
    end

    def to_machine(mem = [])
      labels = {}
      @ins.each do |i|
        case i
        when Symbol
          labels[i] = mem.size
        else
          i.to_machine(mem)
        end
      end
      [mem, labels]
    end
  end

  class Library
    attr_reader :blocks, :extensions, :libraries
    attr_accessor :scope

    def initialize
      @blocks = {}
      @extensions = []
      @libraries = []
    end

    def block(name, &blk)
      @blocks[name] = Block.new(&blk)
    end

    def extension(location, klass, *args, &blk)
      @extensions << [location, klass, args, blk]
    end

    def library(name)
      @libraries << name
    end

    def parse(str)
      ASMParser.new(self, str).parse
    end
  end

  def self.define(name, &blk)
    l = Library.new
    l.instance_eval(&blk)
    Linker.default_libraries[name] = l
  end

  class Linker
    attr_reader :extensions, :symbols

    def self.default_libraries
      @dl ||= {}
    end

    def initialize
      @memory = []
      @blocks = {}
      @seen = {}
      @seen_libs = {}
      @extensions = []
      @libraries = {}
      @symbols = {}
    end

    def gather(library)
      return if @seen_libs[library]
      @seen_libs[library] = true
      @blocks.update(library.blocks)
      @extensions.concat(library.extensions)
      library.libraries.each do |l|
        gather(find(l, library.scope))
      end
    end

    def find(name, scope)
      case name
      when Symbol
        self.class.default_libraries[name] or
          raise AssemblerError, "no lib: #{name}"
      when String
        full = File.expand_path(name, scope)
        @libraries[full] || load_file(full)
      else
        raise AssemblerError, "no lib: #{name.inspect}"
      end
    end

    def load_file(file)
      l = Library.new
      l.scope = File.dirname(file)
      case ext = File.extname(file)
      when ".rcpu"
        l.instance_eval(File.read(file), file)
      when ".s"
        l.parse(File.binread(file))
      else
        raise AssemblerError, "Unknown file format: #{ext}"
      end
      @libraries[file] = l
    end

    def compile(file, scope)
      compile_library(find(file, scope))
    end

    def compile_binary(str)
      @memory.concat(str.unpack('v*'))
    end

    def compile_library(library, name = :main)
      gather(library)
      block = @blocks[name] or raise AssemblerError, "no block: #{name}"
      compile_block(name, block)
    end

    def compile_block(name, block)
      @seen[name] = @memory.size
      pending = []
      m, labels = block.to_machine
      start = @memory.size

      labels.each do |key, value|
        @symbols["#{name}_#{key}"] = value + start
      end

      m.each do |word|
        case word
        when External
          name = word.name
          pending << name unless @seen[name]
          @memory << name
        when Label
          location = labels[word.name] or raise AssemblerError, "no label: #{word.name}"
          @memory << location + start
        when Fixnum
          @memory << word
        else
          raise AssemblerError, "unknown word: #{word.inspect}"
        end
      end

      pending.uniq.each do |name|
        block = @blocks[name]
        raise AssemblerError, "no external label: #{name}" if block.nil?
        compile_block(name, block)
      end
    end

    def finalize
      @memory.map do |word|
        case word
        when Symbol
          @seen[word]
        when Fixnum
          word
        else
          raise AssemblerError, "unknown word: #{word.inspect}"
        end
      end
    end

    def debugger
      emu = Emulator.new(finalize)
      emu.memory.add_extensions(extensions)
      Debugger.new(emu, self)
    end
  end
end

