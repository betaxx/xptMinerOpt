

.globl	compress256
.globl	compress384
.globl	compress512
.globl	loadstate256
.globl	loadstate512
.globl	storestate256
.globl	storestate512

.text


.macro TRANSFORM s0, t1, t2, table

	movdqa	\table, \t2
	movdqa	.k_s0F, \t1
	pandn	\s0, \t1
	psrld	$4, \t1
	pand	.k_s0F, \s0
	pshufb	\s0, \t2
	movdqa	\table + 16, \s0
	pshufb	\t1, \s0
	pxor	\t2, \s0

.endm


.macro TIX256 msg, s10, s8, s24, s0, t1, t2, t3

	pshufd	$0xf3, \s0, \t1
	#insertps $0x1d, \s0, \t1
	pxor	\t1, \s10
		
	movd	(\msg), \t1
	
	TRANSFORM \t1, \t2, \t3, .k_ipt

	#movss	\t1, \s0 
	pand	.maskd1, \s0
	pxor	\t1, \s0
	
	pslldq	$8, \t1
	#pshufd	$0xcf, \s0, \t1
	pxor	\t1, \s8

	pshufd	$0xf3, \s24, \t1
	pxor	\t1, \s0


.endm

.macro TIX384 msg, s16, s8, s27, s30, s0, s4, t1, t2, t3

	pshufd	$0xf3, \s0, \t1
	#insertps $0x1d, \s0, \t1
	pxor	\t1, \s16
		
	movd	(\msg), \t1
	
	TRANSFORM \t1, \t2, \t3, .k_ipt

	movdqa	\t1, \t2
	pslldq	$8, \t1
	#movss	\t2, \s0
	pand	.maskd1, \s0
	pxor	\t2, \s0
	pxor	\t1, \s8

	#movss	\t1, \s0 
	#pand	.maskd1, \s0
	#pxor	\t1, \s0
	
	pslldq	$8, \t1
	#pshufd	$0xcf, \s0, \t1
	pxor	\t1, \s8

	pshufd	$0xf3, \s27, \t1
	pxor	\t1, \s0

	pshufd	$0xf3, \s30, \t1
	pxor	\t1, \s4

.endm


.macro CMIX r1, r2, a, b, t1, t2

	#movdqa	\r1, \t1	# t1 = 0 S5 S4 S3
	#shufps	$0xc9, \r2, \t1	# t1 = 0 S6 S5 S4

	#pshufd	$0xf9, \r1, \t1
	#insertps $0x20, \r2, \t1
	
	pshufd	$0xf9, \r1, \t1
	pshufd	$0xcf, \r2, \t2
	pxor	\t2, \t1

	pxor	\t1, \a 	# add to columns 0,1,2
	pxor	\t1, \b 	# add to columns n/2, n/2+1, n/2+2
	
.endm

.macro PACK_S0 s0, s1, t1

	pshufd	$0x3f, \s1, \t1
	pxor	\t1, \s0

	# SSE4.1	
	#insertps $0x30, \s1, \s0

.endm

.macro UNPACK_S0 s0, s1, t1

	#pshufd	$0xff, \s0, \t1
	#movss	\t1, \s1
	
	insertps $0xc0, \s0, \s1
		
	pand	.maskd3n, \s0

.endm


.macro SUBSTITUTE s0, t1, t2, t3, t4

	movdqa  .k_s0F, \t1 	# 1 : i
	pandn	\s0, \t1 	# 1 = i<<4
	psrld	$4, \t1		# 1 = i
	pand	.k_s0F, \s0	# 0 = k
	movdqa	.k_inv + 16, \t2 # 2 : a/k
	pshufb  \s0, \t2 	# 2 = a/k
	pxor	\t1, \s0 	# 0 = j
	movdqa  .k_inv, \t3	# 3 : 1/i
	pshufb  \t1, \t3   	# 3 = 1/i
	pxor	\t2, \t3   	# 3 = iak = 1/i + a/k
	movdqa	.k_inv, \t4 	# 4 : 1/j
	pshufb	\s0, \t4   	# 4 = 1/j
	pxor	\t2, \t4   	# 4 = jak = 1/j + a/k
	movdqa  .k_inv, \t2	# 2 : 1/iak
	pshufb  \t3, \t2   	# 2 = 1/iak
	pxor	\s0, \t2  	# 2 = io
	movdqa  .k_inv, \t3	# 3 : 1/jak
	pshufb  \t4, \t3	# 3 = 1/jak
	pxor	\t1, \t3	# 3 = jo
	
