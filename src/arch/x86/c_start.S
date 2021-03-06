/*
 * This file is part of the coreboot project.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#include <cpu/x86/post_code.h>

/* Place the stack in the bss section. It's not necessary to define it in the
 * the linker script. */
	.section .bss, "aw", @nobits
.global _stack
.global _estack

.align CONFIG_STACK_SIZE
_stack:
.space CONFIG_MAX_CPUS*CONFIG_STACK_SIZE
_estack:
#if IS_ENABLED(CONFIG_COOP_MULTITASKING)
.global thread_stacks
thread_stacks:
.space CONFIG_STACK_SIZE*CONFIG_NUM_THREADS
#endif

	.section ".text._start", "ax", @progbits
#ifdef __x86_64__
	.code64
#else
	.code32
#endif
	.globl _start
_start:
	cli
	lgdt	%cs:gdtaddr
#ifndef __x86_64__
	ljmp	$0x10, $1f
#endif
1:	movl	$0x18, %eax
	movl	%eax, %ds
	movl	%eax, %es
	movl	%eax, %ss
	movl	%eax, %fs
	movl	%eax, %gs
#ifdef __x86_64__
	mov     $0x48, %ecx
	call    SetCodeSelector
#endif

	post_code(POST_ENTRY_C_START)		/* post 13 */

	cld

	/** poison the stack. Code should not count on the
	 * stack being full of zeros. This stack poisoning
	 * recently uncovered a bug in the broadcast SIPI
	 * code.
	 */
	leal	_stack, %edi
	movl	$_estack, %ecx
	subl	%edi, %ecx
	shrl	$2, %ecx   /* it is 32 bit aligned, right? */
	movl	$0xDEADBEEF, %eax
	rep
	stosl

	/* set new stack */
	movl	$_estack, %esp

#if IS_ENABLED(CONFIG_COOP_MULTITASKING)
	/* Push the thread pointer. */
	push	$0
#endif
	/* Push the CPU index and struct CPU */
	push	$0
	push	$0

	/*
	 *	Now we are finished. Memory is up, data is copied and
	 *	bss is cleared.   Now we call the main routine and
	 *	let it do the rest.
	 */
	post_code(POST_PRE_HARDWAREMAIN)	/* post fe */

	andl	$0xFFFFFFF0, %esp

#if IS_ENABLED(CONFIG_GDB_WAIT)
	call gdb_hw_init
	call gdb_stub_breakpoint
#endif
	call	main
	/* NOTREACHED */
.Lhlt:
	post_code(POST_DEAD_CODE)	/* post ee */
	hlt
	jmp	.Lhlt

#if IS_ENABLED(CONFIG_GDB_WAIT)

	.globl gdb_stub_breakpoint
gdb_stub_breakpoint:
#ifdef __x86_64__
	pop	%rax	/* Return address */
	pushfl
	push	%cs
	push	%rax	/* Return address */
	push	$0	/* No error code */
	push	$32	/* vector 32 is user defined */
#else
	popl	%eax	/* Return address */
	pushfl
	pushl	%cs
	pushl	%eax	/* Return address */
	pushl	$0	/* No error code */
	pushl	$32	/* vector 32 is user defined */
#endif
	jmp	int_hand
#endif

	.globl gdt, gdt_end

gdtaddr:
	.word	gdt_end - gdt - 1
#ifdef __x86_64__
	.quad	gdt
#else
	.long	gdt		/* we know the offset */
#endif

	 .data

	/* This is the gdt for GCC part of coreboot.
	 * It is different from the gdt in ROMCC/ASM part of coreboot
	 * which is defined in entry32.inc
	 *
	 * When the machine is initially started, we use a very simple
	 * gdt from ROM (that in entry32.inc) which only contains those
	 * entries we need for protected mode.
	 *
	 * When we're executing code from RAM, we want to do more complex
	 * stuff, like initializing PCI option ROMs in real mode, or doing
	 * a resume from a suspend to RAM.
	 */
gdt:
	/* selgdt 0, unused */
	.word	0x0000, 0x0000		/* dummy */
	.byte	0x00, 0x00, 0x00, 0x00

	/* selgdt 8, unused */
	.word	0x0000, 0x0000		/* dummy */
	.byte	0x00, 0x00, 0x00, 0x00

	/* selgdt 0x10, flat code segment */
	.word	0xffff, 0x0000
	.byte	0x00, 0x9b, 0xcf, 0x00 /* G=1 and 0x0f, So we get 4Gbytes for
					* limit
					*/

	/* selgdt 0x18, flat data segment */
	.word	0xffff, 0x0000
#ifdef __x86_64__
	.byte	0x00, 0x92, 0xcf, 0x00
#else
	.byte	0x00, 0x93, 0xcf, 0x00
#endif

	/* selgdt 0x20, unused */
	.word	0x0000, 0x0000		/* dummy */
	.byte	0x00, 0x00, 0x00, 0x00

	/* The next two entries are used for executing VGA option ROMs */

	/* selgdt 0x28 16 bit 64k code at 0x00000000 */
	.word   0xffff, 0x0000
	.byte   0, 0x9a, 0, 0

	/* selgdt 0x30 16 bit 64k data at 0x00000000 */
	.word   0xffff, 0x0000
	.byte   0, 0x92, 0, 0

	/* The next two entries are used for ACPI S3 RESUME */

	/* selgdt 0x38, flat data segment 16 bit */
	.word	0x0000, 0x0000		/* dummy */
	.byte	0x00, 0x93, 0x8f, 0x00 /* G=1 and 0x0f, So we get 4Gbytes for
					* limit
					*/

	/* selgdt 0x40, flat code segment 16 bit */
	.word	0xffff, 0x0000
	.byte	0x00, 0x9b, 0x8f, 0x00 /* G=1 and 0x0f, So we get 4Gbytes for
					* limit
					*/

#ifdef __x86_64__
	/* selgdt 0x48, flat x64 code segment */
	.word	0xffff, 0x0000
	.byte	0x00, 0x9b, 0xaf, 0x00
#endif
gdt_end:

	.section ".text._start", "ax", @progbits
#ifdef __x86_64__
SetCodeSelector:
	# save rsp because iret will align it to a 16 byte boundary
	mov	%rsp, %rdx

	# use iret to jump to a 64-bit offset in a new code segment
	# iret will pop cs:rip, flags, then ss:rsp
	mov	%ss, %ax	# need to push ss..
	push	%rax		# push ss instuction not valid in x64 mode,
				# so use ax
	push	%rsp
	pushfq
	push	%rcx		# cx is code segment selector from caller
	mov	$setCodeSelectorLongJump, %rax
	push	%rax

	# the iret will continue at next instruction, with the new cs value
	# loaded
	iretq

setCodeSelectorLongJump:
	# restore rsp, it might not have been 16-byte aligned on entry
	mov	%rdx, %rsp
	ret

	.previous
.code64
#else
	.previous
.code32
#endif
