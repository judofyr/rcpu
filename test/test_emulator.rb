$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require 'minitest/autorun'
require 'rcpu'
require 'rcpu/emulator'

module RCPU
  class TestEmulator < MiniTest::Unit::TestCase
    def rcpu(&blk)
      linker = Linker.new
      linker.instance_eval(&blk)
      @emu = Emulator.new(linker.finalize)
      @emu.run
    end

    def memory
      @emu.memory
    end

    def test_set
      rcpu do
        program :_main do
          block :init do
            SET a, 0x30
            SET [0x2000], a

            SET b, 0x2001
            SET [b], 0x10
            jump :crash
          end

          block :crash do
            jump :crash
          end
        end
      end

      assert_equal 0x30, memory[0x2000]
      assert_equal 0x10, memory[0x2001]
    end
  end
end

