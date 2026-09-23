default rel

section .data
    hw_path      db "/home/itsmazinheremob/itsmazinheremob/Documents/mempy/os_hooks/hardware", 0
    src_path     db "/home/itsmazinheremob/itsmazinheremob/Documents/mempy/compiler/script.mpy", 0
    
    msg_boot     db "[Mempy] Initializing Silicon-Direct Pipeline...", 10, 0
    msg_boot_len equ $ - msg_boot
    
    msg_hw       db "[Mempy Phase 1] Environment parsed dynamically.", 10, 0
    msg_hw_len   equ $ - msg_hw
    
    msg_done     db "[Mempy Phase 5] Output stitched. Compilation complete.", 10, 0
    msg_done_len equ $ - msg_done

    p1           db "! '", 0
    p2           db "' @ ; ", 0
    p3           db 10, 0
    m1           db 00010101b 

section .bss
    b1             resb 128
    os_id          resq 1
    num_cores      resq 1
    gpu_blocks     resq 1
    vector_width   resq 1
    sys_write_op   resq 1
    sys_exit_op    resq 1
    src_fd         resq 1
    thread_packets resb 256  
    
    src_buffer     resb 4096
    purified_tape  resb 4096
    global_dict    resq 512
    safety_table   resb 1024

section .text
    global _start
    global _mempy_compiler_pipeline
    global _mempy_core_stripper
    global _mempy_pass2_master_validator
    global _mempy_update_safety_state
    global _mempy_fast_blit

; =============================================================================
; GATEWAY ENTRY
; =============================================================================
_start:
    mov rbp, rsp
    and rsp, -16

    ; sys_write boot banner
    mov rax, 1              
    mov rdi, 1              
    lea rsi, [msg_boot]
    mov rdx, msg_boot_len
    syscall

    ; Invoke core compilation engine
    lea rsi, [src_buffer]
    lea rdi, [purified_tape]
    lea rdx, [global_dict]
    lea rcx, [safety_table]
    call _mempy_compiler_pipeline

    ; sys_write closure banner
    mov rax, [sys_write_op]
    cmp rax, 0
    jne .invoke_write
    mov rax, 1              
.invoke_write:
    mov rdi, 1              
    lea rsi, [msg_done]
    mov rdx, msg_done_len
    syscall

    ; sys_exit termination
    mov rax, [sys_exit_op]
    cmp rax, 0
    jne .invoke_exit
    mov rax, 60             
.invoke_exit:
    xor rdi, rdi            
    syscall

; =============================================================================
; UTILITY: BITFIELD SAFETY OVERWRITE ENGINE
; =============================================================================
; Inputs: rax = Variable ID Index (0-511)
;         sil = Target 2-bit access state to commit (01b=Write, 10b=Read)
; =============================================================================
_mempy_update_safety_state:
    mov r10, rax
    shr r10, 2              
    
    and rax, 00000011b      
    shl rax, 1              
    
    mov cl, al              
    
    mov r11b, 00000011b
    shl r11b, cl
    not r11b
    and [safety_table + r10], r11b 
    
    shl sil, cl
    or  [safety_table + r10], sil
    ret

; =============================================================================
; UTILITY: HIGH-SPEED TAPE COPY BLIT
; =============================================================================
; Inputs: rsi = Source pointer
;         rdi = Destination pointer
;         rdx = Total bytes count
; =============================================================================
_mempy_fast_blit:
    mov rcx, rdx
    shr rcx, 3              
    jz .u_blit_trailing     
.u_qword_loop:
    mov rax, [rsi]
    mov [rdi], rax
    add rsi, 8
    add rdi, 8
    dec rcx
    jnz .u_qword_loop
.u_blit_trailing:
    mov rcx, rdx
    and rcx, 00000111b      
    jz .u_blit_done
.u_byte_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .u_byte_loop
.u_blit_done:
    ret

; =============================================================================
; ORCHESTRATOR
; =============================================================================
_mempy_compiler_pipeline:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rsi    
    mov r13, rdi    
    mov r14, rdx    
    mov r15, rcx    

    ; Assign runtime target environment fallbacks
    mov qword [sys_write_op], 1
    mov qword [sys_exit_op], 60
    mov qword [num_cores], 1
    mov qword [vector_width], 1
    mov qword [os_id], 1
    mov qword [gpu_blocks], 0

    ; Ingest environment properties configuration sheet
    mov rax, 2              
    lea rdi, [hw_path]
    mov rsi, 0              
    syscall
    test rax, rax
    js .read_source_script  
    
    mov rdi, rax    
    mov rax, 0              
    lea rsi, [b1]   
    mov rdx, 512            
    syscall
    
    mov rax, 3              
    syscall

    ; Environmental dynamic parameter loop matrix
    lea rbx, [b1]           
    xor rcx, rcx            