.endm


.macro SUPERMIX3 r0, r1, r2, r3, r4

		movdqa  .k_sb1, \r4
		movdqa  .k_sb1 + 16, \r2
		pshufb  \r0, \r4
		pshufb  \r1, \r2
		pxor	\r4, \r2  # r2 = 1r

		movdqa  .k_sb2, \r4
		movdqa  .k_sb2 + 16, \r3
		pshufb  \r0, \r4
		pshufb  \r1, \r3
		pxor	\r4, \r3  # r3 = 2r

		movdqa  .k_sb4, \r4
		pshufb  \r0, \r4
		movdqa  .k_sb4 + 16, \r0
		pshufb  \r1, \r0
		pxor	\r4, \r0  # r0 = 4r

		# 1s		
		movdqa	\r2, \r1
		pshufb	.supermix1b, \r1
		movdqa	\r1, \r4
		pshufb	.supermix1c, \r1
		pxor	\r1, \r4
		movdqa	\r4, \r1
		pxor	.k_n, \r4
		pshufb	.supermix1d, \r1
		pxor	\r1, \r4
		
		movdqa	\r2, \r1
		pshufb	.supermix1a, \r1
		pxor	\r1, \r4
				
		# 7s
		pxor	\r3, \r2
		pxor	\r0, \r2
		pshufb	.supermix2a, \r3 # 2s

		
		# 4s
		movdqa	\r0, \r1
		pshufb	.supermix7a, \r2
		pxor	\r2, \r4
		pshufb	.supermix4a, \r1
		pxor	\r1, \r4
		pshufb	.supermix7b, \r2
		pxor	\r2, \r4
		pshufb	.supermix4b, \r0
		pxor	\r3, \r0 	# combine with 2s
		pxor	\r0, \r4
		pshufb	.supermix4c, \r0
		#pxor	.k_n, \r0
		pxor	\r0, \r4
.endm




.macro SUBROUND256 r1, r2, r0, r5
	
	CMIX \r1, \r2, \r0, \r5, %xmm0, %xmm1
	PACK_S0 \r0, \r1, %xmm0
	SUBSTITUTE \r0, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r0
	UNPACK_S0 \r0, \r1, %xmm3

.endm


.macro SUBROUND256_2  r1, r2, r0, r5, s1, s2, s0, s5
	
	CMIX \r1, \r2, \r0, \r5, %xmm0, %xmm1
	PACK_S0 \r0, \r1, %xmm0
	SUBSTITUTE \r0, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r0
	
	pshufd	$0x39, \r0, %xmm0 	# xmm0 = s0 s3 s2 s1
	pxor	%xmm0, \s0
	pand	.maskd3n, %xmm0
	pxor	%xmm0, \s5
	
	UNPACK_S0 \r0, \r1, %xmm3
	

	#CMIX s1, s2, s0, s5, xmm0, xmm1
	#PACK_S0 s0, s1, xmm0
	SUBSTITUTE \s0, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \s0
	UNPACK_S0 \s0, \s1, %xmm3

.endm



.align 16

compress256:


	pushq	%rdx

	movq	statebase, %rax
	cmp		$1, %rax
	jz		_start1
	cmp 	$2, %rax
	jz		_start2
	cmp 	$3, %rax
	jz		_start3
	cmp 	$4, %rax
	jz		_start4


_start0:

	TIX256 %rcx, %xmm9, %xmm8, %xmm14, %xmm6, %xmm0, %xmm1, %xmm2
	#SUBROUND256 %xmm6, %xmm7, %xmm15, %xmm10
	#SUBROUND256 %xmm15, %xmm6, %xmm14, %xmm9
	SUBROUND256_2 %xmm6, %xmm7, %xmm15, %xmm10, %xmm15, %xmm6, %xmm14, %xmm9


	inc		%rax
	add 	$4, %rcx
	dec 	%rdx	
	jz 		_done

_start1:

	TIX256 %rcx, %xmm7, %xmm6, %xmm12, %xmm14, %xmm0, %xmm1, %xmm2
	#SUBROUND256 %xmm14, %xmm15, %xmm13, %xmm8
	#SUBROUND256 %xmm13, %xmm14, %xmm12, %xmm7
	SUBROUND256_2 %xmm14, %xmm15, %xmm13, %xmm8, %xmm13, %xmm14, %xmm12, %xmm7

	inc		%rax
	add 	$4, %rcx
	dec 	%rdx	
	jz 		_done

