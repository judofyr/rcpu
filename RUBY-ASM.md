# Ruby assembler

## Syntax

See http://0x10c.com/doc/dcpu-16.txt for the full specification.

```ruby
# Instructions:
SET a, 1  # Set the register A to 1
ADD a, 1  # Add 1 to the A register
SUB a, 1 
MUL a, 1 
DIV a, 1 
MOD a, 1 
SHL a, 1 
SHR a, 1 
AND a, 1 
BOR a, 1 
XOR a, 1 
IFE a, 1 
IFN a, 1 
IFG a, 1
IFB a, 1

JSR 123

# Values:
SET [a], 0x2000    # Set the address in register A to 0x2000
SET [a+1], [b]     # Set the address in A+1 to the value of the address in B
SET push, [0x2000] # Push the value of the address at 0x2000
```

## Block

The basic building block in RCPU is, well, a *block*:

```ruby
block :main do
  ADD a, 1
  ADD b, 2
  SUB pc, 1
end
```

The block called `main` will always be placed at the top of the program,
so that's where you should place the code that should run first.

You can have multiple blocks too:

```ruby
block :main do
  SET a, 1
  JSR :_testsub
end

block :testsub do
  ADD b, a
end
```

Notice that when you refer to a block, you need to prepend the name
with an underscore so RCPU will know that it's an *external* label (as
opposed to an internal one).

RCPU will also magically detect if you're not using a block, and then
it won't be included in the final program at all. This is useful when
you're writing libraries; you never need to worry about bloating the
final program by adding new blocks.

## Labels

Labels let's you refer to other parts of your block. All labels
are local inside the block to avoid name collisions.

```ruby
# Loop 100 times
block :main do
  label :loop
  ADD a, 1
  IFN a, 100
    SET pc, :loop

  SUB pc, 1
end
```

Labels are nothing else than literals that are resolved when the program
compiles. Here's an example which uses a literal to modify itself:

```ruby
# examples/modify.rcpu
block :main do
  SET i, 1
  # Change the constant in the block below.
  SET [i + :example], 0x2000

  label :example
  # Even though we set A to 0x1000, the code above sets it to 0x2000.
  SET a, 0x1000

  label :crash
  SET pc, :crash
end

```

## Data

You can use `data` to insert raw data with a label.

```ruby
# examples/data.rcpu
block :main do
  SET a, [:word]
  SET b, [:bytestring]
  SET c, [:string]

  label :crash
  SET pc, :crash

  # 1 word, filled with zeros
  data :word, 1

  # 3 words, filled with [1, 2, 3]
  data :bytestring, [1, 2, 3]
  
  # 3 words, filled with [1, 2, address to :string]
  data :labelstring, [1, 2, :string]

  # 6 words, filld with "hello\0"
  data :string, "hello\0"
end
```

You can also use `data` with a single argument to insert data without a
label:

```ruby
block :main do
  SET pc, :continue
  data "Hello World\0"
  label :continue
end
```

## Extensions

Extensions allows you to control specific parts of the memory:

```ruby
extension 0x8000, ScreenExtension, :width => 32, :height => 16
```

`extension` takes a start address, an extension class and some options.
It's up to the extension to decide how many words it occupies.

See [LIBRARIES.md](https://github.com/judofyr/rcpu/blob/master/LIBRARIES.md)
for a list of available extensions that ships with RCPU.

### Writing your own extensions

Writing your own extension is pretty easy:

```ruby
class MyExtension
  # The extension will be initialize with the memory array and the start
  # address given to the #extension call.
  def initialize(array, start)
    @array = array
    @start = start
  end
  
  # You need to implement #map which should yield all the addresses that
  # you wish to control.
  def map
    # Take control of 5 words; starting from @start
    5.times do |x|
      yield @start + x
    end
  end
  
  # Then you must implement a getter.
  def [](key)
    # 1st address gets multiplied by 1, 2nd by 2, 3rd by 3, and so on.
    @array[key] * (key - @start + 1)
  end
  
  # And a setter.
  def []=(key, value)
    @array[key] = value
  end
end
```

