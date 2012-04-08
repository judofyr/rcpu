require 'tsort'

module RCPU

module StandardMacros
  ARG_REGS = [:A, :B, :C].map { |name| RCPU::Register.new(name) }

  class MoveSorter
    include TSort
    SPILL_REG = RCPU::Register.new(:O)

    Move = Struct.new(:src, :dst, :spill)

    def initialize(args)
      fail "too many arguments" if args.size > ARG_REGS.size
      used_arg_regs = ARG_REGS[0...(args.size)]
      @moves = args.zip(used_arg_regs).
        map { |arg,reg| Move.new(arg, reg, false) }.
        reject { |move| move.src == move.dst }
    end

    def tsort_each_node(&blk)
      @moves.each(&blk)
    end

    def tsort_each_child move, &b
      @moves.each do |move2|
        yield move2 if !move.spill && move.dst == move2.src 
      end
    end

    # Move the given register to temporary storage and rewrite reads from it
    # to point to the new location.
    def spill(reg)
      spill_move = Move.new(reg, SPILL_REG, true)
      @moves.each do |move|
        move.src = SPILL_REG if move.src == reg
      end
      @moves << spill_move
    end

    # Return an array of Move objects in the order they should be executed.
    def sort
      # Find a cycle in the move graph and pick a register to spill to break it.
      spillee = nil
      each_strongly_connected_component do |component|
        if component.size > 1
          fail if spillee # There is one cycle with 3 registers.
          spillee = component.first.src
        end
      end

      # Break the cycle.
      spill(spillee) if spillee

      tsort
    end
  end

  # Implements the calling convention from https://gist.github.com/2313564
  def call(dest, *args)
    # Split into register and stack args
    stack_args = args.dup
    reg_args = stack_args.slice! 0...3

    # Push all the stack arguments in reverse order
    stack_args.reverse.each do |arg|
      SET push, arg
    end

    # Set the argument registers
    MoveSorter.new(reg_args).sort.each do |move|
      SET move.dst, move.src
    end

    JSR dest

    # Clean up the stack arguments
    ADD sp, stack_args.size if stack_args.size > 0
  end

  def fun_prologue
    SET push, j
    SET j, sp
  end

  def fun_epilogue
    SET sp, j
    SET j, pop
    SET pc, pop
  end

  def fun(&blk)
    fun_prologue

    # Give the block storage locations for each argument it accepts.
    num_args = blk.arity
    args = (0...num_args).map do |i|
      if reg = ARG_REGS[i]
        reg
      else
        PlusRegister.new(j, 2+i-ARG_REGS.size)
      end
    end

    yield *args

    fun_epilogue
  end

  # Allocate storage for local variables on the stack.
  def locals(&blk)
    @stack_usage ||= 0
    num_locals = blk.arity

    # Allocate stack space
    locals = (0...num_locals).map do |i|
      offset = -(@stack_usage+i+1)
      PlusRegister.new j, (offset & 0xFFFF)
    end
    @stack_usage += num_locals
    SUB sp, num_locals

    yield *locals

    # Deallocate stack space
    ADD sp, num_locals
    @stack_usage -= num_locals
  end
end

module TrigMacros
  # Generates a sine lookup table.
  # The table covers one period. The y values range from 0 to 65535.
  def sin_lookup_table size
    values = (0...size).map { |i| ((Math.sin(i*2*Math::PI/size)/2 + 0.5) * 65535).to_i }
    data :bytestring, values
  end
end

end
