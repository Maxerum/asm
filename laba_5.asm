.model small

.stack 100h

.data   
     cmdl_size        db  ? 
     max_cmdl_size equ 127
     ;  size of command line
     cmdl              db  max_cmdl_size dup(0); whole command line
     file_path            db  max_cmdl_size + 2 dup(0) 
       

     readed_bytes dw 0000h
     processed_bytes_l dw 0000h 
     processed_bytes_h dw 0000h 
     size_of_string dw 0000h  
     size_of_word dw 0000h
       
   
     destination_path db "output.txt",0
;     
     source_handle dw 0
     dest_handle  dw 0  
;    
     buferr_size equ 200
     deleted_word db 50, 52 dup ('$')
     file_buffer db buferr_size dup ('$')  

     begin_buffer_flag db 0  
     
     empty_command_line db "Empty command line", '$'                
     open_error_str db "Open error", '$'
     rename_error_line db  "Rename error", '$'
     delete_error_line db "Delete error",'$' 
     not_all_parameters_line db "Not all parameters here",'$'
     new_line db 10,13,'$'

     space equ ' '
     new_line_symbol equ 13
     car_return_symbol equ 10
     tab equ 9
     end_of_asciiz_str equ 0 
     end_of_str equ '$'
          
.code         
   
   ; 
output_str macro
    push ax
    
    mov ah,9
    int 21h
    
    lea dx, new_line
    mov ah, 9
    int 21h
    
    pop ax    
endm

get_file_path proc   
    push ax 
    push cx
    push di
    xor ax,ax
    xor cx,cx
    
    mov cx, bx  
    
    lea si, cmdl          ; command line - source string 
    
    inc si
    lea di, file_path     ; file path - destination string
loop_get_path:    
    mov bl, ds:[si]
    cmp bl,space;' ' 
    je delim_symbol
    cmp bl, 0
    je delim_symbol
    
    
    mov es:[di],bl
    inc di
    inc si
loop loop_get_path    
    
delim_symbol:
     mov bl,0; symbol of end asciiz string
     mov es:[di],bl; mov at the of path zero 
     inc si
     
     pop di
     pop cx
     pop ax
     ret              
get_file_path endp      


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
 
get_word proc
    push ax 
    push cx
    push dx
   
    xor ax,ax
    xor cx,cx 
        
    mov cl,cmdl_size   
    
    ; command line - source string
    lea di,deleted_word      ; file path - destination string
loop_get_word:    
    mov bl, ds:[si]
    cmp bl,space;' ' 
    je delim_symbol_w                   
    
    cmp bl, 0
    je delim_symbol_w
    
    mov es:[di],bl
    inc di
    inc si
loop loop_get_word    
    
delim_symbol_w:
     mov bl,0; symbol of end asciiz string
     mov es:[di],bl
     inc si 
     
     pop dx
     pop cx                                  
     pop ax
                                           
     ret             
endp

open_file proc
    push cx 
    push dx
    
    mov ah,3Dh
    mov al,02h
    mov cl,0
    int 21h
    
    jnc file_opened
    
    lea dx, open_error_str
    output_str
    
    file_opened:
    
    pop dx 
    pop cx
    ret
open_file endp

create_and_open_file proc
    push dx
    
    mov ah, 3Ch ;creating destionation file
    xor cx,cx
    lea dx, destination_path
    int 21h
    
    jnc file_created_and_opened
    ;jb open_error
;    jc open_error
    
    mov ah,3Dh
    mov al,02h
    lea dx, destination_path
    int 21h
    ;mov ah,5Bh
;    mov cl,0
;    int 21h
    
    jnc file_created_and_opened
    
    lea dx, open_error_str
    output_str
    
    file_created_and_opened:
    
    pop dx
    ret
create_and_open_file endp

str_len proc
    push cx                   
	push bx                     
	push si                       
	xor ax, ax                 
	;lea si,word  ; set offset of word to si
count_len:                  
     mov bl, ds:[si];go while not zero          
	 cmp bl,  end_of_asciiz_str;0            
	 je end_count_len             
	 inc si                
	 inc ax                                                                    
jmp count_len           
	                            ;
end_count_len:
    mov size_of_word, ax                    ;
	pop si                      ;
	pop bx
	pop cx                      
	ret                         ;
str_len endp
           
read_from_file proc
    push bx
    push cx
    push dx
    
    call set_pointer_by_processed_bytes; mov pointer to read the next part of file
    
    mov bx, source_handle        ; a part of file to buffer  
    mov ah, 3Fh                  ;            
    mov cx, buferr_size;200                  ;max amount of bytes to read      
    lea dx, file_buffer   ; 
    int 21h   
    
    mov readed_bytes, ax ;amount of readed bytes
    
    pop dx
    pop cx
    pop bx
    ret
read_from_file endp

set_pointer_by_processed_bytes proc 
    pusha  
    mov bx, source_handle
    mov al, 00h; move pointer from begin  
    xor cx, cx                      ;the beginning of file  
    mov dx, processed_bytes_l         ;  
    mov cx, processed_bytes_h         ;  amount of bytes
    mov ah, 42h 
    int 21h 
    popa    
    ret
set_pointer_by_processed_bytes endp
                    
close_file proc
    pusha
    xor ax, ax      ; 
    mov ah, 3Eh     ; close file
    int 21h         ;     
    popa
    ret
close_file endp   


write_buffer proc 
    ;write cx bytes to destination file
    pusha
    lea dx, file_buffer      
    mov bx, dest_handle
    mov cx, ax
    mov ah, 40h   
    int 21h
          
    popa
    ret  
write_buffer endp                    
                    
add_processed_bytes proc 
    pusha
        mov dx, processed_bytes_l
        mov bx, processed_bytes_h         
        add dx, ax
        jae end_operations        
        inc bx 
               
