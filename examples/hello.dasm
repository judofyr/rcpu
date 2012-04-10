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
