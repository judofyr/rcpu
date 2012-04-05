module RCPU
  module Loader
    @@libraries = {}
    @@blocks = {}

    def self.find(name, scope)
      case name
      when Symbol
        @@libraries[name] or raise "no lib: #{name}"
      when String
        full = File.expand_path(name, scope)
        @@libraries[full] || load_file(full)
      end
    end

    def self.find_block(name)
      @@blocks[name]
    end

    def self.setup(name)
      yield (lib = Library.new)
      @@libraries[name] = lib
      lib.blocks.each do |name, block|
        @@blocks[name] = lib
      end
      lib
    end

    def self.define(name, &blk)
      setup(name) do |l|
        l.instance_eval(&blk)
      end
    end

    def self.load_file(name)
      setup(name) do |l|
        l.scope = File.dirname(__FILE__)
        l.instance_eval(File.read(name), name)
      end
    end
  end
end

