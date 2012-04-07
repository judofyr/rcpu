$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require 'minitest/autorun'
require 'rcpu'

module RCPU
  class TestCase < MiniTest::Unit::TestCase
    def rcpu(run = true, &blk)
      lib = Library.new
      lib.instance_eval(&blk)
      linker = Linker.new
      linker.compile(lib)
      @emu = Emulator.new(linker.finalize)
      @emu.memory.add_extensions(linker.extensions)
      @emu.run if run
    end

    def memory
      @emu.memory
    end

    def register(name)
      @emu.registers[name]
    end

    def block(&blk)
      rcpu do
        block :main do
          instance_eval(&blk)

          label :crash
          SET pc, :crash
        end
      end
    end
  end
end