_start2:

	TIX256 %rcx, %xmm15, %xmm14, %xmm10, %xmm12, %xmm0, %xmm1, %xmm2
	#SUBROUND256 %xmm12, %xmm13, %xmm11, %xmm6
	#SUBROUND256 %xmm11, %xmm12, %xmm10, %xmm15
	SUBROUND256_2 %xmm12, %xmm13, %xmm11, %xmm6, %xmm11, %xmm12, %xmm10, %xmm15

	inc		%rax
	add 	$4, %rcx
	dec 	%rdx	
	jz 		_done

_start3:

	TIX256 %rcx, %xmm13, %xmm12, %xmm8, %xmm10, %xmm0, %xmm1, %xmm2
	#SUBROUND256 %xmm10, %xmm11, %xmm9, %xmm14
	#SUBROUND256 %xmm9, %xmm10, %xmm8, %xmm13
	SUBROUND256_2 %xmm10, %xmm11, %xmm9, %xmm14, %xmm9, %xmm10, %xmm8, %xmm13

	inc		%rax
	add 	$4, %rcx
	dec 	%rdx	
	jz 		_done

_start4:

	TIX256 %rcx, %xmm11, %xmm10, %xmm6, %xmm8, %xmm0, %xmm1, %xmm2
	#SUBROUND256 %xmm8, %xmm9, %xmm7, %xmm12
	#SUBROUND256 %xmm7, %xmm8, %xmm6, %xmm11
	SUBROUND256_2 %xmm8, %xmm9, %xmm7, %xmm12, %xmm7, %xmm8, %xmm6, %xmm11
	
	xor		%rax, %rax
	add		$4, %rcx
	dec		%rdx
	jnz		_start0

_done:
	movq 	%rax, statebase

	popq	%rdx
	ret



.macro SUBROUND512_3 r1a, r1b, r1c, r1d, r2a, r2b, r2c, r2d, r3a, r3b, r3c, r3d

	CMIX \r1a, \r1b, \r1c, \r1d, %xmm0, %xmm1
	PACK_S0 \r1c, \r1a, %xmm0
	SUBSTITUTE \r1c, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r1c
	
	pshufd	$0x39, \r1c, %xmm0
	pxor	%xmm0, \r2c
	pand	.maskd3n, %xmm0
	pxor	%xmm0, \r2d
	
	UNPACK_S0 \r1c, \r1a, %xmm3

	#CMIX r2a, r2b, r2c, r2d, xmm0, xmm1
	#PACK_S0 r2c, r2a, xmm0
	SUBSTITUTE \r2c, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r2c

	pshufd	$0x39, \r2c, %xmm0
	pxor	%xmm0, \r3c
	pand	.maskd3n, %xmm0
	pxor	%xmm0, \r3d

	UNPACK_S0 \r2c, \r2a, %xmm3

	#CMIX r3a, r3b, r3c, r3d, xmm0, xmm1
	#PACK_S0 r3c, r3a, xmm0
	SUBSTITUTE \r3c, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r3c
	UNPACK_S0 \r3c, \r3a, %xmm3

.endm


.macro SUBROUND512 r1, r2, r0, r5
	
	CMIX \r1, \r2, \r0, \r5, %xmm0, %xmm1
	PACK_S0 \r0, \r1, %xmm0
	SUBSTITUTE \r0, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r0
	UNPACK_S0 \r0, \r1, %xmm3

.endm


.align 16

compress384:


	pushq	%rdx

	movq	statebase, %rax
	cmp		$1, %rax
	jz		_start384_1
	cmp 	$2, %rax
	jz		_start384_2
	cmp 	$3, %rax
	jz		_start384_3


_start384_0:
		
	TIX384 %rcx, %xmm9, %xmm6, %xmm13, %xmm14, %xmm4, %xmm5, %xmm0, %xmm1, %xmm2
	#SUBROUND512 %xmm4, %xmm5, %xmm15, %xmm9
	#SUBROUND512 %xmm15, %xmm4, %xmm14, %xmm8
	#SUBROUND512 %xmm14, %xmm15, %xmm13, %xmm7
	SUBROUND512_3 %xmm4, %xmm5, %xmm15, %xmm9, %xmm15, %xmm4, %xmm14, %xmm8, %xmm14, %xmm15, %xmm13, %xmm7
	
	inc %rax
	add $4, %rcx
	dec %rdx	
	jz _done384

