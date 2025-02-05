.text;
.p2align 2;
.global gemm_kernel_opt_loop_unrolling;
.type gemm_kernel_opt_loop_unrolling, %function;

#define     MAT_C               %rdi
#define     MAT_A               %rsi
#define     MAT_B               %r14
#define     DIM_M               %rcx
#define     DIM_N               %r8
#define     DIM_K               %r9
#define     loop_m              %r10
#define     loop_k              %r11
#define     loop_n              %r12
#define     mat_elem_idx        %r13


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

    xor loop_m, loop_m
    xor loop_k, loop_k
    xor loop_n, loop_n
.endm
.macro DO_GEMM
DO_LOOP_K:
    xor loop_m, loop_m

DO_LOOP_M:
    xor loop_n, loop_n

    mov loop_m, %rax
    mul DIM_K
    mov %rax, mat_elem_idx
    add loop_k, mat_elem_idx                    // Calculate m*K+k
    flds (MAT_A, mat_elem_idx, 4)     // Load A[m][k]

DO_LOOP_N:
    mov DIM_N, %rax
    mul loop_k
    mov %rax, mat_elem_idx
    add loop_n, mat_elem_idx
    flds (MAT_B, mat_elem_idx, 4)     // Load B[k][n]
    fmul %st(1), %st(0)                 // Calculate A[m][k] * B[k][n]  --> st(0)

    // Add logic to calculate A[m][k] * B[k][n+1] --> st(0)
    add $1, mat_elem_idx                // Move to B[k][n+1]
    flds (MAT_B, mat_elem_idx, 4)       // Load B[k][n+1]
    fmul %st(2), %st(0)                 // Calculate A[m][k] * B[k][n+1]  --> st(0)

    mov DIM_N, %rax
    mul loop_m
    mov %rax, mat_elem_idx
    add loop_n, mat_elem_idx                    // Calculate m*N+n

    // Add logic to load C[m][n] --> st(1) and C[m][n+1] --> st(0)
    flds (MAT_C, mat_elem_idx, 4)      // Load C[m][n] --> st(1)
    add $1, mat_elem_idx                // Move to C[m][n+1]
    flds (MAT_C, mat_elem_idx, 4)      // Load C[m][n+1] --> st(0)

    // Add partial sum accumulation logic: C[m][n+1] + A[m][k] * B[k][n+1] and C[m][n] + A[m][k] * B[k][n]
    faddp %st(2), %st(0)                // st(0) = C[m][n+1] + A[m][k] * B[k][n+1]
    faddp %st(2), %st(0)                // st(0) = C[m][n] + A[m][k] * B[k][n]

    // Save C[m][n+1] and C[m][n]
    fstps (MAT_C, mat_elem_idx, 4)      // Save C[m][n+1]
    sub $1, mat_elem_idx               // Move to C[m][n]
    fstps (MAT_C, mat_elem_idx, 4)      // Save C[m][n]

    // Update the loop control variable for dimension N
    add $2, loop_n                      // Increment by 2 each iteration
    cmp DIM_N, loop_n
    jl DO_LOOP_N

    fstp %st(0)                   // 仅弹出元素
    add $1, loop_m
    cmp DIM_M, loop_m
    jl DO_LOOP_M

    add $1, loop_k
    cmp DIM_K, loop_k
    jl DO_LOOP_K
.endm

gemm_kernel_opt_loop_unrolling:
    PUSHD
    GEMM_INIT
    DO_GEMM
    POPD
    ret