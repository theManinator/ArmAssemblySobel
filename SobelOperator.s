	AREA	BonusEffect, CODE, READONLY
	IMPORT	main
	IMPORT	getPicAddr
	IMPORT	putPic
	IMPORT	getPicWidth
	IMPORT	getPicHeight
	EXPORT	start

	PRESERVE8
start

	BL	getPicAddr	; load the start address of the image in R4
	MOV	R4, R0
	BL	getPicHeight	; load the height of the image (rows) in R5
	MOV	R5, R0
	BL	getPicWidth	; load the width of the image (columns) in R6
	MOV	R6, R0
	LDR R7, =0xA1800000

	MOV R0, R4	;Preperation for greyScale
	MOV R1, R5
	MOV R2, R6
	BL greyScale

	MOV R0, R4	;Preperation for picDup
	MOV R1, R7
	MOV R2, R6
	MOV R3, R5
	BL picDup

	MOV R0, R4 ;Preperation for sobelOperator
	MOV R1, R7
	MOV R2, R5
	MOV R3, R6
	BL sobelOperator

	BL	putPic		; re-display the updated image

stop	B	stop

;Subroutine sobelOperator
;Convolves an image with the sobel operator
;Parameters: R0-editImageAddress
;			 R1-cleanImageAddress
;			 R2-imageHeight
;			 R3-imageWidth
sobelOperator
	STMFD SP!, {R4 - R9 , LR}
	MOV R4, R0	;Creates local variables
	MOV R5, R1
	MOV R6, R2
	MOV R7, R3

	MOV R9, #0
rowSobel			;for(int j = 0; j < imageHeightLimit;j ++){
	CMP R9, R6
	BGT endRowSobel
	MOV R8, #0
columnSobel 		;for(int i = 0; i < imageWidthLimit; i ++){
	CMP R8, R7
	BGT endColumnSobel

	MOV R0, R5		;Preperation for sobelPixel
	MOV R1, R7
	MOV R2, R8
	MOV R3, R9
	STMFD SP!, {R6}
	BL sobelPixel
	LDMFD SP!, {R6}

	MOV R1, R0		;Constructs pixel using the blue value as the colour for all values
	MOV R2, R0
	BL constructPixel

	STMFD SP!, {R0}	;Preperation for storePixel
	STMFD SP!, {R7}
	STMFD SP!, {R8-R9}
	STMFD SP!, {R4}
	BL storePixel
	LDMFD SP!, {R4}	;Unloads stack
	LDMFD SP!, {R8-R9}
	LDMFD SP!, {R7}
	LDMFD SP!, {R0}

	ADD R8, R8, #1
	B columnSobel
endColumnSobel	;}
	ADD R9, R9, #1
	B rowSobel	;}
endRowSobel

	LDMFD SP!, {R4 - R9 , PC}

