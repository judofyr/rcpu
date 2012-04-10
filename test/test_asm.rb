require 'helper'

module RCPU
  class TestASM < TestCase
    def test_notch
      asm <<-ASM, false
;Notch's examples
;Should compile fine, by default

;Try some basic stuff
		SET A, 0x30				; 7c01 0030
		SET [0x1000], 0x20		; 7de1 1000 0020
		SUB A, [0x1000]			; 7803 1000
		IFN A, 0x10				; c00d 
		SET PC, crash         	; 7dc1 001a [*]
                      
;Do a loopy thing
		SET I, 10               ; a861
		SET A, 0x2000           ; 7c01 2000
:loop	SET [0x2000+I], [A]		; 2161 2000
		SUB I, 1				; 8463
		IFN I, 0				; 806d
		SET PC, loop			; 7dc1 000d [*]
        
;Call a subroutine
		SET X, 0x4				; 9031
		JSR testsub				; 7c10 0018 [*]
		SET PC, crash			; 7dc1 001a [*]
        
:testsub
		SHL X, 4				; 9037
		SET PC, POP				; 61c1
                        
								
;Hang forever. X should now be 0x40 if everything went right.
:crash	SET PC, crash			; 7dc1 001a [*]

; Assembler test for DCPU
; by Markus Persson

		set a, 0xbeef				; Assign 0xbeef to register a
		set [0x1000], a				; Assign memory at 0x1000 to value of register a
		ifn a, [0x1000]				; Compare value of register a to memory at 0x1000 ..
			set PC, end				; .. and jump to end if they don't match

		set i, 0; Init loop counter, for clarity
:nextchar
		ife [data+i]				, 0; If the character is 0 ..
		set PC, end					; .. jump to the end
		set [0x8000+i], [data+i]	; Video ram starts at 0x8000, copy char there
		add i, 1					; Increase loop counter
		set PC, nextchar			; Loop
  
:data	dat "Hello world!", 0; Zero terminated string

:end	sub PC, 1; Freeze the CPU forever
      ASM

      rcpu(false) do
        block :main do
          SET a, 0x30				
          SET [0x1000], 0x20		
          SUB a, [0x1000]			
          IFN a, 0x10				
          SET pc, :crash         	


          SET i, 10               
          SET a, 0x2000           
          label :loop
          SET [i+0x2000], [a]		
          SUB i, 1				
          IFN i, 0				
          SET pc, :loop			

          SET x, 0x4				
          JSR :testsub				
          SET pc, :crash			

          label :testsub
          SHL x, 4				
          SET pc, pop

          label :crash
          SET pc, :crash			

          SET a, 0xbeef				
          SET [0x1000], a				
          IFN a, [0x1000]				
          SET pc, :end				

          SET i, 0
          label :nextchar
          IFE [i+:data], 0
          SET pc, :end					
          SET [i+0x8000], [i+:data]	
          ADD i, 1					
          SET pc, :nextchar			

          data :data, "Hello world!\0"
          label :end
          SUB pc, 1
        end
      end

      assert_equal memory.array[0, 70], @asmemu.memory.array[0, 70]
    end
  end
end

