.text;
.p2align 2;
.global gemm_kernel_opt_avx;
.type gemm_kernel_opt_avx, %function;


#define     AVX_REG_BYTE_WIDTH  32

#define     MAT_C               %rdi
#define     MAT_A               %rsi
#define     MAT_B               %r13
#define     DIM_M               %rcx
#define     DIM_N               %r8
#define     DIM_K               %r9
#define     loop_m              %r10
#define     loop_k              %r11
#define     loop_n              %r12
#define     mat_elem_idx        %r14
#define     temp_reg            %r15

// 以下是计算过程中用到的avx寄存器
#define     mat_c0_0_8           %ymm0
#define     mat_c0_8_16          %ymm1
#define     mat_c0_16_24         %ymm2
#define     mat_c0_24_32         %ymm3
#define     mat_c1_0_8           %ymm4
#define     mat_c1_8_16          %ymm5
#define     mat_c1_16_24         %ymm6
#define     mat_c1_24_32         %ymm7
#define     mat_a0_0_8           %ymm8
#define     mat_a1_0_8           %ymm9
#define     mat_b0_0_8           %ymm10
#define     mat_b0_8_16          %ymm11
#define     mat_b0_16_24         %ymm12
#define     mat_b0_24_32         %ymm13

.macro PUSHD   // 保存原通用寄存器值
    push %rax
    push %rbx
    push %rcx
    push %rdx
    push %rsi
    push %rdi
    push %rbp
    push %r8
    push %r9
    push %r10
    push %r11
    push %r12
    push %r13
    push %r14
    push %r15
.endm

.macro POPD    // 恢复原通用寄存器值
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rbp
    pop %rdi
    pop %rsi
    pop %rdx
    pop %rcx
    pop %rbx
    pop %rax
.endm

.macro GEMM_INIT
    mov %rdx, MAT_B
.endm

.macro LOAD_MAT_A     // 每次装载矩阵A同一列的2个元素, 即A[m][k], A[m+1][k]
    // 装载A[m][k]的数据
    mov loop_m, %rax
    mul DIM_K
    mov %rax, temp_reg
    add loop_k, temp_reg

    // 计算A[m][k]的字节地址
    mov temp_reg, mat_elem_idx
    shl $2, mat_elem_idx        // 左移，相当于乘4

    vbroadcastss (MAT_A, mat_elem_idx), mat_a0_0_8    // 将A[m][k]广播到AVX寄存器的8个单元

    ;// TODO 练习3: 请添加加载并广播A[m+1][k]-->mat_a1_0_8的逻辑
    mov  temp_reg,mat_elem_idx
    add DIM_K ,mat_elem_idx
    shl $2 ,mat_elem_idx
    vbroadcastss (MAT_A, mat_elem_idx), mat_a1_0_8

.endm

.macro LOAD_MAT_B    // Load 32 elements from matrix B in one row, i.e., B[k][n:n+32]

    ;// TODO 练习3: 请添加加载B[k][n:n+32]-->mat_b0_0_8, mat_b0_8_16, mat_b0_16_24, mat_b0_24_32的逻辑
    mov loop_k, %rax
    mul DIM_N
    mov %rax, temp_reg
    add loop_n, temp_reg

    // Calculate the byte address of B[k][n]
    mov temp_reg, mat_elem_idx
    shl $2, mat_elem_idx        // Shift left, equivalent to multiplying by 4

    // Load B[k][n:n+8] into mat_b0_0_8
    vmovups (MAT_B, mat_elem_idx), mat_b0_0_8

    // Load B[k][n+8:n+16] into mat_b0_8_16
    add $32, mat_elem_idx       // Offset by 8 floats, i.e., 32 bytes
    vmovups (MAT_B, mat_elem_idx), mat_b0_8_16

    // Load B[k][n+16:n+24] into mat_b0_16_24
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups (MAT_B, mat_elem_idx), mat_b0_16_24

    // Load B[k][n+24:n+32] into mat_b0_24_32
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups (MAT_B, mat_elem_idx), mat_b0_24_32

.endm

.macro LOAD_MAT_C
    mov loop_m, %rax
    mul DIM_N
    mov %rax, temp_reg
    add loop_n, temp_reg

    // Load the first row of matrix C, i.e., C[m][n:n+32]
    mov temp_reg, mat_elem_idx
    shl $2, mat_elem_idx        // Shift left, equivalent to multiplying by 4

    // Load C[m][n:n+8] into mat_c0_0_8
    vmovups (MAT_C, mat_elem_idx), mat_c0_0_8

    // Load C[m][n+8:n+16] into mat_c0_8_16
    add $32, mat_elem_idx       // Offset by 8 floats, i.e., 32 bytes
    vmovups (MAT_C, mat_elem_idx), mat_c0_8_16

    // Load C[m][n+16:n+24] into mat_c0_16_24
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups (MAT_C, mat_elem_idx), mat_c0_16_24

    // Load C[m][n+24:n+32] into mat_c0_24_32
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups (MAT_C, mat_elem_idx), mat_c0_24_32

    // Load the second row of matrix C, i.e., C[m+1][n:n+32]
    mov temp_reg, mat_elem_idx
    add DIM_N, mat_elem_idx
    shl $2, mat_elem_idx        // Shift left, equivalent to multiplying by 4

    // Load C[m+1][n:n+8] into mat_c1_0_8
    vmovups (MAT_C, mat_elem_idx), mat_c1_0_8

    // Load C[m+1][n+8:n+16] into mat_c1_8_16
    add $32, mat_elem_idx       // Offset by 8 floats, i.e., 32 bytes
    vmovups (MAT_C, mat_elem_idx), mat_c1_8_16

    // Load C[m+1][n+16:n+24] into mat_c1_16_24
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups (MAT_C, mat_elem_idx), mat_c1_16_24

    // Load C[m+1][n+24:n+32] into mat_c1_24_32
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups (MAT_C, mat_elem_idx), mat_c1_24_32
.endm

