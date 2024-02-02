.data
displayBuffer:  .space 0x40000 # space for 512x256 bitmap display 
dummySpace:	.space 0x30
errorBuffer:    .space 0x40000 # space to store match function
templateBuffer: .space 0x100   # space for 8x8 template
imageFileName:    .asciiz "pxlcon512x256cropgs.raw" 
templateFileName: .asciiz "template8x8gs.raw"
# struct bufferInfo { int *buffer, int width, int height, char* filename }
imageBufferInfo:    .word displayBuffer  512 128  imageFileName
errorBufferInfo:    .word errorBuffer    512 128 0
templateBufferInfo: .word templateBuffer 8   8    templateFileName

.text
main:	la $a0, imageBufferInfo
	li $v0 1
	syscall
	jal loadImage
	
	la $a0, templateBufferInfo
	jal loadImage
	
	la $a0, imageBufferInfo
	la $a1, templateBufferInfo
	la $a2, errorBufferInfo
	jal matchTemplateFast       # MATCHING DONE HERE
	
	la $a0, errorBufferInfo
	jal findBest
	
	la $a0, imageBufferInfo
	move $a1, $v0
	jal highlight
	
	la $a0, errorBufferInfo	
	jal processError
	
	li $v0, 10		# exit
	syscall
	

##########################################################
# matchTemplate( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplate:
	sw $s0 0($sp)  # storing the save variables
	sw $s1 4($sp)
	sw $s2 8($sp)
	sw $s3 12($sp)
	sw $s5 16($sp)
	
	
	lw $s0 0($a0)  # load address of displayBuffer into $s0
	lw $s1 4($a0)  # load width of image (512) into $s1
	lw $s2 8($a0)  # load height of image (128) into $s2
	lw $s3 0($a1)  # load address of templateBuffer into $s3
	
	li $t0 0  # counter for LoopMatTemp1
	
	loopMatTemp1:
		
		subi $t1 $s2 8  # checks if height - 8 < y, exit if yes
		slt $t1 $t1 $t0
		li $t2 1
		beq $t1 $t2 exitLoopTemp1
		
		li $t1 0  # counter for LoopMatTemp2
		
		loopMatTemp2:
			
			subi $t2 $s1 8  # checks if width - 8 < x, exit if yes
			slt $t2 $t2 $t1
			li $t3 1
			beq $t2 $t3 exitLoopTemp2
			
			li $t2 0 # counter for LoopMatTemp3
			
			loopMatTemp3:
				
				li $t3 8  # checks if j < 8
				slt $t3 $t2 $t3
				beq $t3 $0 exitLoopTemp3
				
				li $t3 0 # counter for LoopMatTemp4
					
				loopMatTemp4:
				
					li $t4 8  # checks if i < 8
					slt $t4 $t3 $t4
					beq $t4 $0 exitLoopTemp4
					
					
					#1#
					add $t5 $t0 $t2  # t5 = y+j
					mul $t4 $s1 $t5  # t4 = width*(y+j)
					add $t4 $t4 $t1  # t4 = width*(y+j) + x
					add $t4 $t4 $t3  # t4 = width*(y+j) + (x+i)
					li $t5 4
					mul $t4 $t4 $t5  # t4 = 4*(width*(y+j) + (x+i))
					# gives us #
					add $t4 $s0 $t4  # t4 = displayBuffer + 4*(width*(y+j) + (x+i))
					
					lw $t4 0($t4)  # t4 = I[x+i][y+j]  (not and)
					andi $t4 $t4 0x000000FF  # t4 = I[x+i][y+j]
					
					
					#2#
					li $t5 8
					mul $t5 $t5 $t2  # t5 = 8*j
					add $t5 $t5 $t3  # t5 = 8*j + i
					li $t6 4
					mul $t5 $t5 $t6  # t5 = 4*(8*j + i)
					#gives us#
					add $t5 $t5 $s3  # t5 = templateBuffer + 4*(8*j + i)
					
					lw $t5 0($t5)  # t5 = T[i][j]  (not and)
					andi $t5 $t5 0x000000FF  # t5 = T[i][j]
					
					
					#3#
					sub $t4 $t4 $t5  # t4 = I[x+i][y+j] - T[i][j]
					slt $t5 $t4 $0
					beq $t5 $0 No  # if ( I[x+i][y+j] - T[i][j] < 0 ), then multiply by -1
					li $t5 -1
					mul $t4 $t4 $t5
					No:
					#  now t4 = | I[x+i][y+j] - T[i][j] |
					
					
					#4#
					lw $s5 0($a2)  # stores errorBuffer in s5
					mul $t5 $s1 $t0  # t5 = width*y
					add $t5 $t5 $t1  # t5 = width*y + x
					li $t6 4
					mul $t5 $t5 $t6  # t5 = 4*(width*y + x)
					#gives us#
					add $s5 $s5 $t5  # s5 = errorBuffer + 4*(width*y + x)
					
					
					#5#
					lw $t5 0($s5)  # t5 = SAD[x,y] (not and)
					add $t5 $t5 $t4  # t5 = SAD[x,y] + | I[x+i][y+j] - T[i][j] |
					
					
					#Finally gives us#
					sw $t5 0($s5)  # SAD[x,y] = SAD[x,y] + | I[x+i][y+j] - T[i][j] |
					
					
					addi $t3 $t3 1  # add 1 to the LoopMatTemp4 counter
					j loopMatTemp4
					exitLoopTemp4:
				
				addi $t2 $t2 1  # add 1 to the LoopMatTemp3 counter
				j loopMatTemp3
				exitLoopTemp3:
			
			addi $t1 $t1 1  # add 1 to the LoopMatTemp2 counter
			j loopMatTemp2
			exitLoopTemp2:
		
		addi $t0 $t0 1  # add 1 to the LoopMatTemp1 counter
		j loopMatTemp1
		exitLoopTemp1:
	
	
	
	lw $s0 0($sp)  # loading the save variables
	lw $s1 4($sp)
	lw $s2 8($sp)
	lw $s3 12($sp)
	lw $s5 16($sp)
	jr $ra	
	
