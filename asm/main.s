	.include "macros/function.inc"
	.include "constants/gba_constants.inc"
	.include "constants/gax3_constants.inc"
	.include "constants/syscall.inc"

	.syntax unified

	.set INTR_MAIN_BUFFER_SIZE, 0x9C
	.set GAX_WORK_RAM_SIZE, 0x1800

	.text

	thumb_func_start AgbMain
AgbMain:
	push {r4-r7,lr}
	@sub fp, sp, #Gax2Params_size
	sub sp, sp, #Gax2Params_size

	ldr r7, =REG_IE
	ldr r1, =0x4014
	strh r1, [r7, #OFFSET_REG_WAITCNT - OFFSET_REG_IE]

	adr r3, GaxtapperSignature
	movs r0, 0x80
	lsls r4, r0, 17
AgbMain_ReadSignature:
	ldr r0, [r3]
	cmp r0, r4
	ble AgbMain_Init
	adds r3, r3, 4
	b AgbMain_ReadSignature
	.align 2, 0
GaxtapperSignature:
	.asciz "Gaxtapper 0.01 \xa9 loveemu"
	.align 2, 0 @ Don't pad with nop.
	.size GaxtapperSignature, .-GaxtapperSignature

AgbMain_Init:
	mov r4, sp
	movs r0, r4
	bl gax2_new

	ldr r0, myGaxFlags
	strh r0, [r4, #o_Gax2Params_flags]
	ldr r0, myGaxMixingRate
	strh r0, [r4, #o_Gax2Params_mixing_rate]
	strh r0, [r4, #o_Gax2Params_fx_mixing_rate]
	ldr r0, myGaxVolume
	strh r0, [r4, #o_Gax2Params_volume]
	movs r0, #0
	strh r0, [r4, #o_Gax2Params_num_fx_channels]
	ldr r0, myGaxSfxPointer
	movs r3, #o_Gax2Params_sfx @ gaxtapper will replace the offset if necessary
	adds r3, r3, r4
	str r0, [r3]
	ldr r0, myGaxSongPointer
	adds r3, r3, #o_Gax2Params_music - o_Gax2Params_sfx
	str r0, [r3]
	ldr r0, =GAX_WORK_RAM_SIZE
	str r0, [r4, #o_Gax2Params_wram_size]
	ldr r0, =GaxWorkRam
	str r0, [r4, #o_Gax2Params_wram]
	movs r0, r4
	bl gax2_init

	bl InitIntrHandlers

AgbMain_Loop:
	svc 2
	b AgbMain_Loop
	.pool
	thumb_func_end AgbMain

	thumb_func_start InitIntrHandlers
InitIntrHandlers:
	push {r4,lr}

	@ Load interrupt handler to IWRAM
	ldr r4,=IntrMainBuffer
	ldr r3, =REG_DMA3
	ldr r0, =IntrMain
	str r0, [r3, #OFFSET_REG_DMA3SAD - OFFSET_REG_DMA3]
	str r4, [r3, #OFFSET_REG_DMA3DAD - OFFSET_REG_DMA3]
	ldr r1, =(DMA_ENABLE | DMA_START_NOW | DMA_32BIT | DMA_SRC_INC | DMA_DEST_INC) << 16 | (INTR_MAIN_BUFFER_SIZE / 4)
	str r1, [r3, #OFFSET_REG_DMA3CNT - OFFSET_REG_DMA3]
	ldr r0, [r3, #OFFSET_REG_DMA3CNT - OFFSET_REG_DMA3]

	ldr r0, =INTR_VECTOR
	str r4, [r0]

	ldr r2, =REG_BASE
	ldr r3, =REG_IE
	movs r1, #1
	strh r1, [r3, #OFFSET_REG_IME - OFFSET_REG_IE]
	strh r1, [r3, #OFFSET_REG_IE - OFFSET_REG_IE]
	movs r0, #8 @ DISPSTAT_VBLANK_INTR
	strh r0, [r2, #OFFSET_REG_DISPSTAT]
	pop {r4}
	pop {r0}
	bx r0
	.pool
	thumb_func_end InitIntrHandlers

	thumb_func_start IntrDummy
IntrDummy:
	bx lr
	.pool
	thumb_func_end IntrDummy

	thumb_func_start VBlankIntr
VBlankIntr:
	push {lr}
	bl gax_irq
	bl gax_play
	pop {r0}
	bx r0
	.pool
	thumb_func_end VBlankIntr

	thumb_func_start gax2_new
gax2_new:
	ldr r1, gax2_new_p
	bx r1
	.pool
	thumb_func_end gax2_new

	thumb_func_start gax2_init
gax2_init:
	ldr r1, gax2_init_p
	bx r1
	.pool
	thumb_func_end gax2_init

	thumb_func_start gax_irq
gax_irq:
	ldr r0, gax_irq_p
	bx r0
	.pool
	thumb_func_end gax_irq

	thumb_func_start gax_play
gax_play:
	ldr r0, gax_play_p
	bx r0
	.pool
	thumb_func_end gax_play

	.align 2, 0
gax2_new_p:
	.4byte IntrDummy @ overwritten by gaxtapper
gax2_init_p:
	.4byte IntrDummy @ overwritten by gaxtapper
gax_irq_p:
	.4byte IntrDummy @ overwritten by gaxtapper
gax_play_p:
	.4byte IntrDummy @ overwritten by gaxtapper

myGaxSfxPointer:
	.4byte 0

@ minigsf parameter block start
myGaxSongPointer:
	.4byte 0x8000000
myGaxFlags:
	.2byte 0 @ default (repeat forever)
	.align 2, 0
myGaxMixingRate:
	.2byte 0xFFFF @ default
	.align 2, 0
myGaxVolume:
	.2byte 0xFFFF @ default
	.align 2, 0

	.bss
IntrMainBuffer:
	.space INTR_MAIN_BUFFER_SIZE
	.size IntrMainBuffer, .-IntrMainBuffer

GaxWorkRam:
	.space GAX_WORK_RAM_SIZE
	.size GaxWorkRam, .-GaxWorkRam
