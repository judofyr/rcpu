RCPU
====

Assembler and emulator for [DCPU](http://0x10c.com/doc/dcpu-16.txt) written in Ruby.

## Run binary files

```
$ bin/rcpu examples/hello.bin
Welcome to RCPU 0.1.0:
(^C) stop execution
(b) add breakpoint
(c) compile to binary
(d) dump memory and registrers
(e) evaluate ruby
(h) help (this message)
(p) ruby shell
(r) run
(s) step
(q) quit

You probably want to type 'r' for run or 'c' for compile

0000: JSR a
```


## Write assembly in Ruby

```ruby
# Run this with: bin/rcpu examples/hello.rcpu
library :screen

block :main do
  SET i, 0                           # Init loop counter, for clarity

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

See [RUBY-ASM.md](https://github.com/judofyr/rcpu/blob/master/RUBY-ASM.md)
for how you can use Ruby as a macro language for the DCPU-16.

## Write assembly like Notch

```dasm
; Run this with: bin/rcpu examples/hello.dasm
; Assembler test for DCPU
; by Markus Persson
.library screen

             set i, 0                             ; Init loop counter, for clarity
:nextchar    ife [data+i], 0                      ; If the character is 0 ..
                 set PC, end                      ; .. jump to the end
             set [0x8000+i], [data+i]             ; Video ram starts at 0x8000, copy char there
             add i, 1                             ; Increase loop counter
             set PC, nextchar                     ; Loop
  
:data        dat "Hello world!", 0                ; Zero terminated string

:end         sub PC, 1                            ; Freeze the CPU forever
```

See [NOTCH-ASM.md](https://github.com/judofyr/rcpu/blob/master/NOTCH-ASM.md)
for how you can write assembly like Notch does.

## Use libraries

See [LIBRARIES.md](https://github.com/judofyr/rcpu/blob/master/LIBRARIES.md)
for a set of built-in libraries that ships with RCPU.