##########################################################
# matchTemplateFast( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplateFast:
	sw $s0 0($sp)  # storing the save variables
	sw $s1 4($sp)
	sw $s2 8($sp)
	sw $s3 12($sp)
	sw $s4 16($sp)	
	sw $s5 20($sp)
	sw $s6 24($sp)
	sw $s7 28($sp)	
	
	
	lw $s0 0($a1)  # load address of templateBuffer into $s0
	lw $s1 0($a0)  # load address of displayBuffer into $s1
	lw $s2 4($a0)  # load width of image (512) into $s2
	lw $s3 8($a0)  # load height of image (128) into $s3
	lw $s4 0($a2)  # load address of errorBuffer in $a2
	
	
	li $t8 0  # 32*j=t8 is the counter for loopMatTempFast1
	sub $a2 $s4 $s1  # set a2 = errorBuffer - displayBuffer
	loopMatTempFast1:
	
		mul $a3 $t8 $s2
		li $t9 8
		div $a3 $a3 $t9  # a3 = 4*j*width
		
		# checks loop state #
		li $t9 256
		slt $t9 $t8 $t9
		beq $t9 $0 exitLoopMatTempFast1  # checks if j<8
		##
		
		
		move $t0 $t8  # t0 = counter
		addi $t1 $t0 4  # t1 = counter + 4
		addi $t2 $t0 8
		addi $t3 $t0 12
		addi $t4 $t0 16  # ...
		addi $t5 $t0 20
		addi $t6 $t0 24
		addi $t7 $t0 28  # t7 = counter + 28
			
		add $t0 $t0 $s0  # t0 = templateBuffer + counter
		add $t1 $t1 $s0  # t1 = templateBuffer + counter + 4
		add $t2 $t2 $s0
		add $t3 $t3 $s0
		add $t4 $t4 $s0
		add $t5 $t5 $s0
		add $t6 $t6 $s0
		add $t7 $t7 $s0  # t7 = templateBuffer + counter + 28
		
		lw $t0 0($t0)  # t0 = T[0][j]
		lw $t1 0($t1)  # t1 = T[1][j]
		lw $t2 0($t2)
		lw $t3 0($t3)
		lw $t4 0($t4)  # ...
		lw $t5 0($t5)
		lw $t6 0($t6)
		lw $t7 0($t7)  # t7 = T[7][j]
		
		andi $t0 $t0 0x000000FF  # t0 becomes and
		andi $t1 $t1 0x000000FF  # t1 becomes and
		andi $t2 $t2 0x000000FF
		andi $t3 $t3 0x000000FF
		andi $t4 $t4 0x000000FF  # ...
		andi $t5 $t5 0x000000FF
		andi $t6 $t6 0x000000FF
		andi $t7 $t7 0x000000FF  # t7 becomes and
		
		
		li $v1 0
		move $v0 $s1  # y=v0 is the counter for loopMatTempFast2 (starts at displayBuffer)
		loopMatTempFast2:
			
			# checks loop state #
			subi $t9 $s3 7
			mul $t9 $t9 $s2
			li $s6 4
			mul $t9 $t9 $s6
			add $t9 $t9 $s1  # t9 = displayBuffer + 4*width*height - 28*width
			slt $t9 $v0 $t9
			beq $t9 $0 exitLoopMatTempFast2  # checks if y < height-7
			##
			
			
			move $v1 $v0  # set counter for loopMatTempFast3 to v0
			
			li $t9 4
			mul $a1 $s2 $t9  # a1 = 4*width
			add $a1 $a1 $v1  # a1 = 4*width + v1
			add $s5 $v1 $a2  # s5 = errorBuffer + 4*width + v1
			subi $a1 $a1 28  # a1 = width*4*(y + 1) - 28
			loopMatTempFast3:
				
				# checks loop state #
				slt $t9 $v1 $a1
				beq $t9 $0 exitLoopMatTempFast3  # checks if x < width-7
				##
				
				add $v1 $v1 $a3  # adding to adjust the j coordinate
				
				lw $s4 0($s5)  # loads SAD[x,y] in s4
				
				
				#0.1#
				lw $s6 0($v1)  # s6 = I[x+0][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+0][y+j]
				##
				
				#0.2#
				sub $s6 $s6 $t0  # s6 = I[x+0][y+j] - t0
				slt $s7 $s6 $0
				beq $s7 $0 No0  # if ( I[x+0][y+j] - t0 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No0:
				#  now s6 = | I[x+0][y+j] - t0 |
				
				#0.3#
				add $s4 $s4 $s6  # s4 += | I[x+0][y+j] - t0 |
				##
				
				
				
				#1.1#
				lw $s6 4($v1)  # s6 = I[x+1][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+0][y+j]
				##
				
				#1.2#
				sub $s6 $s6 $t1  # s6 = I[x+1][y+j] - t1
				slt $s7 $s6 $0
				beq $s7 $0 No1  # if ( I[x+1][y+j] - t1 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No1:
				#  now s6 = | I[x+1][y+j] - t1 |
				
				#1.3#
				add $s4 $s4 $s6  # s4 += | I[x+1][y+j] - t1 |
				##
				
				
				
				#2.1#
				lw $s6 8($v1)  # s6 = I[x+2][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+2][y+j]
				##
				
				#2.2#
				sub $s6 $s6 $t2  # s6 = I[x+2][y+j] - t2
				slt $s7 $s6 $0
				beq $s7 $0 No2  # if ( I[x+2][y+j] - t2 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No2:
				#  now s6 = | I[x+2][y+j] - t2 |
				
				#2.3#
				add $s4 $s4 $s6  # s4 += | I[x+2][y+j] - t2 |
				##
				
				
				
				#3.1#
				lw $s6 12($v1)  # s6 = I[x+3][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+3][y+j]
				##
				
				#3.2#
				sub $s6 $s6 $t3  # s6 = I[x+3][y+j] - t3
				slt $s7 $s6 $0
				beq $s7 $0 No3  # if ( I[x+3][y+j] - t3 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No3:
				#  now s6 = | I[x+3][y+j] - t3 |
				
				#3.3#
				add $s4 $s4 $s6  # s4 += | I[x+3][y+j] - t3 |
				##
				
				
				
				#4.1#
				lw $s6 16($v1)  # s6 = I[x+4][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+4][y+j]
				##
				
				#4.2#
				sub $s6 $s6 $t4  # s6 = I[x+4][y+j] - t4
				slt $s7 $s6 $0
				beq $s7 $0 No4  # if ( I[x+4][y+j] - t4 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No4:
				#  now s6 = | I[x+4][y+j] - t4 |
				
				#4.3#
				add $s4 $s4 $s6  # s4 += | I[x+4][y+j] - t4 |
				##
				
				
				
				#5.1#
				lw $s6 20($v1)  # s6 = I[x+5][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+5][y+j]
				##
				
				#5.2#
				sub $s6 $s6 $t5  # s6 = I[x+5][y+j] - t5
				slt $s7 $s6 $0
				beq $s7 $0 No5  # if ( I[x+5][y+j] - t5 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No5:
				#  now s6 = | I[x+5][y+j] - t5 |
				
				#5.3#
				add $s4 $s4 $s6  # s4 += | I[x+5][y+j] - t5 |
				##
				
				
				
				#6.1#
				lw $s6 24($v1)  # s6 = I[x+6][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+6][y+j]
				##
				
				#6.2#
				sub $s6 $s6 $t6  # s6 = I[x+6][y+j] - t6
				slt $s7 $s6 $0
				beq $s7 $0 No6  # if ( I[x+6][y+j] - t6 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No6:
				#  now s6 = | I[x+6][y+j] - t6 |
				
				#6.3#
				add $s4 $s4 $s6  # s4 += | I[x+6][y+j] - t6 |
				##
				
				
				
				#7.1#
				lw $s6 28($v1)  # s6 = I[x+7][y+j]  (not and)
				andi $s6 $s6 0x000000FF  # s6 = I[x+7][y+j]
				##
				
				#7.2#
				sub $s6 $s6 $t7  # s6 = I[x+7][y+j] - t7
				slt $s7 $s6 $0
				beq $s7 $0 No7  # if ( I[x+7][y+j] - t7 < 0 ), then multiply by -1
				li $s7 -1
				mul $s6 $s6 $s7
				No7:
				#  now s6 = | I[x+7][y+j] - t7 |
				
				#7.3#
				add $s4 $s4 $s6  # s4 += | I[x+7][y+j] - t7 |
				##
				
				#Add everything in SAD[x,y]#
				sw $s4 0($s5)
				
				sub $v1 $v1 $a3  # removing to readjust j coordinate
				
				addi $v1 $v1 4
				addi $s5 $s5 4
				j loopMatTempFast3
				exitLoopMatTempFast3:
			
			li $t9 4
			mul $a1 $s2 $t9  # a1 = 4*width
			add $v0 $v0 $a1  # add 4*width to the counter y=v0
			j loopMatTempFast2
			exitLoopMatTempFast2:
		
		add $t8 $t8 32
		j loopMatTempFast1
		exitLoopMatTempFast1:
	
	
	lw $s0 0($sp)  # loading the save variables
	lw $s1 4($sp)
	lw $s2 8($sp)
	lw $s3 12($sp)
	lw $s4 16($sp)	
	lw $s5 20($sp)
	lw $s6 24($sp)
	lw $s7 28($sp)	
	jr $ra	
	
	
	
