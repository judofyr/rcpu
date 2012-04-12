require 'helper'

module RCPU
  class TestEmulator < TestCase
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
          ADD [a+0xFFFF], 0x1000
          ADD [a-2], 0x1000
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
        "ADD [a-1], 0x1000",
        "ADD [a-2], 0x1000",
        "SUB [a+1], [0x10]",
        "SET push, o",
        "SET x, pop",
        "SET x, peek",
        "SET x, pc",
        "JSR 0x12",
        "SUB pc, 0x1"
      ]

      until res.empty?
        assert_equal res.shift, @emu.next_instruction[1].to_s
        @emu.tick
      end
    end

    def test_parse_number
      rcpu do
        library :parse

        block :main do
          SET a, 10
          SET b, 3
          SET c, :base10
          JSR :_parse_number
          SET [0x1000], x
          SET [0x1001], o

          SET a, 16
          SET b, 3
          SET c, :base16
          JSR :_parse_number
          SET [0x1002], x
          SET [0x1003], o

          SET a, 2
          SET b, 3
          SET c, :base2
          JSR :_parse_number
          SET [0x1004], x
          SET [0x1005], o

          SET a, 5
          SET b, 3
          SET c, :base16
          JSR :_parse_number
          SET [0x1006], o

          SUB pc, 1

          data :base10, "123"
          data :base16, "11F"
          data :base2,  "101"
        end
      end

      assert_equal 123, memory[0x1000]
      assert_equal 0, memory[0x1001]
      assert_equal 0x11F, memory[0x1002]
      assert_equal 0, memory[0x1003]
      assert_equal 0b101, memory[0x1004]
      assert_equal 0, memory[0x1005]
      assert_equal 1, memory[0x1006]
    end

    def test_sin_table
      n = 16

      rcpu(false) do
        block :main do
          extend TrigMacros
          sin_lookup_table n
        end
      end

      expected = [32767, 45307, 55937, 63040,
                  65535, 63040, 55937, 45307,
                  32767, 20227, 9597, 2494,
                  0, 2494, 9597, 20227]

      assert_equal expected, memory.slice(0...n)
    end

    # Tests PC wraparound in the middle of an instruction.
    def test_pc_wrap
      rcpu do
        block :main do
          crash = 0x85c3 # SUB PC, 1
          set_z = 0x7c51 # SET z, <next word>
          SET y, crash
          SET pc, :wrapped_instruction
          data :pad, Array.new(65531, 0)
          data :wrapped_instruction, [set_z]
        end
      end

      assert_equal 0x85c3, register(:Y)
      assert_equal 0x7c41, register(:Z)
    end
  end
end