_start384_1:

	TIX384 %rcx, %xmm6, %xmm15, %xmm10, %xmm11, %xmm13, %xmm14, %xmm0, %xmm1, %xmm2
	#SUBROUND512 %xmm13, %xmm14, %xmm12, %xmm6
	#SUBROUND512 %xmm12, %xmm13, %xmm11, %xmm5
	#SUBROUND512 %xmm11, %xmm12, %xmm10, %xmm4
	SUBROUND512_3 %xmm13, %xmm14, %xmm12, %xmm6, %xmm12, %xmm13, %xmm11, %xmm5, %xmm11, %xmm12, %xmm10, %xmm4

	inc %rax
	add $4, %rcx
	dec %rdx	
	jz _done384

_start384_2:

	TIX384 %rcx, %xmm15, %xmm12, %xmm7, %xmm8, %xmm10, %xmm11, %xmm0, %xmm1, %xmm2
	#SUBROUND512 %xmm10, %xmm11, %xmm9, %xmm15
	#SUBROUND512 %xmm9, %xmm10, %xmm8, %xmm14
	#SUBROUND512 %xmm8, %xmm9, %xmm7, %xmm13
	SUBROUND512_3 %xmm10, %xmm11, %xmm9, %xmm15, %xmm9, %xmm10, %xmm8, %xmm14, %xmm8, %xmm9, %xmm7, %xmm13

	inc %rax
	add $4, %rcx
	dec %rdx	
	jz _done384

_start384_3:

	TIX384 %rcx, %xmm12, %xmm9, %xmm4, %xmm5, %xmm7, %xmm8, %xmm0, %xmm1, %xmm2
	#SUBROUND512 %xmm7, %xmm8, %xmm6, %xmm12
	#SUBROUND512 %xmm6, %xmm7, %xmm5, %xmm11
	#SUBROUND512 %xmm5, %xmm6, %xmm4, %xmm10
	SUBROUND512_3 %xmm7, %xmm8, %xmm6, %xmm12, %xmm6, %xmm7, %xmm5, %xmm11, %xmm5, %xmm6, %xmm4, %xmm10

	xor	%rax, %rax	
	add $4, %rcx
	dec %rdx	
	jnz _start384_0
	
_done384:	

	movq 	%rax, statebase

	popq	%rdx
	ret


.macro TIX512 msg, s22, s8, s24, s27, s30, s0, s4, s7, t1, t2, t3

	pshufd	$0xf3, \s0, \t1
	pxor	\t1, \s22
	
	movd	(\msg), \t1
	
	TRANSFORM \t1, \t2, \t3, .k_ipt
	
	movdqa	\t1, \t2
	pslldq	$8, \t1 
	#movss	\t2, \s0 
	pand .maskd1, \s0
	pxor	\t2, \s0
	pxor	\t1, \s8
	
	pshufd	$0xf3, \s24, \t1
	pxor	\t1, \s0

	pshufd	$0xf3, \s27, \t1
	pxor	\t1, \s4

	pshufd	$0xf3, \s30, \t1
	pxor	\t1, \s7

.endm

.macro SUBROUND512_4 r1a, r1b, r1c, r1d, r2a, r2b, r2c, r2d, r3a, r3b, r3c, r3d, r4a, r4b, r4c, r4d

	CMIX \r1a, \r1b, \r1c, \r1d, %xmm0, %xmm1
	PACK_S0 \r1c, \r1a, %xmm0
	SUBSTITUTE \r1c, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r1c
	
	pshufd	$0x39, \r1c, %xmm0
	pxor	%xmm0, \r2c
	pand	.maskd3n, %xmm0
	pxor	%xmm0, \r2d
	
	UNPACK_S0 \r1c, \r1a, %xmm3

	SUBSTITUTE \r2c, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r2c

	pshufd	$0x39, \r2c, %xmm0
	pxor	%xmm0, \r3c
	pand	.maskd3n, %xmm0
	pxor	%xmm0, \r3d

	UNPACK_S0 \r2c, \r2a, %xmm3

	SUBSTITUTE \r3c, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r3c
	
	pshufd	$0x39, \r3c, %xmm0
	pxor	%xmm0, \r4c
	pand	.maskd3n, %xmm0
	pxor	%xmm0, \r4d
	
	UNPACK_S0 \r3c, \r3a, %xmm3

	SUBSTITUTE \r4c, %xmm1, %xmm2, %xmm3, %xmm0
	SUPERMIX3 %xmm2, %xmm3, %xmm0, %xmm1, \r4c
	UNPACK_S0 \r4c, \r4a, %xmm3

