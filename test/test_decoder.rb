require 'helper'

module RCPU
  class TestInstructionDecoder < TestCase
    def check words, asm, expected_cycles
      lib = Library.new
      ASMParser.new(lib, asm).parse
      expected_inst = lib.blocks[:main].ins[0]
      decoder = InstructionDecoder.new words
      inst, new_pc, cycles = decoder.decode 0
      assert_equal expected_inst, inst
      assert_equal words.size, new_pc
      assert_equal expected_cycles, cycles
    end

    def test_invalid_instruction
      decoder = InstructionDecoder.new [0x00, 0x20, 0x3f0]

      (0...3).each do |pc|
        assert_raises DecoderError do
          inst, new_pc, cycles = decoder.decode pc
        end
      end
    end

    def test_basic_instructions
      check [0x2401],                  'SET a, [b]', 1
      check [0x18a2],                  'ADD [c], i', 1
      check [0x8573, 0x0001],          'SUB [1+j], 1', 2
      check [0x6584],                  'MUL pop, peek', 1
      check [0x6995],                  'DIV peek, push', 1
      check [0x61a6],                  'MOD push, pop', 1
      check [0x7db7, 0xffff],          'SHL SP, 0xFFFF', 2
      check [0x71f8, 0xffff],          'SHR 0xFFFF, PC', 2
      check [0xfdd9],                  'AND O, 31', 1
      check [0x79fa, 0x0020, 0x0000],  'BOR 32, [0]', 3
      check [0x0deb, 0xffff],          'XOR [0xFFFF], x', 2
      check [0x7c4c, 0x7fff],          'IFE y, 0x7FFF', 2
      check [0x795d, 0xffff, 0xffff],  'IFN [0xFFFF+z], [0xFFFF]', 3
      check [0x545e, 0x0],             'IFG z, [0+z]', 2
      check [0x75df],                  'IFB O, O', 1
    end

    def test_nonbasic_instructions
      check [0x0010], 'JSR a', 1
      check [0xfc10], 'JSR 31', 1
      check [0x7c10, 0x20], 'JSR 32', 2
      check [0x5410, 0x0a], 'JSR [10+z]', 2
    end
  end
end
