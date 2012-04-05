RCPU
====

Assembler and emulator for [DCPU](http://0x10c.com/doc/dcpu-16.txt) written in Ruby:

```ruby
# Open it in the debugger: bin/rcpu examples/simple.rcpu

block :main do
  SET a, 2
  SET b, 2
  ADD a, b

  label :crash
  SET pc, :crash
end

```

Then you can step through it (or run it).

## Block

A block is a piece of executable code (like a lightweight function)
that has internal labels.

### Labels

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

### Data

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

  # 6 words, filld with "hello\0"
  data :string, "hello\0"
end

```

### External labels

External labels starts with an underscore and refers to another code
block:

```ruby
# examples/plus1.rcpu
block :main do
  JSR :_plus1
  JSR :_plus1
  JSR :_plus1

  label :crash
  SET pc, :crash
end

block :plus1 do
  ADD a, 1
  SET pc, pop
end
```

## Libraries

All your programs are also libraries; executables are merely libraries
that includes a `main`-block. By using `library` you can include other
libraries:

```ruby
# Use the built-in screen-library
library :screen

# Use a library called "foo.rcpu" in the same directory
library "foo"
```

RCPU ships with some built-in libraries:

### screen

`screen` maps 0x8000-0x8400 to a 32x16 terminal:

* 0x8000 is first row, first column
* 0x8001 is first row, second column
* ...
* 0x8020 is second row; first column

```ruby
# examples/hello.rcpu
library :screen

block :main do
  SET i, 0                             # Init loop counter, for clarity

  label :nextchar
  IFE [i+:string], 0                   # If the character is 0 ..
    SET pc, :end                       # .. jump to the end

  SET [i+0x8000], [i+:string]          # Video ram starts at 0x8000, copy char there
  ADD i, 1                             # Increase loop counter
  SET pc, :nextchar                    # Loop

  data :string, "Hello world!\0"       # Zero terminated string

  label :end
  SUB pc, 1                            # Freeze the CPU forever
end
```

#### Colors

*Note: This may change in the future to match 0x10c more closely.*

Only the 7 (least-significent) bits describes the character. The rest
describes the color:

```
FFFF BBBB _CCC CCCC
```

* The first 4 bits describes the text color.
* The second 4 bits describes the background color.
* The 9th bit is ignored.
* The final 7 bits is the character (ASCII).

Each color follows this structure:

* The first bit in a color describes the brightness (1 = bright/bold; 0
  = normal).
* The second is red
* the third is green
* the fourth is blue

Examples:

```
Black:         0000
White:         0111
Blue:          0001
Bright yellow: 1110
```

See also Notch's example script:


```ruby
# examples/hello2.rcpu
# Notch's second "hello word" program.
# http://i.imgur.com/XIXc4.jpg
# Supposed to show formatting.

library :screen

block :main do
  SET i, 0
  SET j, 0
  SET b, 0xf100

  label :nextchar
  SET a, [i+:data]
  IFE a, 0
    SET pc, :end
  IFG a, 0xff
    SET pc, :setcolor
  BOR a, b
  SET [j+0x8000], a
  ADD i, 1
  ADD j, 1
  SET pc, :nextchar

  label :setcolor
  SET b, a
  AND b, 0xff
  SHL b, 8
  IFG a, 0x1ff
    ADD b, 0x80
  ADD i, 1
  SET pc, :nextchar

  data :data, [0x170, "Hello ", 0x2E1, "world", 0x170, ", how are you?", 0]
  # Color format:
  # After processing:
  # 0x170 -> b = 0x7000 -> 0111 0000 0XXX XXXX = white(grey) on black
  # 0x2e1 -> b = 0xe180 -> 1110 0001 1XXX XXXX = yellow on blue
  #                        FORE BACK ? CHAR
  # Each color is: Brbg (where B = bold/brightness)

  label :end
  SUB pc, 1
end
```