.endm


compress512:
	
	pushq %rdx
	
	movq statebase, %rax
	cmp	$1, %rax
	jz	_start512_1
	cmp $2, %rax
	jz	_start512_2
	
_start512_0:
	
	TIX512 %rcx, %xmm11, %xmm6, %xmm12, %xmm13, %xmm14, %xmm4, %xmm5, %xmm6, %xmm0, %xmm1, %xmm2
	#SUBROUND512 %xmm4, %xmm5, %xmm15, %xmm9
	#SUBROUND512 %xmm15, %xmm4, %xmm14, %xmm8
	#SUBROUND512 %xmm14, %xmm15, %xmm13, %xmm7
	#SUBROUND512 %xmm13, %xmm14, %xmm12, %xmm6
	SUBROUND512_4 %xmm4, %xmm5, %xmm15, %xmm9, %xmm15, %xmm4, %xmm14, %xmm8, %xmm14, %xmm15, %xmm13, %xmm7, %xmm13, %xmm14, %xmm12, %xmm6
	
	inc %rax
	add $4, %rcx
	dec %rdx	
	jz _done512

_start512_1:

	TIX512 %rcx, %xmm7, %xmm14, %xmm8, %xmm9, %xmm10, %xmm12, %xmm13, %xmm14, %xmm0, %xmm1, %xmm2
	#SUBROUND512 %xmm12, %xmm13, %xmm11, %xmm5
	#SUBROUND512 %xmm11, %xmm12, %xmm10, %xmm4
	#SUBROUND512 %xmm10, %xmm11, %xmm9, %xmm15
	#SUBROUND512 %xmm9, %xmm10, %xmm8, %xmm14
	SUBROUND512_4 %xmm12, %xmm13, %xmm11, %xmm5, %xmm11, %xmm12, %xmm10, %xmm4, %xmm10, %xmm11, %xmm9, %xmm15, %xmm9, %xmm10, %xmm8, %xmm14

	inc %rax
	add $4, %rcx
	dec %rdx	
	jz _done512


_start512_2:

	TIX512 %rcx, %xmm15, %xmm10, %xmm4, %xmm5, %xmm6, %xmm8, %xmm9, %xmm10, %xmm0, %xmm1, %xmm2
	#SUBROUND512 %xmm8, %xmm9, %xmm7, %xmm13
	#SUBROUND512 %xmm7, %xmm8, %xmm6, %xmm12
	#SUBROUND512 %xmm6, %xmm7, %xmm5, %xmm11
	#SUBROUND512 %xmm5, %xmm6, %xmm4, %xmm10
	SUBROUND512_4 %xmm8, %xmm9, %xmm7, %xmm13, %xmm7, %xmm8, %xmm6, %xmm12, %xmm6, %xmm7, %xmm5, %xmm11, %xmm5, %xmm6, %xmm4, %xmm10

	xor %rax, %rax
	add $4, %rcx
	dec %rdx	
	jnz _start512_0
	
_done512:	
	
	movq %rax, statebase
	
	popq %rdx
	ret


	.align 16