.scan_hw_buffer:
    cmp rcx, 500
    jge .hw_parsing_complete
    mov al, [rbx + rcx]
    test al, al
    jz .hw_parsing_complete
    
    cmp al, 'O'
    je .match_os
    cmp al, 'N'
    je .match_cores
    cmp al, 'G'
    je .match_gpu
    cmp al, 'V'
    je .match_vector
    cmp al, 'W'
    je .match_write
    cmp al, 'E'
    je .match_exit
    
.continue_scan:
    inc rcx
    jmp .scan_hw_buffer

.match_os:
    cmp byte [rbx + rcx + 1], '='
    jne .continue_scan
    add rcx, 2
    call .parse_value
    mov [os_id], rax
    jmp .scan_hw_buffer

.match_cores:
    cmp byte [rbx + rcx + 1], '='
    jne .continue_scan
    add rcx, 2
    call .parse_value
    mov [num_cores], rax
    jmp .scan_hw_buffer

.match_gpu:
    cmp byte [rbx + rcx + 1], '='
    jne .continue_scan
    add rcx, 2
    call .parse_value
    mov [gpu_blocks], rax
    jmp .scan_hw_buffer

.match_vector:
    cmp byte [rbx + rcx + 1], '='
    jne .continue_scan
    add rcx, 2
    call .parse_value
    mov [vector_width], rax
    jmp .scan_hw_buffer

.match_write:
    cmp byte [rbx + rcx + 1], '='
    jne .continue_scan
    add rcx, 2
    call .parse_value
    mov [sys_write_op], rax
    jmp .scan_hw_buffer

.match_exit:
    cmp byte [rbx + rcx + 1], '='
    jne .continue_scan
    add rcx, 2
    call .parse_value
    mov [sys_exit_op], rax
    jmp .scan_hw_buffer

.parse_value:
    xor rax, rax            
    xor rbp, rbp            
.digit_loop:
    mov bpl, [rbx + rcx]
    cmp bpl, '0'
    jl .digits_done
    cmp bpl, '9'
    jg .digits_done
    sub bpl, '0'
    imul rax, rax, 10
    add rax, rbp
    inc rcx
    jmp .digit_loop
.digits_done:
    ret

.hw_parsing_complete:
.read_source_script:
    mov rax, [sys_write_op]
    mov rdi, 1
    lea rsi, [msg_hw]
    mov rdx, msg_hw_len
    syscall

    mov rax, 2              
    lea rdi, [src_path]
    mov rsi, 0              
    syscall
    test rax, rax
    js .pipeline_empty_exit 
    mov [src_fd], rax

    mov rax, 0              
    mov rdi, [src_fd]
    lea rsi, [src_buffer]
    mov rdx, 4096   
    syscall

    mov rax, 3              
    mov rdi, [src_fd]
    syscall

    lea rsi, [src_buffer]    
    lea rdi, [purified_tape] 
    lea rdx, [global_dict]   
    call _mempy_core_stripper
    
    mov r12, rax    
    test r12, r12
    jz .pipeline_empty_exit
    
    lea rsi, [global_dict]   
    mov rdx, r12    
    lea rcx, [safety_table]  
    mov r8,  [num_cores]   
    mov r9,  [vector_width] 
    call _mempy_pass2_master_validator

.pipeline_empty_exit:
    mov rax, r12
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; =============================================================================
; PHASE 1: TOKEN LEXER AND STRIPPER PURIFIER
; =============================================================================
_mempy_core_stripper:
    xor rcx, rcx            
    xor r8b, r8b            
    xor r9b, r9b            

.strip_loop:
    mov al, [rsi]
    test al, al
    jz .strip_done

    test r9b, r9b
    jnz .process_inside_comment

    cmp al, '/'
    jne .check_string_state
    cmp byte [rsi + 1], '*'
    jne .check_string_state
    mov r9b, 1              
    add rsi, 2              
    jmp .strip_loop

.process_inside_comment:
    cmp al, '*'
    jne .skip_comment_char
    cmp byte [rsi + 1], '/'
    jne .skip_comment_char
    xor r9b, r9b            
    add rsi, 2              
    jmp .strip_loop
.skip_comment_char:
    inc rsi
    jmp .strip_loop

