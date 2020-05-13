.model small

.data

cmd_size db ?

max_cmdl_size equ 127
cmdl db max_cmdl_size + 2 dup(0)
folder_path db max_cmdl_size + 2 dup(0)

;Disk Transfer Area
size_of_DTA_block equ 2Ch
DTA_block db size_of_DTA_block dup(0)

space equ ' '
new_line_symbol equ 13
car_return_symbol equ 10
tab equ 9
end_of_asciiz_str equ 0 
end_of_str equ '$'

end_of_program_7 db "Program was finished", '$'
file_is_not_founded db "file_is_not_founded ", '$'
folder_is_not_found db "Folder is not found", '$'
empty_cmdl db "Empty command line", '$'
new_line db 10,13,'$'

epb 	dw 0
			dw offset line,0
			dw 005Ch,0,006Ch,0		
line db 125
	 db " /?"
line_text db 122 dup(?)

extension db "*.exe", 0

data_size=$-cmd_size

.stack 100h
.code 
output_str macro str
    push ax
    push dx
        
    lea dx, str
    mov ah,9
    int 21h 
    
    lea dx, new_line
    mov ah, 9
    int 21h
    
    pop dx
    pop ax
endm


start:
    call  realocate_memory_block  
    
	mov ax, @data
	mov es, ax
	
    call read_cmdl
	mov ds, ax

	call get_folder_path 
	push si
    lea si, folder_path
    call str_len
    cmp ax,0
    je  emp
    pop si

	call find_folder
	jc exit
	
	call run_programs
    jc exit
    
emp:
	output_str empty_cmdl
exit:
	;exit
	;output_str end_of_program_7

	mov ah, 4Ch
	int 21h

realocate_memory_block proc
    mov ah, 4Ah
	mov bx, ((code_size/16)+1)+((data_size/16)+1)+32	
	int 21h
    ret
endp

find_folder proc
    mov ah, 3Bh
    lea dx,  folder_path
    int 21h 
    jnc folder_is_founded
    
    output_str folder_is_not_found
    
    folder_is_founded:
    ret
endp    

run_programs proc

	call find_first_file
	jnc run_exe_
	output_str file_is_not_founded
	jmp proc_out				
run_exe_:
	call run_exe
	cmp ax, 0
	jne exit				

run_next_files:
	call find_next_file
	cmp ax, 0
	jne exit				

	call run_exe
	cmp ax, 0
	jne exit				

jmp run_next_files
proc_out:
    ret	
run_programs endp	

read_cmdl proc
    push cx 
    push si
    push di
    
    xor cx, cx              ; 
	mov cl, ds:[80h]		; set len of command line
	mov bx, cx
	 		 
	mov si, 81h             ; set si in 81h because the first symbol always space
	lea di, cmdl            ; set di into begin of cmdl
	rep movsb 
        
    pop di
    pop si
    pop cx
    ret
read_cmdl endp

get_folder_path proc
	push ax
	push cx
	push di

	mov cl, cmd_size
	xor ch, ch

	lea si, cmdl
	inc si
	lea di, folder_path     
loop_get_path:
	mov al, ds:[si]
	cmp al, space;' '
	je delim_symbol

	cmp al, end_of_asciiz_str;0
	je delim_symbol

	mov es:[di], al

	inc di
	inc si

	loop loop_get_path

delim_symbol:
	mov al, end_of_asciiz_str;0
	mov es:[di], al
	inc si

	pop di
	pop cx
	pop ax
	ret
get_folder_path endp

str_len proc
	push bx 
	push si
	xor ax, ax

count_len:                  
     mov bl, ds:[si];          
	 cmp bl,  0            
	 je end_count_len             
	 inc si                
	 inc ax                                                                    
jmp count_len           
	                            ;
end_count_len:
	pop si
	pop bx
	ret
str_len endp

run_exe proc
	push bx
	push dx

	mov ax, 4B00h				
	mov bx, offset epb
	mov dx, offset DTA_block + 1Eh	;???????? ??? ????? ?? DTA
	int 21h
	
	jnc run_exe_good

	mov ax, 1

	jmp run_exe_out

run_exe_good:
	mov ax, 0

run_exe_out:
	pop dx
	pop  bx
	ret
run_exe endp


find_first_file proc
	mov ah,1Ah
    mov dx, offset DTA_block
    int 21h

    mov ah,4Eh
    xor cx,cx               		 
    lea dx, extension    
    int 21h
    
	ret
find_first_file endp

find_next_file proc
	mov ah,1Ah
    mov dx, offset DTA_block
    int 21h

	mov ah,4Fh
    mov dx, offset DTA_block       
    int 21h

	jnc find_next_file_good

	mov ax, 1

	jmp find_next_file_out

find_next_file_good:
	mov ax, 0

find_next_file_out:

	ret
find_next_file endp

code_size = $ - start

end start