.fugue_consts:
	# s0F
	.k_s0F = .
	.quad	0x0F0F0F0F0F0F0F0F
	.quad	0x0F0F0F0F0F0F0F0F

	# input transform (lo, hi)
	.k_ipt = .
	.quad	0xC2B2E8985A2A7000
	.quad	0xCABAE09052227808
	.quad	0x4C01307D317C4D00
	.quad	0xCD80B1FCB0FDCC81

	# inv, inva
	.k_inv = .
	.quad	0x0E05060F0D080180
	.quad	0x040703090A0B0C02
	.quad	0x01040A060F0B0780
	.quad	0x030D0E0C02050809

	# output transform
	.k_opt = .
	.quad	0xFF9F4929D6B66000
	.quad	0xF7974121DEBE6808
	.quad	0x01EDBD5150BCEC00
	.quad	0xE10D5DB1B05C0CE0

	.k_n = .
	.quad	0x4E4E4E4E4E4E4E4E
	.quad	0x1B1B1B1B0E0E0E0E

	.k_sb1 = .
	.quad	0xB19BE18FCB503E00
	.quad	0xA5DF7A6E142AF544
	.quad	0x3618D415FAE22300
	.quad	0x3BF7CCC10D2ED9EF

	.k_sb2 = .
	.quad 	0xE27A93C60B712400
	.quad	0x5EB7E955BC982FCD
	.quad	0x69EB88400AE12900
	.quad	0xC2A163C8AB82234A

	.k_sb4 = .
	.quad	0xE1E937A03FD64100
	.quad	0xA876DE9749087E9F
	.quad	0x3D50AED7C393EA00
	.quad	0xBA44FE79876D2914

	.supermix1a = .
	.quad 	0x0202010807020100
	.quad	0x0a05000f06010c0b

	.supermix1b = .
	.quad 	0x0b0d080703060504
	.quad	0x0e0a090c050e0f0a

	.supermix1c = .
	.quad 	0x0402060c070d0003
	.quad 	0x090a060580808080

	.supermix1d = .
	.quad 	0x808080800f0e0d0c
	.quad	0x0f0e0d0c80808080

	.supermix2a = .
	.quad 	0x07020d0880808080
	.quad	0x0b06010c050e0f0a
	
	.supermix4a = .
	.quad 	0x000f0a050c0b0601
	.quad	0x0302020404030e09
	
	.supermix4b = .
	.quad 	0x07020d08080e0d0d 
	.quad	0x07070908050e0f0a
	
	.supermix4c = .
	.quad 	0x0706050403020000 
	.quad	0x0302000007060504
	
	.supermix7a = .
	.quad 	0x010c0b060d080702 
	.quad	0x0904030e03000104
	
	.supermix7b = .
	.quad 	0x8080808080808080 
	.quad	0x0504070605040f06

	.maskd3n = .
	.quad	0xffffffffffffffff
	.quad	0x00000000ffffffff
	
	.maskd1 = .
	.quad	0xffffffff00000000
	.quad	0xffffffffffffffff

	#.statebase = .
	#statebase:
	#.quad	0


.macro LOAD_TRANSFORM  state, r, t1, t2

	pxor	\r, \r
	
	## requires SSE4.1
	#pinsrd	r, dword ptr [state + 0], 0
	#pinsrd	r, dword ptr [state + 4], 1
	#pinsrd	r, dword ptr [state + 8], 2

	## reads one more extra dword than necessary
	#movups	r, xmmword ptr [state]
	#pand	r, xmmword ptr maskd3n
	
	movss	8(\state), \t1
	movss	\t1, \r
	pslldq	$4, \r
	movss	4(\state), \t1
	movss	\t1, \r
	pslldq	$4, \r
	movss	(\state), \t1
	movss	\t1, \r

	TRANSFORM  \r, \t1, \t2, .k_ipt

.endm

.macro STORE_TRANSFORM  state, r, t1, t2

	TRANSFORM  \r, \t1, \t2, .k_opt

	## requires SSE4.1
	#pextrd	dword ptr [state + 0], r, 0
	#pextrd	dword ptr [state + 4], r, 1
	#pextrd	dword ptr [state + 8], r, 2

	movss 	\r, (\state) 
	psrldq	$4, \r
	movss 	\r, 4(\state) 
	psrldq	$4, \r
	movss 	\r, 8(\state) 

.endm

loadstate512:

	LOAD_TRANSFORM %rcx, %xmm4, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm5, %xmm0, %xmm1
	add $12, %rcx

loadstate256:

	LOAD_TRANSFORM %rcx, %xmm6, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm7, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm8, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm9, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm10, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm11, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm12, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm13, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm14, %xmm0, %xmm1
	add $12, %rcx
	LOAD_TRANSFORM %rcx, %xmm15, %xmm0, %xmm1
	
	movq $0, statebase

	ret


storestate512:

	STORE_TRANSFORM %rcx, %xmm4, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm5, %xmm0, %xmm1
	add $12, %rcx

storestate256:
	
	STORE_TRANSFORM %rcx, %xmm6, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm7, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm8, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm9, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm10, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm11, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm12, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm13, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm14, %xmm0, %xmm1
	add $12, %rcx
	STORE_TRANSFORM %rcx, %xmm15, %xmm0, %xmm1

	ret


.bss
	statebase:
	.quad	