###############################################################
# loadImage( bufferInfo* imageBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
loadImage:	lw $a3, 0($a0)  # int* buffer
		lw $a1, 4($a0)  # int width
		lw $a2, 8($a0)  # int height
		lw $a0, 12($a0) # char* filename
		mul $t0, $a1, $a2 # words to read (width x height) in a2
		sll $t0, $t0, 2	  # multiply by 4 to get bytes to read
		li $a1, 0     # flags (0: read, 1: write)
		li $a2, 0     # mode (unused)
		li $v0, 13    # open file, $a0 is null-terminated string of file name
		syscall
		move $a0, $v0     # file descriptor (negative if error) as argument for read
  		move $a1, $a3     # address of buffer to which to write
		move $a2, $t0	  # number of bytes to read
		li  $v0, 14       # system call for read from file
		syscall           # read from file
		move $v0 $a0
        		# $v0 contains number of characters read (0 if end-of-file, negative if error).
        		# We'll assume that we do not need to be checking for errors!
		# Note, the bitmap display doesn't update properly on load, 
		# so let's go touch each memory address to refresh it!
		move $t0, $a3	   # start address
		add $t1, $a3, $a2  # end address
loadloop:	lw $t2, ($t0)
		sw $t2, ($t0)
		addi $t0, $t0, 4
		bne $t0, $t1, loadloop
		jr $ra
		
		
