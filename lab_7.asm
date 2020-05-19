
.model small

.data
;.386
cmd_size db ?

max_cmdl_size equ 127
cmdl db max_cmdl_size + 2 dup(0)
folder_path db max_cmdl_size + 2 dup(0)

;Disk Transfer Area
size_of_DTA_block equ 2Ch;ther is required size of buffer
DTA_block db size_of_DTA_block dup(0)

curdisk  db "c:\"
curdir   db 64 dup(?)  
cur_drive db 64 dup(?) 
lol db ":\"
    
space equ ' '
new_line_symbol equ 13
car_return_symbol equ 10
tab equ 9
end_of_asciiz_str equ 0 
end_of_str equ '$'

memory_error_str db "Memory error", '$'
file_is_not_founded db "file_is_not_founded ", '$'
folder_is_not_found db "Folder is not found", '$'
empty_cmdl db "Empty command line", '$'
new_line db 10,13,'$'

epb 	dw 0
			dw offset new_cmdl,0 ;new command line
			dw 005Ch,0,006Ch,0; File BLock adresses 		
new_cmdl db 125
	 db " /?"
new_cmdl_text db 122 dup(?)

extension db "*.exe", 0

size_of_source_folder equ 64
source_folder db  size_of_source_folder dup(0),'$'
data_size = $-cmd_size

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
    jc memory_error
    
	mov ax, @data
	mov es, ax
	
    call read_cmdl
	mov ds, ax

	call get_folder_path 
	;check folder len
	push si
    lea si, folder_path
    call str_len
    cmp ax,0
    je  emp
    pop si
    
    call remember_current_folder
    jc exit
    
    output_str source_folder
    
	call find_folder
	jc exit
	
	call run_programs
    jc exit
    
    
     
    ;call return_directory
;    jc exit
    
emp:
	output_str empty_cmdl
	jmp exit
memory_error:
    output_str memory_error_str	
exit:
    ;mov ah, 3Bh
;    lea dx,  source_folder
;    int 21h  
    lea dx, cur_drive
    mov ah, 3Bh
    int 21h 
    
    lea dx, curdir
    mov ah, 3Bh
    int 21h            
    
    
    ;mov ah,47h
;    mov dl,00h
;    mov si, offset source_folder  
;    int 21h 
    
    ;output_str source_folder
    
	mov ah, 4Ch
	int 21h

realocate_memory_block proc
    mov ah, 4Ah ;free all memory after ending program and stack
	mov bx, ((code_size/16)+1)+((data_size/16)+1)+32	
	int 21h
    ret
endp

remember_current_folder proc
    push di
    mov ah,19h          
    int 21h 
    lea  di,cur_drive
rewrite_drive_name:
    add al,41h
    mov dl,al
    mov es:[di], dl
    mov al, ':'
    inc di
    mov es:[di], al 
    mov al, '\'  
    inc di
    mov es:[di], al

    mov ah,47h
    mov dl,00h
    mov si, offset curdir;source_folder  
    int 21h
    pop di     
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
find_folder endp    

run_programs proc
	call find_first_file
	jnc run_exe_
	output_str file_is_not_founded
	jmp proc_out				
run_exe_:
	call run_exe 
	;use ax to identificate errors
	cmp ax, 0
	jne exit				

run_next_files:
	call find_next_file
	;use ax to identificate errors
	cmp ax, 0
	jne exit				

	call run_exe 
	;use ax to identificate errors
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
	xor cx, cx

	lea si, cmdl
	inc si  ; skip one space in command line
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

	mov ah, 4Bh ;load program
	mov al, 00h	;number of function			
	lea bx,  epb; addres exec parameter block for loaded program
	mov dx, offset DTA_block + 1Eh;addres program name 	
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
    lea dx, DTA_block
    int 21h

    mov ah,4Eh ; find file, in begin we will use mask for finding file
    xor cx,cx               		 
    lea dx, extension; mask which used for finding exe-files   
    int 21h
    
	ret
find_first_file endp

find_next_file proc
	mov ah,1Ah       ;install DTA-block for finding file, usually it places in command line PSP 
    lea dx, DTA_block
    int 21h

	mov ah,4Fh ;find next file
    lea dx, DTA_block;dta contains data from previous call 4Eh or 4Fh        
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
