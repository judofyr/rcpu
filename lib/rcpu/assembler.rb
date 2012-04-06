module RCPU
  class Block
    def initialize(&blk)
      @ins = []
      @data = {}
      instance_eval(&blk)
    end

    def data(name, data)
      label(name)
      if data.kind_of? Symbol
        @ins << data
      elsif data.respond_to?(:to_ary)
        @ins << ByteData.new(data)
      elsif data.respond_to?(:to_int)
        @ins << ZeroData.new(data)
      elsif data.respond_to?(:to_str)
        @ins << StringData.new(data)
      else
        raise AssemblerError, "unknown data type"
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
        raise "Missing: #{value.inspect}"
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

    def all_blocks
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
  end

  def self.define(name, &blk)
    l = Library.new
    l.instance_eval(&blk)
    Linker.default_libraries[name] = l
  end

  class Linker
    attr_reader :extensions

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
      end
    end

    def load_file(file)
      l = Library.new
      l.scope = File.dirname(file)
      l.instance_eval(File.read(file), file)
      @libraries[file] = l
    end

    def compile(library, name = :main)
      gather(library)
      block = @blocks[name] or raise AssemblerError, "no block: #{name}"
      compile_block(name, block)
    end

    def compile_block(name, block)
      @seen[name] = @memory.size
      pending = []
      m, labels = block.to_machine
      start = @memory.size
      m.each do |word|
        case word
        when External
          name = word.name
          pending << name unless @seen[name]
          @memory << name
        when Label
          location = labels[word.name] or raise AssemblerError, "no label: #{word.name}"
          @memory << location + start
        else
          @memory << word
        end
      end

      pending.each do |name|
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
          raise AssemblerError, "unknown word: #{word}"
        end
      end
    end

    def dump
      finalize.each_slice(8).each_with_index do |r, i|
        print "#{(i*8).to_s(16).rjust(4, '0')}: "
        puts r.map { |x| x.to_s(16).rjust(4, '0') }.join(" ")
      end
    end
  end
end