#####################################################
# (offset, score) = findBest( bufferInfo errorBuffer )
# Returns the address offset and score of the best match in the error Buffer
findBest:	lw $t0, 0($a0)     # load error buffer start address	
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		li $v0, 0		# address of best match	
		li $v1, 0xffffffff 	# score of best match	
		lw $a1, 4($a0)    # load width
        		addi $a1, $a1, -7 # initialize column count to 7 less than width to account for template
fbLoop:		lw $t9, 0($t0)        # score
		sltu $t8, $t9, $v1    # better than best so far?
		beq $t8, $zero, notBest
		move $v0, $t0
		move $v1, $t9
notBest:		addi $a1, $a1, -1
		bne $a1, $0, fbNotEOL # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
fbNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, fbLoop
		lw $t0, 0($a0)     # load error buffer start address	
		sub $v0, $v0, $t0  # return the offset rather than the address
		jr $ra
		

#####################################################
# highlight( bufferInfo imageBuffer, int offset )
# Applies green mask on all pixels in an 8x8 region
# starting at the provided addr.
highlight:	lw $t0, 0($a0)     # load image buffer start address
		add $a1, $a1, $t0  # add start address to offset
		lw $t0, 4($a0) 	# width
		sll $t0, $t0, 2	
		li $a2, 0xff00 	# highlight green
		li $t9, 8	# loop over rows