.macro STORE_MAT_C
    // Save the first row of matrix C
    mov loop_m, %rax
    mul DIM_N
    mov %rax, temp_reg
    add loop_n, temp_reg

    // Save the first row of matrix C, i.e., C[m][n:n+32]
    mov temp_reg, mat_elem_idx
    shl $2, mat_elem_idx        // Shift left, equivalent to multiplying by 4

    // Save mat_c0_0_8 to C[m][n:n+8]
    vmovups mat_c0_0_8, (MAT_C, mat_elem_idx)

    // Save mat_c0_8_16 to C[m][n+8:n+16]
    add $32, mat_elem_idx       // Offset by 8 floats, i.e., 32 bytes
    vmovups mat_c0_8_16, (MAT_C, mat_elem_idx)

    // Save mat_c0_16_24 to C[m][n+16:n+24]
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups mat_c0_16_24, (MAT_C, mat_elem_idx)

    // Save mat_c0_24_32 to C[m][n+24:n+32]
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups mat_c0_24_32, (MAT_C, mat_elem_idx)

    // Save the second row of matrix C, i.e., C[m+1][n:n+32]
    mov temp_reg, mat_elem_idx
    add DIM_N, mat_elem_idx
    shl $2, mat_elem_idx        // Shift left, equivalent to multiplying by 4

    // Save mat_c1_0_8 to C[m+1][n:n+8]
    vmovups mat_c1_0_8, (MAT_C, mat_elem_idx)

    // Save mat_c1_8_16 to C[m+1][n+8:n+16]
    add $32, mat_elem_idx       // Offset by 8 floats, i.e., 32 bytes
    vmovups mat_c1_8_16, (MAT_C, mat_elem_idx)

    // Save mat_c1_16_24 to C[m+1][n+16:n+24]
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups mat_c1_16_24, (MAT_C, mat_elem_idx)

    // Save mat_c1_24_32 to C[m+1][n+24:n+32]
    add $32, mat_elem_idx       // Offset by another 32 bytes
    vmovups mat_c1_24_32, (MAT_C, mat_elem_idx)
.endm

.macro DO_COMPUTE      // Compute C[m:m+2][n:n+32] += A[m:m+2][k] * B[k:k+8][n:n+32]

    // Compute C[m][n:n+32] += A[m][k] * B[k][n:n+32]
    vfmadd231ps mat_a0_0_8, mat_b0_0_8, mat_c0_0_8
    vfmadd231ps mat_a0_0_8, mat_b0_8_16, mat_c0_8_16
    vfmadd231ps mat_a0_0_8, mat_b0_16_24, mat_c0_16_24
    vfmadd231ps mat_a0_0_8, mat_b0_24_32, mat_c0_24_32

    // Compute C[m+1][n:n+32] += A[m+1][k] * B[k][n:n+32]
    vfmadd231ps mat_a1_0_8, mat_b0_0_8, mat_c1_0_8
    vfmadd231ps mat_a1_0_8, mat_b0_8_16, mat_c1_8_16
    vfmadd231ps mat_a1_0_8, mat_b0_16_24, mat_c1_16_24
    vfmadd231ps mat_a1_0_8, mat_b0_24_32, mat_c1_24_32

.endm


.macro DO_GEMM
    xor loop_n, loop_n
DO_LOOP_N:

    xor loop_m, loop_m
DO_LOOP_M:
    // 装载矩阵C的数据
    LOAD_MAT_C

    xor loop_k, loop_k
DO_LOOP_K:
    // 装载矩阵A和矩阵B分块的数据
    LOAD_MAT_A
    LOAD_MAT_B

    DO_COMPUTE

    add $1, loop_k              // kr=1
    cmp DIM_K, loop_k
    jl DO_LOOP_K

    // 保存结果
    STORE_MAT_C

    add $2, loop_m              // mr=2
    cmp DIM_M, loop_m
    jl DO_LOOP_M

    add $32, loop_n             // nr=32
    cmp DIM_N, loop_n
    jl DO_LOOP_N

.endm



gemm_kernel_opt_avx:
    PUSHD
    GEMM_INIT
    DO_GEMM
    POPD
    ret