;Subroutine sobelPixel
;Returns the pixel that has been convolved with the sobel operator
;Parameters R0 - picAddress
;			R1 - imageWidth
;			R2 - pixelI
;			R3 - pixelJ
;			SP - imageHeight
;		RETURNS R0- returnPixel
sobelPixel
	STMFD SP!, {R4 - R9 , LR}
	MOV R4, R0	;creates local variables
	MOV R5, R1
	MOV R6, R2
	MOV R7, R3
	LDR R8, [SP, #28 ]

	SUB R6, R6, #1	;startingI = pixelI - 1
	SUB R7, R7, #1 	;startingJ = pixelJ - 1
	MOV R9, #0	;gradientTotal = 0

	
	MOV R0, R6	;Preperation for getHorizontalGradient
	MOV R1, R7
	MOV R2, R4
	MOV R3, R5
	STMFD SP!, {R8}
	BL getHorizontalGradient
	LDMFD SP!, {R8}
	MUL R1, R0, R0	;horizontalGradient *= 2
	ADD R9, R9, R1	;adds horizontalGradient to gradientTotal

	MOV R0, R6 		;Preperation for getVerticalGradient
	MOV R1, R7
	MOV R2, R4
	MOV R3, R5
	STMFD SP!, {R8}
	BL getVerticalGradient
	LDMFD SP!, {R8}
	MUL R1, R0, R0	;verticalGradient *= 2
	ADD R9, R9, R1	;adds verticalGradient to gradientTotal

	MOV R0, R9		;gets square root of totalGradient
	BL getSquareRoot

	CMP R0, #255	;if(gradient>255)
	BLE smallerThan256
	MOV R0, #255 	;gradient = 255
smallerThan256
	CMP R0, #0		;if(gradient < 0)
	BGE notEdge
	MOV R0, #0		;gradient = 0
notEdge		
	LDMFD SP!, {R4 - R9 , PC}

;Subroutine getVerticalGradient
;Returns the vertical gradient for the given pixel
;Parameters: R0-startingI
;			 R1-startingJ
;			 R2-picAddress
;			 R3-picWidth
;			 SP-picHeight
;			Returns: R0-verticalGradient
getVerticalGradient
	STMFD SP!, {R4 - R12 , LR}
	MOV R4, R0	;Creates local variables
	MOV R5, R1
	MOV R6, R2
	MOV R10, R3
	ADD R7, R4, #3	;maxI = i + 3
	ADD R8, R5, #3	;maxJ = j + 3
	MOV R9, #0	;maskAddress = 0	

	MOV R12, #0	;int verticalGradient = 0

verticalJWhile	;for(int j = startingJ; j < maxJ; j ++)
	CMP R5, R8
	BEQ endVerticalJWhile
	MOV R11, R4
verticalIWhile	;for(int i = startingI; i < maxI; i ++)
	CMP R11, R7
	BEQ endVerticalIWhile
	STMFD SP!, {R11}	;stores i for later use

	MOV R0, R6	;Preperation for getPixel
	MOV R1, R11
	MOV R2, R5
	MOV R3, R10
	LDR R11, [SP,#44]
	STMFD SP!, {R11}
	BL getPixel
	LDMFD SP!, {R11}

	BL getBlue
	
	STMFD SP!, {R4}	;Clears R4 for use
	LDR R4, =VerticalMask
	LDR R4, [R4, R9]
	MUL R0, R4, R0	;multiplies value times appropriate mask value
	ADD R12, R12, R0	;adds value to gradientTotal
	LDMFD SP!, {R4}	;restores R4
	ADD R9, R9, #4	;maskAddress += 4
	LDMFD SP!, {R11}	;restores i
	ADD R11, R11, #1
	B  verticalIWhile
endVerticalIWhile
	ADD R5, R5, #1
	B verticalJWhile
endVerticalJWhile
	MOV R0, R12
	LDMFD SP!, {R4 - R12 , PC}

;Subroutine getSquareRoot
;Returns the square root of a given number
;Parameters: R0-number
;	Returns: R0-squareRoot
getSquareRoot
	STMFD SP!, {LR}
	MOV R4, R0
	MOV R8, R0
	
	MOV R7, R4, LSR #1	;squareRoot = number / 2	//Creates good initial seed

	MOV R5, #8	;number of approximations = 8 //Works for all possible numbers

	MOV R6, #0
squareRootWhile		;for(int approximation = 0; approximation < numberOfApproximations; approximation ++)
	CMP R6, R5
	BEQ endSquareRootWhile

	MOV R0, R4		;nextApproximation = number / currentApproximation
	MOV R1, R7
	BL divide

	ADD R7, R7, R0	;nextApproximation += currentApproximation
	
	MOV R7, R7, LSR #1	;nextApproximation /= 2
	
	ADD R6, R6, #1
	B squareRootWhile
endSquareRootWhile
	MOV R0, R7
	LDMFD SP!, {PC}

;Subroutine getHorizontalGradient
;Returns the horizontal gradient for the given pixel
;Parameters: R0-startingI
;			 R1-startingJ
;			 R2-picAddress
;			 R3-picWidth
;			 SP-picHeight
;			Returns: R0-horizontalGradient
getHorizontalGradient
	STMFD SP!, {R4 - R12 , LR}
	MOV R4, R0	;Creates local variables
	MOV R5, R1
	MOV R6, R2
	MOV R10, R3
	ADD R7, R4, #3	;maxI = i + 3
	ADD R8, R5, #3	;maxJ = j + 3
	MOV R9, #0	;maskAddress = 0	

	MOV R12, #0	;int horizontalGradient = 0

horizontalJWhile	;for(int j = startingJ; j < maxJ; j ++)
	CMP R5, R8
	BEQ endHorizontalJWhile
	MOV R11, R4
horizontalIWhile    ;for(int i = startingI;i < maxI;i ++)
	CMP R11, R7
	BEQ endHorizontalIWhile
	STMFD SP!, {R11}	;stores i on stack for later use

	MOV R0, R6 		;preperation for getPixel
	MOV R1, R11
	MOV R2, R5
	MOV R3, R10
	LDR R11, [SP,#44]
	STMFD SP!, {R11}
	BL getPixel
	LDMFD SP!, {R11}

	BL getBlue
	
	STMFD SP!, {R4}		;Allows the use of R4
	LDR R4, =HorizontalMask	
	LDR R4, [R4, R9]
	MUL R0, R4, R0	;Multiplies value times corresponding mask value
	ADD R12, R12, R0	;Adds to gradientTotal
	LDMFD SP!, {R4}	;Restores R4
	ADD R9, R9, #4	;maskAddress += 4
	LDMFD SP!, {R11}	;restores i
	ADD R11, R11, #1
	B  horizontalIWhile
endHorizontalIWhile
	ADD R5, R5, #1
	B horizontalJWhile
endHorizontalJWhile
	MOV R0, R12
	LDMFD SP!, {R4 - R12 , PC}

;Subroutine getBlue
;Returns the blue component of a given pixel
;Parameters: R0 - givenPixel
;			 R0 - returnBlue
getBlue
	STMFD SP!, {R4, LR}
	LDR R4, =0x000000FF
	AND R0, R0, R4		;Removes red and green components
	LDMFD SP!, {R4, PC}

;Subroutine getGreen
;Returns the green component of a given pixel
;Parameters: R0 - givenPixel
;			 R0 - returnGreen
getGreen
	STMFD SP!, {R4, LR}
	LDR R4, =0x0000FF00
	AND R0, R0, R4 	;Removes red and blue components
	LSR R0, R0, #8	;Normalises green value
	LDMFD SP!, {R4, PC}

;Subroutine getRed
;Returns the red component of a given pixel
;Parameters: R0 - givenPixel
;			 R0 - returnRed
getRed
	STMFD SP!, {R4, LR}
	LDR R4, =0x00FF0000
	AND R0, R0, R4 	;Removes green and blue components
	LSR R0, R0, #16	;Normalises red value
	LDMFD SP!, {R4, PC}

;Subroutine greyscale
;Converts a picture to greyscale
;Parameters: R0 - picAddress
;			 R1 - imageHeight
;			 R2 - imageWidth
greyScale
	STMFD SP!, {R4 - R9, LR}
	MOV R4, R0	;int address = picAddress
	MOV R5, R1	;int height = imageHeight
	MOV R6, R2	;int width = imageWidth

	MOV R7, #0
rowWhile
	CMP R7, R5	;for(int currentRow = 0;currentRow < height;currentRow ++)
	BEQ endRowWhile;{
	MOV R8, #0
columnWhile
	CMP R8, R6	;for(int currentColumn = 0;currentColumn < width;currentColumn ++)
	BEQ endColumnWhile;{
	
	MOV R0, R4 ;Preperation for getPixel method
	MOV R1, R8 ;...
	MOV R2, R7 ;...
	MOV R3, R6 ;...
	STMFD SP!, {R5}
	BL getPixel
	LDMFD SP!, {R5}

	BL greyscalePixel

	MOV R9, R0 ;Preperation for storePixel method
	MOV R0, R4 ;...
	MOV R1, R8 ;...
	MOV R2, R7 ;...
	MOV R3, R6 ;...
	STMFD SP!, {R0 - R3, R9} ;...
	BL storePixel
	LDMFD SP!, {R0 - R3, R9}

	ADD R8, R8, #1
	B columnWhile;}
endColumnWhile
	
	ADD R7, R7, #1
	B rowWhile;}
endRowWhile
	LDMFD SP!, {R4 - R9, PC}
	
;Subroutine: greyscalePixel 
;Returns a greyscale version of a given pixel
;Parameters: R0 - givenPixel
;			 R0 - returnPixel
greyscalePixel
	STMFD SP!, {R4 - R7 , LR}
	MOV R4, R0	;Creates copy of pixel for later use
	
	BL getRed
	MOV R5, R0	;int redComponent = returnValue
	MOV R0, R4
	BL getGreen
	MOV R6, R0	;int greenComponent = returnValue
	MOV R0, R4
	BL getBlue
	MOV R7, R0	;int blueComponent = returnValue
	
	MOV R0, R5	;Gets greyscale value of redComponent
	MOV R1, #21
	MOV R2, #100
	BL multiplyAndDivide
	MOV R5, R0 	;int greyRed = returnValue
	
	MOV R0, R6	;Gets greyscale value of green component
	MOV R1, #71
	MOV R2, #100
	BL multiplyAndDivide
	MOV R6, R0	; int greyGreen = returnValue
	
	MOV R0, R7	;Gets greyscale value of blue component
	MOV R1, #7
	MOV R2, #100
	BL multiplyAndDivide
	MOV R7, R0	;int greyBlue = returnValue
	
	ADD R0, R5, R6
	ADD R0, R0, R7	;int greyAverage
	MOV R1, R0	;Preperation for constructPixel method
	MOV R2, R0	;...
	BL constructPixel	
	LDMFD SP!, {R4 - R7 , PC}


;Subroutine: constructPixel
; Given a red, blue and green component, constructs a pixel
;Parameters: R0 - red
;			 R1 - green
;			 R2 - blue
;			 R0 - returnPixel
constructPixel
	STMFD SP!, {LR}
	LSL R0, R0, #8	;int greyscale = red <<8
	ADD R0, R0, R1	;int greyscale += green
	LSL R0, R0, #8  ;int greyscale = greyscale <<8
	ADD R0, R0, R2	;int greyscale += blue	
	LDMFD SP!, {PC}
	
;Subroutine: multiplyAndDivide
; Multiplies value by a number and then divides by a number
;Parameters: R0 - value
;			 R1 - multiplyValue
;			 R2 - divideValue
;			 R0 - returnValue
multiplyAndDivide
	STMFD SP!, {LR}
	MUL R0, R1, R0	;int returnValue = value * multiplyValue
	MOV R1, R2 		;Preperation for divide
	BL divide	
	LDMFD SP!, {PC}
	
;Subroutine: divide
; Divides a by b
;Parameters: R0 - a
;			 R1 - b
;			 R0 - returnValue
divide
	STMFD SP!, {LR}
	CMP R1, #0 	;Ensures b != 0
	BEQ endDivide
	MOV R2, R0	;Remainder = a
	MOV R0, #0 	;int quotient = 0
divideWhile
	BCC endDivide ;while(remainder>=b){
	ADD R0, R0,	#1 ;Quotient = Qoutient+1
	SUBS R2, R2, R1 ; remainder = remainder-b
	b	divideWhile		;}
endDivide	
	LDMFD SP!, {PC}

;Subroutine: getPixel
;Retrieve the value of an element from a 2D array
;Parameters: R0 - arrayAddress
;			 R1 - i
;			 R2 - j
;			 R3 - N
;			 SP - Height
;			 R0 - Return value
getPixel
	STMFD SP!, {R4-R5, LR}	
	CMP R1, #0	;if(i < 0)
	BGE testJNegative
	MOV R0, #0	;return 0
	B returnPixel
testJNegative
	CMP R1, R3	;if(j < 0)
	BLT testITooBig
	MOV R0, #0	;return 0
	B returnPixel
testITooBig
	CMP R2, #0	;(if i > width)
	BGE testJTooBig
	MOV R0, #0	;return 0
	B returnPixel
testJTooBig
	LDR R5, [SP, #12]
	CMP R2, R5	;if( j > height)
	BLT continueGetPixel
	MOV R0, #0	;return 0
	B returnPixel

continueGetPixel
	MOV R5, #2	;int adressAdjustment = 2
	MOV R4, R3, LSL R5	;int longsPerRow = N * 4
	MUL R4, R2, R4	;int row = 	j * longsPerRow
	MOV R5, R1, LSL R5	;int column = i * 4
	ADD R4, R4, R5	;int index = column + row
	LDR R0, [R0, R4]
returnPixel
	LDMFD SP!, {R4-R5, PC}

;Subroutine storePixel
;Stores a pixel into a given index
;Parameters: SP - arrayAddress
;			 SP + 4 - i
;			 SP + 8 - j
;			 SP + 12 - N
;			 SP + 16 - newPixel
storePixel
	STMFD SP!, {R4-R6, LR}
	MOV R5, #2	;int addressAdjustment = 2
	LDR R3, [SP, #28]
	MOV R4, R3, LSL R5 		;int longsPerRow = N * 4
	LDR R2, [SP, #24]
	MUL R4, R2, R4		;int row = j * longsPerRow
	LDR R1, [SP, #20]
	MOV R5, R1, LSL R5		;int column = i * 4
	ADD R4, R4, R5		;int index = column + row
	LDR R6, [SP, #16]
	LDR R0, [SP, #32]
	STR R0, [R6, R4]	;Stores value at calculated pixel
	LDMFD SP!, {R4-R6, PC}

;Subroutine: picDup
;Creates a copy of a given picture
;Parameters: R0 - picAddress
;			 R1 - newAddress
;			 R2 - imageHeight
;			 R3 - imageWidth
picDup
	STMFD SP!, {R4 - R9 , LR}
	MOV R6, R0	;Makes copies of subroutine parameters
	MOV R7, R1
	MOV R9, R2
	MOV R4, #0
rowWhileDup		;for(int currentRow = 0; currentRow < imageHeight; currentRow ++){
	CMP R4, R9
	BEQ endRowWhileDup
	MOV R5, #0
columnWhileDup		;for(int currentColumn = 0; currentColumn < imageWidth; currentColumn ++){
	CMP R5, R3
	BEQ endColumnWhileDup
	MOV R0, R6	;Preperation for getPixel
	MOV R1, R5
	MOV R2, R4
	MOV R3, R3
	STMFD SP!, {R9}
	BL getPixel
	LDMFD SP!, {R9}

	MOV R8, R0	;Preperaion for storePixel
	MOV R0,	R7
	MOV R1, R5
	MOV R2, R4
	STMFD SP!, {R0 - R3, R8}
	BL storePixel
	LDMFD SP!, {R0 - R3, R8}

	ADD R5, R5, #1
	B columnWhileDup
endColumnWhileDup
	ADD R4, R4, #1
	B rowWhileDup
endRowWhileDup			
	LDMFD SP!, {R4 - R9, PC}

	AREA	SobelMask, DATA, READWRITE

HorizontalMask DCD -1, 0, 1
			   DCD -2, 0, 2
			   DCD -1, 0, 1

VerticalMask   DCD -1, -2, -1
			   DCD 0, 0, 0
			   DCD 1, 2, 1


	END	