.check_string_state:
    test r8b, r8b
    jnz .process_literal_string

    cmp al, '"'
    je .push_quote_stack
    cmp al, "'"
    je .push_quote_stack
    
    cmp al, 'a'
    jl .check_uppercase
    cmp al, 'z'
    jle .keep_token_char
.check_uppercase:
    cmp al, 'A'
    jl .check_digits
    cmp al, 'Z'
    jle .keep_token_char
.check_digits:
    cmp al, '0'
    jl .check_structural_symbols
    cmp al, '9'
    jle .keep_token_char
.check_structural_symbols:
    cmp al, ';'
    je .handle_statement_semicolon
    cmp al, '='
    je .keep_token_char
    cmp al, '('             
    je .keep_token_char
    cmp al, ')'             
    je .keep_token_char
    inc rsi
    jmp .strip_loop

.push_quote_stack:
    mov r8b, al             
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .strip_loop

.process_literal_string:
    mov [rdi], al
    cmp al, r8b             
    jne .continue_literal
    xor r8b, r8b            
.continue_literal:
    inc rsi
    inc rdi
    jmp .strip_loop

.handle_statement_semicolon:
    mov [rdx + rcx * 8], rdi 
    inc rcx
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .strip_loop

.keep_token_char:
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .strip_loop

.strip_done:
    mov byte [rdi], 0       
    mov rax, rcx            
    ret                     

; =============================================================================
; PHASE 2: MASTER VALIDATOR
; =============================================================================
_mempy_pass2_master_validator:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    test rdx, rdx
    jz .safety_pass_complete
    
    mov r12, rsi            
    mov r13, rdx            
    mov r14, rcx            
    xor r15, r15            
    xor r10, r10            

.statement_validation_loop:
    cmp r15, r13
    jge .initialize_sharding_layer
    mov rbx, [r12 + r15 * 8] 
    mov rbp, r15
    inc rbp
    cmp rbp, r13
    jl .calculate_exact_gap
    mov rbp, rbx
    
.find_eof_null:
    inc rbp
    cmp byte [rbp], 0
    jne .find_eof_null
    mov rcx, rbp
    sub rcx, rbx
    jmp .evaluate_statement_tokens
    
.calculate_exact_gap:
    mov rcx, [r12 + rbp * 8]
    sub rcx, rbx
    
.evaluate_statement_tokens:
    xor rbp, rbp            
    
.footprint_scan_loop:
    cmp rbp, rcx
    jge .step_next_statement
    mov al, [rbx + rbp]
    cmp al, '='
    jne .step_footprint_char

    push rcx
    push rsi
    
    mov rsi, rbx            
    xor r11, r11            
    test r10, r10           
    jz .register_new_variable
    
.search_existing_registry:
    lea rdi, [r14 + 512]    
    mov rax, r11
    shl rax, 3              
    add rdi, rax
    
    mov al, [rsi]
    cmp al, [rdi]
    jne .try_next_index
    
    push rsi
    push rdi
.scan_match_loop:
    mov al, [rsi]
    cmp al, '='                 
    je .check_reg_end
    cmp al, [rdi]               
    jne .scan_mismatch
    inc rsi
    inc rdi
    jmp .scan_match_loop

.check_reg_end:
    cmp byte [rdi], 0           
    je .scan_match_success

.scan_mismatch:
    pop rdi
    pop rsi
    jmp .try_next_index         

.scan_match_success:
    pop rdi
    pop rsi
    jmp .variable_index_resolved 

.try_next_index:
    inc r11
    cmp r11, r10
    jl .search_existing_registry

.register_new_variable:
    lea rdi, [r14 + 512]
    mov rax, r10
    shl rax, 3
    add rdi, rax
    
    mov al, [rsi]           
    mov [rdi], al           
    
    mov r11, r10            
    inc r10                 
    
.variable_index_resolved:
    pop rsi
    pop rcx

    mov rax, r11            
    
    mov r10, rax
    shr r10, 2
    mov dl, [r14 + r10]     
    mov r8, rax
    and r8, 00000011b
    shl r8, 1
    push rcx
    mov cl, r8b
    shr dl, cl
    pop rcx
    and dl, 00000011b
    cmp dl, 00000010b       
    je .memory_safety_violation_panic
    
    mov sil, 00000001b      
    call _mempy_update_safety_state
    
    jmp .step_footprint_char

.step_footprint_char:       
    inc rbp
    jmp .footprint_scan_loop
    
.step_next_statement:
    inc r15
    jmp .statement_validation_loop
    
.initialize_sharding_layer:
    mov rsi, r12                    
    mov rdx, r13                    
    mov rcx, r8                     
    lea r8,  [rel thread_packets]   
    call _mempy_sharding_scheduler
    
