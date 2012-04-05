$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require 'minitest/autorun'
require 'rcpu'

module RCPU
  class TestEmulator < MiniTest::Unit::TestCase
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

    def test_parse
      ins = []
      rcpu(false) do
        block :main do
          SET a, 1
          ins << @ins.last

          ADD [a], 0x1000
          ins << @ins.last

          SUB (a+1), [0x10]
          ins << @ins.last

          SET push, o
          ins << @ins.last

          SET x, pop
          ins << @ins.last

          SET x, peek
          ins << @ins.last

          SET x, pc
          ins << @ins.last

          JSR :crash

          label :crash
          SUB pc, 1
        end
      end

      until ins.empty?
        assert_equal ins.shift, @emu.next_instruction[1]
        @emu.tick
      end
    end

    def test_set
      block do
        SET a, 0x30
        SET [0x2000], a

        SET b, 0x2001
        SET [b], 0x10
      end

      assert_equal 0x30, memory[0x2000]
      assert_equal 0x10, memory[0x2001]
    end

    def test_add
      block do
        SET [0x1000], 0x5678    # low word
        SET [0x1001], 0x1234    # high word
        ADD [0x1000], 0xCCDD    # add low words, sets O to either 0 or 1 (in this case 1)
        ADD [0x1001], o         # add O to the high word
        ADD [0x1001], 0xAABB
        ADD [0x1001], o
      end

      assert_equal 0x2355, memory[0x1000]
      assert_equal 0xBCF0, memory[0x1001]
    end

    def test_sub
      block  do
        SET [0x1000], 0x5678
        SUB [0x1000], 0xCCDD
      end

      assert_equal 0x899B, memory[0x1000]
      assert_equal 0xFFFF, register(:O)
    end

    def test_mul
      block do
        SET [0x1000], 0x5678
        MUL [0x1000], 0x3
      end

      assert_equal 0x0368, memory[0x1000]
      assert_equal 0x1, register(:O)
    end

    def test_div
      block do
        SET [0x1000], 15
        DIV [0x1000], 4
      end

      assert_equal 3, memory[0x1000]
      assert_equal 0xC000, register(:O)

      block do
        SET [0x1000], 15
        DIV [0x1000], 0
      end

      assert_equal 0, memory[0x1000]
      assert_equal 0, register(:O)
    end

    def test_mod
      block do
        SET [0x1000], 15
        MOD [0x1000], 4
      end

      assert_equal 3, memory[0x1000]

      block do
        SET [0x1000], 15
        MOD [0x1000], 0
      end

      assert_equal 0, memory[0x1000]
    end

    def test_shl
      block do
        SET [0x1000], 0xFFFF
        SHL [0x1000], 4
      end

      assert_equal 0xFFF0, memory[0x1000]
      assert_equal 0xF, register(:O)
    end

    def test_shr
      block do
        SET [0x1000], 0xFF
        SHR [0x1000], 4
      end

      assert_equal 0xF, memory[0x1000]
      assert_equal 0xF000, register(:O)
    end

    def test_and
      block do
        SET [0x1000], 5
        AND [0x1000], 4
      end

      assert_equal (5 & 4), memory[0x1000]
    end

    def test_bor
      block do
        SET [0x1000], 5
        BOR [0x1000], 4
      end

      assert_equal (5 | 4), memory[0x1000]
    end

    def test_xor
      block do
        SET [0x1000], 5
        XOR [0x1000], 4
      end

      assert_equal (5 ^ 4), memory[0x1000]
    end

    def test_ife
      block do
        SET a, 5
        IFE a, 4
          SET b, 1
        IFE a, 5
          SET pc, :crash
        SET b, 1
      end

      assert_equal 0, register(:B)
    end

    def test_ifn
      block do
        SET a, 5
        IFN a, 5
          SET b, 1
        IFN a, 4
          SET pc, :crash
        SET b, 1
      end

      assert_equal 0, register(:B)
    end

    def test_ifg
      block do
        SET a, 5
        IFG a, 6
          SET b, 1
        IFG a, 3
          SET pc, :crash
        SET b, 1
      end

      assert_equal 0, register(:B)
    end

    def test_ifb
      block do
        SET a, 5
        IFB a, 2
          SET b, 1
        IFB a, 1
          SET pc, :crash
        SET b, 1
      end

      assert_equal 0, register(:B)
    end

    def test_stack
      block do
        SET a, sp
        SET push, 2
        SET push, 3
        SET b, pop
        SET c, pop
        SET x, sp
      end

      # Default SP
      assert_equal 0, register(:A)
      # Push and pop
      assert_equal 3, register(:B)
      assert_equal 2, register(:C)
      # Final value of SP
      assert_equal 0, register(:X)
    end

    def test_bytedata
      block do
        SET a, [:hello]
        SET [:hello], 123
        SET b, [:hello]
        SET pc, :crash

        data :hello, [12]
      end

      assert_equal 12, register(:A)
      assert_equal 123, register(:B)
    end

    def test_zerodata
      block do
        SET i, 1

        SET a, 1
        SET a, [:hello]

        SET b, 1
        SET b, [i+:hello]
        SET pc, :crash

        data :hello, 2
      end

      assert_equal 0, register(:A)
      assert_equal 0, register(:B)
    end

    def test_stringdata
      block do
        SET i, 1
        SET a, [:hello]
        SET b, [i+:hello]
        SET pc, :crash

        data :hello, "ab"
      end

      assert_equal "a".ord, register(:A)
      assert_equal "b".ord, register(:B)
    end

    def test_unknowndata
      assert_raises(AssemblerError, "unkown data type") do
        block do
          data :hello, :nope
        end
      end
    end

    def test_missing_label
      assert_raises(AssemblerError, "no label: fail") do
        block do
          SET pc, :fail
        end
      end
    end

    def test_multiple_blocks
      rcpu do
        block :main do
          JSR :_another
          label :crash
          SET pc, :crash
        end

        block :another do
          SET a, 1
          SET pc, pop
        end
      end

      assert_equal 1, register(:A)
    end

    def test_missing_block
      assert_raises(AssemblerError, "no external label: another") do
        block do
          JSR :_another
        end
      end
    end

    class VoidExtension
      def initialize(array, start)
        @array = array
        @start = start
      end

      def map; yield @start end

      def [](key)
        0
      end

      def []=(key, value)
        # do nothing
      end
    end

    def test_extension
      rcpu do
        extension 0x1000, VoidExtension

        block :main do
          SET [0x1000], 5
          label :crash
          SET pc, :crash
        end
      end

      assert_equal 0, memory[0x1000]
    end

    def test_format
      rcpu(false) do
        block :main do
          SET a, 1
          ADD [a], 0x1000
          SUB [a+1], [0x10]
          SET push, o
          SET x, pop
          SET x, peek
          SET x, pc
          JSR :crash
          label :crash
          SUB pc, 1
        end
      end

      res = [
        "SET a, 0x1",
        "ADD [a], 0x1000",
        "SUB [a+1], [0x10]",
        "SET push, o",
        "SET x, pop",
        "SET x, peek",
        "SET x, pc",
        "JSR 0xC",
        "SUB pc, 0x1"
      ]

      until res.empty?
        assert_equal res.shift, @emu.next_instruction[1].to_s
        @emu.tick
      end
    end
  end
end