end_operations:      
        mov processed_bytes_l, dx
        mov processed_bytes_h, bx
        popa
        ret
add_processed_bytes endp
                    
start:
    ;Read word from command line

    mov ax, @data
    mov es, ax
    call read_cmdl                         ;
	mov ds, ax   
	
	;check empty cmdl
	lea si, cmdl
    call str_len
    cmp ax,0
    je  emp
    
    ;output_str getting_file_path        
    call get_file_path
    push si
    lea si, file_path
    call str_len
    cmp ax,0
    je  emp
    pop si  
      
    ;output_str getting_word
    call get_word 
    push si
    lea si, deleted_word
    call str_len
    cmp ax,0
    je  not_all_parameters
    pop si
    
    lea dx, file_path     
    call open_file
    jc end_program               
	
	mov source_handle,ax
	
	lea dx,destination_path
	call create_and_open_file
	jc end_program
	
	mov dest_handle ,ax
	   
    xor dx, dx         
    lea si, deleted_word
    call str_len ;we know len of deleted word
   
process_files: 
    mov begin_buffer_flag, 0 ; flag for reading 
    
    call read_from_file;             
    
    mov ax, readed_bytes;    
    cmp ax, 0              
    je ending                ;if readed bytes equal to zero 
    
    mov dx, size_of_word; 
    ;inc dx
    
    cmp ax, dx ;compare amount of readed bytes and size of word
    jb write_small_part_of_word ;if smaller just write  part of buffer which smaller than size of word 
    
    lea si,file_buffer;set si to begin of file's buffer
    lea di,deleted_word;set di to begin of the deleted word
    
    sub al, dl; count amount of bytes without word's bytes  
                              
    mov cl, al; amount of bytes we should process  
    inc cx
find_the_word:
    pusha  
        ;check delimiters to find words
    cmp begin_buffer_flag, 0
    je str_cmp 
                
    cmp ds[si-1], space;' '
    je str_cmp 
        
    cmp ds[si-1], end_of_str;'$'
    je str_cmp                                                                                  
          
    cmp ds[si-1], car_return_symbol;0Dh
    je str_cmp   
        
    cmp ds[si-1], new_line_symbol;0Ah
    je str_cmp
        
    cmp ds[si-1], tab;09h
    je str_cmp

    cmp ds[si-1], end_of_asciiz_str;0h
    je str_cmp
       
    jmp next
         
str_cmp:        
    xor cx, cx 
    mov cx, dx   ; in dx size of word       
    repe cmpsb         
    jnz next      
    
check_first_space:
    
    mov bx,si
    sub  bx, size_of_word
    sub  bx,1
    
    cmp ds[bx], space;' '
    je check_second_space 
        
    cmp ds[bx], end_of_str;'$'
    je check_second_space                                                                               
          
    cmp ds[bx], car_return_symbol;0Dh
    je check_second_space  
        
    cmp ds[bx], new_line_symbol;0Ah
    je check_second_space  
    
    cmp ds[bx], end_of_asciiz_str;0h
    je check_second_space    
    
    cmp ds[bx], tab;09h
    je check_second_space

    
    
    jmp next
    
check_second_space:        
    cmp ds[si], space; ' ';space
    je is_find 
        
    cmp ds[si], end_of_str;'$' 
    je is_find
        
    cmp ds[si],car_return_symbol; 0Dh 
    je is_find
        
    cmp ds[si], new_line_symbol;0Ah
    je is_find
        
    cmp ds[si], tab;09h
    je is_find
       
    cmp ds[si],  end_of_asciiz_str;0h
    je is_find  
          
next:
        
     popa                  
        
     mov begin_buffer_flag, 0
                         
     inc si              ;next symbol of file buffer                                      
     lea di, deleted_word        ;set di to begin of te deleted word                                  
     loop find_the_word  ;            
      
     mov ax, readed_bytes
     call write_buffer
   
     mov ax, readed_bytes 
     ;add ax, size_of_word 
     call add_processed_bytes   
 
     jmp process_files                            
is_find:
        
     lea di, file_buffer; begin of file buffer to di 

     mov cx, si       ; end of finded qord to di      
      
     sub cx, offset file_buffer; get position in file buffer where word ended  
       
     xor ax, ax
     mov ax, size_of_word;
      
     sub cx, ax;return to begin of the word 
       
next_write_to_buffer:
       
     mov ax, cx  ; begin of the word
       
     call write_buffer 
     
     call add_processed_bytes;add proccesed bytes without finded word
      
     mov ax, size_of_word
     
     call add_processed_bytes ;add processed bytes after finded word, which we shouldn't to write
       
     jmp process_files                            
   
write_small_part_of_word:
     mov ax, readed_bytes
     
     call write_buffer 
     
     jmp ending  

;read_error:
;    lea dx ,read_error_line
;    output_str                
ending:
    
mov bx, dest_handle

call close_file 
                                    
mov bx, source_handle

call close_file
jc end_program

;lea dx ,close_files_str
;output_str  
;jmp end_program  

;delete file
    xor ax,ax 
    mov ah,41h
    lea dx, file_path
    int 21h                                              
    jc  delete_error
;renaming dest file
    mov ah,56h
    mov dx,offset destination_path
    mov di,offset file_path
    int 21h                
    jnc end_program
    jmp rename_error

not_all_parameters:
    lea dx,not_all_parameters_line
    output_str
    jmp end_program 
emp:     
    lea dx,empty_command_line
    output_str
    jmp end_program
rename_error:
    lea dx, rename_error_line    
    output_str
    jmp end_program
delete_error:
    lea dx,delete_error_line
    output_str    
end_program:
    mov ax,4c00h
    int 21h       
end start        