.safety_pass_complete:
    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret                     ; --- PHASE 2 OFFICIALLY ENDS HERE ---
    
.memory_safety_violation_panic:
    ud2                     

; =============================================================================
; STANDALONE STATIC VALIDATION AND AUXILIARY MATH UTILITIES
; =============================================================================
_mempy_verify_read:
    mov rcx, rax
    shr rcx, 2
    mov dl, [rsi + rcx]
    mov rcx, rax
    and rcx, 00000011b
    shl rcx, 1
    shr dl, cl
    and dl, 00000011b
    test dl, 00000001b
    jz .read_panic_trip
    ret
.read_panic_trip:
    ud2

_mempy_verify_write:
    mov rcx, rax
    shr rcx, 2
    mov dl, [rsi + rcx]
    mov rcx, rax
    and rcx, 00000011b
    shl rcx, 1
    shr dl, cl
    and dl, 00000011b
    test dl, 00000010b
    jnz .write_panic_trip
    ret
.write_panic_trip:
    ud2

_mempy_absolute_div:
    xor r8, r8
    test rbx, rbx
    jz .division_by_zero_trap
.math_waterfall_step:
    test rax, rax
    jz .math_complete
    cmp rax, rbx
    jb .math_complete
    bsr rcx, rax
    bsr rdx, rbx
    sub rcx, rdx
    mov rsi, rbx
    shl rsi, cl
    cmp rsi, rax
    seta r9b
    movzx r9, r9b
    sub rcx, r9
    shr rsi, cl
    shl rsi, cl
    mov rdi, 1
    shl rdi, cl
    or r8, rdi
    sub rax, rsi
    jmp .math_waterfall_step
.math_complete:
    mov rdx, rax
    mov rax, r8
    ret
.division_by_zero_trap:
    ud2

_mempy_fixed_point_sub:
    push rbp
    push rsi
    push rdi
    cmp rcx, rdx
    je .execute_raw_sub
    jl .scale_op_a
    sub rcx, rdx
    mov rdi, rdx
    mov rbp, 10
.scale_b_stride:
    imul rbx, rbp
    dec rcx
    jnz .scale_b_stride
    mov rdx, rdi
    jmp .execute_raw_sub
.scale_op_a:
    mov rsi, rdx
    sub rsi, rcx
    mov rbp, 10
.scale_a_stride:
    imul rax, rbp
    dec rsi
    jnz .scale_a_stride
    mov rcx, rdx
.execute_raw_sub:
    sub rax, rbx
    mov rdx, rcx
    pop rdi
    pop rsi
    pop rbp
    ret

; =============================================================================
; WORKER SCHEDULER
; =============================================================================
_mempy_sharding_scheduler:
    push rbx
    push rbp
    push r12
    push r13
    test rdx, rdx
    jz .sharding_empty_abort

    mov r14, rdx            
    mov rax, rdx            
    xor rdx, rdx            
    div rcx                 
    
    mov r9, rax             
    mov r10, rdx            
    xor r11, r11            
    xor rbx, rbx            

.build_thread_packet_loop:
    cmp rbx, rcx            
    jge .sharding_pipeline_finished
    
    mov rbp, [rsi + r11 * 8] 
    mov r12, r9             
    test r10, r10           
    jz .apply_thread_stride
    inc r12                 
    dec r10                 
    
.apply_thread_stride:
    add r11, r12            
    
    cmp r11, r14            
    jle .extract_terminal_ptr
    mov r11, r14
    
.extract_terminal_ptr:
    mov r13, r11
    dec r13                 
    mov r12, [rsi + r13 * 8] 
    
    mov r13, rax            
    shl rax, 5              
    shl r13, 3              
    add rax, r13            
    lea rdi, [r8 + rax]     

    mov [rdi],      rbx     
    mov [rdi + 8],  rbp     
    mov [rdi + 16], r12     
    mov qword [rdi + 24], 0 
    mov qword [rdi + 32], 0 
    
    inc rbx
    jmp .build_thread_packet_loop

.sharding_pipeline_finished:
.sharding_empty_abort:
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; =============================================================================
; PARSER: NESTED ARRAY SCANNER
; =============================================================================
_mempy_parse_nested_arrays:
    push rbx
    push rcx
    push rdx
    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
.array_scan_loop:
    mov dl, [rsi]
    test dl, dl
    jz .bracket_mismatch_fault
    cmp dl, '('             
    je .nested_brace_open
    cmp dl, ')'             
    je .nested_brace_close
    cmp dl, ';'
    je .nested_array_delimiter
    inc rsi
    jmp .array_scan_loop
