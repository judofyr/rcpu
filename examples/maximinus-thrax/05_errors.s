;list of errors that all compilers should check
;all lines up to :start will be skipped by the test program

:start
		sit a, 3		;instruction name incorrect
		set d, 4		;wrong register name
		set a, 70000	;integer too big
		set a, 0xfffff	;hex value too large
		set a a			;no comma to seperate
		set a			;missing operand
		set				;no operands
label	set a, 0		;label has no colon
loop:	set a, 0		;label is at wrong end
		set a, [x		;missing right square bracket
		set a, x]		;missing left square bracket
		jsr a, a		;too many operands on a jsr
		set a, aaa		;no label exists
		set a, [aaa]	;no indexed label exists
		div a, 0		;catch compiler divide by zero errors