highlightLoop:	lw $t3, 0($a1)		# inner loop completely unrolled	
		and $t3, $t3, $a2
		sw $t3, 0($a1)
		lw $t3, 4($a1)
		and $t3, $t3, $a2
		sw $t3, 4($a1)
		lw $t3, 8($a1)
		and $t3, $t3, $a2
		sw $t3, 8($a1)
		lw $t3, 12($a1)
		and $t3, $t3, $a2
		sw $t3, 12($a1)
		lw $t3, 16($a1)
		and $t3, $t3, $a2
		sw $t3, 16($a1)
		lw $t3, 20($a1)
		and $t3, $t3, $a2
		sw $t3, 20($a1)
		lw $t3, 24($a1)
		and $t3, $t3, $a2
		sw $t3, 24($a1)
		lw $t3, 28($a1)
		and $t3, $t3, $a2
		sw $t3, 28($a1)
		add $a1, $a1, $t0	# increment address to next row	
		add $t9, $t9, -1		# decrement row count
		bne $t9, $zero, highlightLoop
		jr $ra

######################################################
# processError( bufferInfo error )
# Remaps scores in the entire error buffer. The best score, zero, 
# will be bright green (0xff), and errors bigger than 0x4000 will
# be black.  This is done by shifting the error by 5 bits, clamping
# anything bigger than 0xff and then subtracting this from 0xff.
processError:	lw $t0, 0($a0)     # load error buffer start address
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		lw $a1, 4($a0)     # load width as column counter
        		addi $a1, $a1, -7  # initialize column count to 7 less than width to account for template
pebLoop:		lw $v0, 0($t0)        # score
		srl $v0, $v0, 5       # reduce magnitude 
		slti $t2, $v0, 0x100  # clamp?
		bne  $t2, $zero, skipClamp
		li $v0, 0xff          # clamp!
skipClamp:	li $t2, 0xff	      # invert to make a score
		sub $v0, $t2, $v0
		sll $v0, $v0, 8       # shift it up into the green
		sw $v0, 0($t0)
		addi $a1, $a1, -1        # decrement column counter	
		bne $a1, $0, pebNotEOL   # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width to reset column counter
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
pebNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, pebLoop
		jr $ra