.nested_brace_open:
    inc rbx
    cmp rbx, rax
    jle .continue_brace_scan
    mov rax, rbx
.continue_brace_scan:
    inc rsi
    jmp .array_scan_loop
.nested_brace_close:
    test rbx, rbx
    jz .bracket_mismatch_fault
    cmp byte [rsi + 1], ';'
    jne .bracket_mismatch_fault
    dec rbx
    add rsi, 2
    test rbx, rbx
    jz .nested_parsing_complete
    jmp .array_scan_loop
.nested_array_delimiter:
    inc rcx
    inc rsi
    jmp .nested_array_delimiter_loop
.nested_array_delimiter_loop:
    inc rcx
    inc rsi
    jmp .array_scan_loop
.nested_parsing_complete:
    pop rdx
    pop rcx
    pop rbx
    ret
.bracket_mismatch_fault:
    ud2

; =============================================================================
; CODEGEN: IF CONTROL STRUCTURE EMITTER
; =============================================================================
_mempy_codegen_if_block:
    push rbx
    push rbp
    mov byte [rdi], 0x48
    mov byte [rdi + 1], 0x85
    mov byte [rdi + 2], 0xC0
    add rdi, 3
    mov byte [rdi], 0x0F
    mov byte [rdi + 1], 0x84
    mov dword [rdi + 2], 0x00000000
    lea rbx, [rdi + 2]
    mov [rdx], rbx
    add rdx, 8
    add rdi, 6
    add rsi, 2
.inner_if_processing_loop:
    mov al, [rsi]
    test al, al
    jz .control_structure_fault
    cmp al, '}'
    je .resolve_if_backpatch
    inc rsi
    jmp .inner_if_processing_loop
.resolve_if_backpatch:
    cmp byte [rsi + 1], ';'
    jne .control_structure_fault
    sub rdx, 8
    mov rbx, [rdx]
    lea rbp, [rbx + 4]
    mov rax, rdi
    sub rax, rbp
    mov [rbx], eax
    add rsi, 2
    pop rbp
    pop rbx
    ret
.control_structure_fault:
    ud2

; =============================================================================
; CODEGEN: IMPLICIT ASSIGNMENT EMITTER
; =============================================================================
_mempy_codegen_implicit_assignment:
    push rbx
    push rbp
    mov rbx, [rdx]
    add qword [rdx], 8
    mov byte [rdi], 0x48
    mov byte [rdi + 1], 0x8B
    mov byte [rdi + 2], 0x06
    add rdi, 3
    mov byte [rdi], 0x48
    mov byte [rdi + 1], 0x89
    mov byte [rdi + 2], 0x07
    add rdi, 3
    mov rax, r9
    shr rax, 2
    mov bl, [rcx + rax]
    mov rbp, r9
    and rbp, 00000011b
    shl rbp, 1
    mov r10b, 00000011b
    push rcx
    mov cl, bpl
    shl r10b, cl
    not r10b
    and bl, r10b
    mov [rcx + rax], bl
    pop rcx
    mov rax, r8
    shr rax, 2
    mov bl, [rcx + rax]
    mov rbp, r8
    and rbp, 00000011b
    shl rbp, 1
    mov r10b, 00000011b
    push rcx
    mov cl, bpl
    shl r10b, cl
    not r10b
    and bl, r10b
    mov r10b, 00000001b
    shl r10b, cl
    or bl, r10b
    mov [rcx + rax], bl
    pop rcx
    pop rbp
    pop rbx
    ret

; =============================================================================
; PHASE 5: TAPE STITCH ENGINE
; =============================================================================
_mempy_phase5_perfect_stitch:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    xor rbx, rbx
    mov r12, rdx
    mov r15, rdi
    
.stitch_core_segment_loop:
    cmp rbx, r12
    jge .stitch_pipeline_sealed
    mov rax, rbx
    mov rbx, rax
    shl rax, 5              
    shl rbx, 3              
    add rax, rbx            
    lea rbp, [rsi + rax]
    mov r13, [rbp + 24]     
    mov r14, [rbp + 32]     
    
    mov rdx, r14
    sub rdx, r13            
    test rdx, rdx
    jle .advance_to_next_core
    
    mov rsi, r13            
    mov rdi, r15            
    call _mempy_fast_blit
    mov r15, rdi            
    
.advance_to_next_core:
    inc rbx
    jmp .stitch_core_segment_loop
    
.stitch_pipeline_sealed:
    mov byte [r15], 0       
    mov rax, r15
    sub rax, rdi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
