; *******************************************************************
; *** This software is copyright 2005 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include    bios.inc
include    kernel.inc


           org     8000h
           lbr     0ff00h
           db      'shell',0
           dw      9000h
           dw      endrom+2000h
           dw      7000h
           dw      endrom-7000h
           dw      7000h
           db      0

           org     7000h
           br      start

include    date.inc

chkvalue:  equ     01ffeh
wrmvalue:  equ     01ffch
stkvalue:  equ     01ffah

start:     ldi     high stub           ; copy stub code into kernel space
           phi     rf
           ldi     low stub
           plo     rf
           ldi     01fh                ; where to copy
           phi     rd 
           ldi     0
           plo     rd
           ldi     0                   ; copy 256 bytes
           plo     rc
mncopy:    lda     rf                  ; get byte from stub
           str     rd                  ; store into destination
           inc     rd
           dec     rc                  ; decrement count
           glo     rc                  ; see if done
           lbnz    mncopy              ; jump if not
           sep     scall               ; get checksum
           dw      chksum
           plo     re                  ; set aside
           ldi     high chkvalue       ; storage space
           phi     rf
           ldi     low chkvalue
           plo     rf
           glo     re                  ; get the checksum
           str     rf                  ; and save it
           dec     rf                  ; point to storage for wrmboot vector
           dec     rf
           ldi     high (o_wrmboot+1)  ; need to get warmboot vector
           phi     rd
           ldi     low (o_wrmboot+1)
           plo     rd
           lda     rd                  ; get high byte
           str     rf                  ; and place into storage
           inc     rf
           ldn     rd                  ; get low byte
           str     rf                  ; and store
           ldi     low (stub_wrm-05f00h)
           str     rd                  ; store stub warm boot address
           dec     rd
           ldi     high (stub_wrm-05f00h)
           str     rd
           sep     scall               ; display startup
           dw      f_inmsg
           db      10,13,'Elf/OS Shell V0.3',10,13,0
main:      sep     scall               ; display prompt
           dw      f_inmsg
           db      10,13,'$ ',0
           sep     scall               ; get input buffer address
           dw      setbuf
           sep     scall               ; get user input
           dw      o_input
           lbdf    quit                ; exit shell if ^C pressed
           sep     scall               ; display a cr/lf
           dw      docrlf
           sep     scall               ; check for DIR command
           dw      check
           db      'ls',0
           lbdf    cmd_dir             ; jump if directory command
           sep     scall               ; check for CD command
           dw      check
           db      'cd',0
           lbdf    cmd_cd              ; jump if cd command
           sep     scall               ; check for MD command
           dw      check
           db      'md',0
           lbdf    cmd_md              ; jump if md command
	   sep     scall               ; check for CP command
	   dw      check
	   db      'cp',0
	   lbdf    cmd_cp              ; jump if cp command
	   sep     scall               ; check for CAT command
	   dw      check
	   db      'cat',0
	   lbdf    cmd_cat             ; jump if cat command
	   sep     scall               ; check for RM command
	   dw      check
	   db      'rm',0
	   lbdf    cmd_rm              ; jump if rm command
	   sep     scall               ; check for RN command
	   dw      check
	   db      'rn',0
	   lbdf    cmd_rn              ; jump if rn command
	   sep     scall               ; check for RD command
	   dw      check
	   db      'rd',0
	   lbdf    cmd_rd              ; jump if rd command

    lbr    1f00h                       ; execute from stub code

           sep     scall               ; get input buffer address
           dw      setbuf
           sep     scall               ; attempt to exec external command
           dw      o_exec
           lbnf    main

           sep     scall               ; get input buffer address
           dw      setbuf
           sep     scall               ; attempt to exec from /bin
           dw      o_execbin
           lbnf    main

error:     ldi     high cmderr         ; indicate command error
           phi     rf
           ldi     low cmderr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           lbr     main                ; back to main loop

quit:      lbr     wrm_rest            ; return to Elf/OS shell

cmd_dir:   sep     scall               ; display directory
           dw      dir
           lbr     main                ; then back to main loop

cmd_cd:    sep     scall               ; change directory
           dw      cd
           lbr     main                ; then back to main loop

cmd_md:    sep     scall               ; made directory
           dw      md
           lbr     main                ; then back to main loop

cmd_cp:    sep     scall               ; copy file
           dw      cp
           lbr     main                ; then back to main loop

cmd_rm:    sep     scall               ; remove file
           dw      rm
           lbr     main                ; then back to main loop

cmd_rn:    sep     scall               ; rename file
           dw      rn
           lbr     main                ; then back to main loop

cmd_rd:    sep     scall               ; remove directory
           dw      rd
           lbr     main                ; then back to main loop

cmd_cat:   sep     scall               ; type file
           dw      cat
           lbr     main                ; then back to main loop

check:     sep     scall               ; point to input buffer
           dw      setbuf
           sex     r6                  ; point x to test data
checklp:   ldx                         ; see if at end
           lbz     checkend            ; jump if so
           lda     rf                  ; get byte from input
           sm                          ; compare against test
           irx
           lbz     checklp             ; jump if matched
checkno:   lda     r6                  ; need to find the zero
           lbnz    checkno             ; jump if not found
           sex     r2                  ; point x back to stack
           adi     0                   ; signal not found
           sep     sret                ; return
checkend:  sex     r2                  ; point x back to stack
           inc     r6                  ; move past the zero
           ldn     rf                  ; get byte from input
           lbz     checkyes            ; jump if end of input
           smi     ' '                 ; check for a space
           lbnz    checkno             ; not a match
checkyes:  smi     0                   ; signal a match
           sep     sret                ; and return

setbuf:    ldi     high buffer         ; put buffer address
           phi     rf                  ; into rf
           ldi     low buffer
           plo     rf
           sep     sret                ; and return

dir:       ldi     high mode           ; point to mode
           phi     rb
           ldi     low mode            ; point to mode
           plo     rb                  ; set into base page
           ldi     0                   ; set mode to width
           str     rb
sw_lp:     sep     scall               ; move past leading whitespace
           dw      f_ltrim
           ldn     rf                  ; check for switches
           smi     '-'                 ; which begin with -
           lbnz    no_sw               ; jump if no switches
           inc     rf                  ; move to switch char
           lda     rf                  ; retrieve switch
           smi     'L'                 ; check for long mode
           lbnz    not_l               ; ignore others
           ldi     1                   ; set long mode
           str     rb
           lbr     sw_lp               ; loop back for more switches
not_l:     smi     ('S'-'L')           ; check for S
           lbnz    sw_lp               ; loop if not valid
           ldi     1                   ; set show size flag
           inc     rb
           str     rb
           dec     rb
           str     rb                  ; for -L when -S is selected
           lbr     sw_lp
no_sw:     sep     scall               ; open the directory
           dw      o_opendir
           ldi     0                   ; setup line counter
           plo     r7
dirloop:   ldi     0                   ; need to read 32 bytes
           phi     rc
           ldi     32
           plo     rc
           ldi     high buffer         ; setup transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           sep     scall               ; read files from dir
           dw      o_read
           glo     rc                  ; see if eof was hit
           smi     32
           lbnz    dirdone             ; jump if done
           ldi     high buffer         ; setup transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           lda     rf                  ; check for good entry
           lbnz    dirgood
           lda     rf                  ; check for good entry
           lbnz    dirgood
           lda     rf                  ; check for good entry
           lbnz    dirgood
           lda     rf                  ; check for good entry
           lbnz    dirgood
           lbr     dirloop             ; not a valid entry, loop back
dirgood:   ldi     low buffer          ; point to filename
           adi     12
           plo     rf
           plo     r8                  ; make a copy here
           ldi     high buffer
           adci    0
           phi     rf
           phi     r8
           ldi     0                   ; need to find size
           plo     r9
size_lp:   lda     r8                  ; load next byte
           lbz     size_dn             ; jump if found end
           inc     r9                  ; increment count
           inc     r7                  ; and terminal position
           lbr     size_lp             ; keep going til end found
size_dn:   inc     r9                  ; accomodate a trailing space
           glo     r7                  ; get terminal position
           smi     79                  ; see if off end
           lbnf    size_ok             ; jump if not
           sep     scall               ; move to next line
           dw      docrlf
           glo     r9                  ; get size of next entry
           plo     r7                  ; new terminal size
size_ok:   sep     scall               ; display the name
           dw      o_msg
           ldi     low buffer          ; point to flags
           adi     6
           plo     rf
           ldi     high buffer
           adci    0
           phi     rf
           ldn     rf                  ; get flags
           ani     1                   ; see if entry is a directory
           lbz     notdir              ; jump if not
           ldi     '/'                 ; indicate a dir
           sep     scall
           dw      o_type
           inc     r7                  ; accomodate the /
notdir:    ldi     ' '                 ; trailing space
           sep     scall
           dw      o_type
           inc     r7                  ; increment terminal position
           glo     r7                  ; see if at end
           smi     79
           lbnf    term_lp             ; jump if not
           sep     scall               ; perform a cr/lf
           dw      docrlf
           ldi     0                   ; set new terminal width
           plo     r7
           lbr     dirloop             ; loop back for next entry
term_lp:   glo     r7                  ; get terminal width
           ani     15                  ; uses 16 as tabstop
           lbnz    notdir              ; jump if not at tabstop
           ldn     rb                  ; get mode
           lbnz    long                ; jump if long mode
           lbr     dirloop             ; loop for next entry
long:      ldi     low buffer          ; point to directory entry
           adi     7                   ; date field
           plo     ra
           ldi     high buffer
           adci    0                   ; propagate carry
           phi     ra
           ldi     high buffer2        ; point to conversion buffer
           phi     rf
           ldi     low buffer2
           plo     rf
           sep     scall               ; convert the date/time
           dw      datetime
           ldi     high buffer2        ; point to conversion buffer
           phi     rf
           ldi     low buffer2
           plo     rf
           sep     scall               ; display it
           dw      o_msg


           inc     rb                  ; point to size flag
           ldn     rb                  ; retrieve it
           dec     rb                  ; put rb back
           lbz     do_crlf             ; loop back if no size requested
           ldi     high buffer         ; point to directory entry buffer
           phi     rf
           ldi     low buffer 
           plo     rf
           inc     rf                  ; point to starting lump
           inc     rf
           lda     rf                  ; get starting lump
           phi     ra
           ldn     rf
           plo     ra
           ldi     0                   ; setup count
           phi     rc
           plo     rc
sz_loop:   sep     scall               ; read value of lump
           dw      o_rdlump
           ghi     ra                  ; check for end of chain
           smi     0feh
           lbnz    not_end             ; jump if not
           glo     ra                  ; check low byte as well
           smi     0feh
           lbz     sz_done             ; jump if found end
not_end:   inc     rc                  ; increment lump count
           lbr     sz_loop             ; and keep looking
sz_done:   glo     rd                  ; save descriptor
           stxd
           ghi     rd
           stxd
           glo     rc                  ; get count
           shl                         ; multiply by 4096
           shl
           shl
           shl
           str     r2                  ; and set aside for a moment
           ldi     high buffer         ; point to directory entry buffer
           phi     rf
           ldi     low buffer
           plo     rf
           inc     rf                  ; point to lsb of eof word
           inc     rf
           inc     rf
           inc     rf
           inc     rf
           ldn     rf                  ; get low value of eof
           plo     rd                  ; and place into rd
           dec     rf                  ; point to msb
           ldn     rf                  ; and retrieve it
           add                         ; add with lump count
           phi     rd                  ; rd now has size
           ldi     high buffer2        ; point to directory output buffer
           phi     rf
           ldi     low buffer2
           plo     rf
           sep     scall               ; convert number to ascii
           dw      f_uintout
           ldi     0                   ; need terminator
           str     rf                  ; store into buffer
           irx                         ; recover RD
           ldxa
           phi     rd
           ldx
           plo     rd
           ldi     high buffer2        ; point to converted number
           phi     rf
           ldi     low buffer2
           plo     rf
           sep     scall               ; now display it
           dw      o_msg
do_crlf:   ldi     high crlf           ; point to crlf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           ldi     0                   ; set new terminal width
           plo     r7
           lbr     dirloop             ; to next entry

dirdone:   sep     scall               ; close the directory
           dw      o_close
           sep     scall               ; final cr/lf
           dw      docrlf
           sep     sret                ; return to os
docrlf:    glo     rf                  ; save rf
           stxd
           ghi     rf
           stxd
           ldi     high crlf           ; ponit to cr/lf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           irx                         ; recover original rf
           ldxa
           phi     rf
           ldx
           plo     rf
           sep     sret                ; and return

; ****************************************************
; *** Output 2 digit decimal number with leading 0 ***
; *** D - value to output                          ***
; *** RF - buffer to write value to                ***
; ****************************************************
intout2:   str     r2                  ; save value for a moment
           ldi     0                   ; setup count
           plo     re
           ldn     r2                  ; retrieve it
intout2lp: smi     10                  ; subtract 10
           lbnf    intout2go           ; jump if too small
           inc     re                  ; increment tens
           lbr     intout2lp           ; and keep looking
intout2go: adi     10                  ; make positive again
           str     r2                  ; save units
           glo     re                  ; get tens
           adi     '0'                 ; convert to ascii
           str     rf                  ; store into buffer
           inc     rf
           ldn     r2                  ; recover units
           adi     '0'                 ; convert to ascii
           str     rf                  ; and store into buffer
           inc     rf
           sep     sret                ; return to caller

; ***********************************************
; *** Display date/time from descriptor entry ***
; *** RA - pointer to packed date/time        ***
; *** RF - where to put it                    ***
; ***********************************************
datetime:  glo     rd                  ; save consumed register
           stxd
           ghi     rd
           stxd
           lda     ra                  ; get year/month
           shr                         ; shift high month bit into DF
           ldn     ra                  ; get low bits of month
           shrc                        ; shift high bit in
           shr                         ; then shift into position
           shr
           shr
           shr
           sep     scall               ; convert month output
           dw      intout2
           ldi     '/'                 ; need a slash
           str     rf                  ; place into output
           inc     rf
           ldn     ra                  ; recover day
           ani     01fh                ; mask for day
           sep     scall               ; convert month output
           dw      intout2
           ldi     '/'                 ; need a slash
           str     rf                  ; place into output
           inc     rf
           dec     ra                  ; point back to year
           lda     ra                  ; get year
           shr                         ; shift out high bit of month
           adi     180                 ; add in 1970
           plo     rd                  ; put in RD for conversion
           ldi     0                   ; need zero
           adci    7                   ; propagate carry
           phi     rd
           sep     scall               ; conver it 
           dw      f_uintout
           ldi     ' '                 ; need a space
           str     rf                  ; place into output
           inc     rf
           inc     ra                  ; point to time
           ldn     ra                  ; retrieve hours
           shr                         ; shift to proper position
           shr
           shr
           sep     scall               ; output it
           dw      intout2
           ldi     ':'                 ; need a colon
           str     rf                  ; place into output
           inc     rf
           lda     ra                  ; get minutes
           ani     07h                 ; strip out hours
           shl                         ; shift to needed spot
           shl
           shl
           str     r2                  ; save for combination
           ldn     ra                  ; get low bits of minutes
           shr                         ; shift into position
           shr
           shr
           shr
           shr
           or                          ; combine with high bites
           sep     scall               ; output it
           dw      intout2
           ldi     ':'                 ; need a colon
           str     rf                  ; place into output
           inc     rf
           ldn     ra                  ; get seconds
           ani     1fh                 ; strip minutes out
           shl                         ; multiply by 2
           sep     scall               ; output it
           dw      intout2
           ldi     ' '                 ; need a space
           str     rf                  ; place into output
           inc     rf
           ldi     ' '                 ; need a space
           str     rf                  ; place into output
           inc     rf
           ldi     0                   ; need terminator
           str     rf
           irx                         ; recover consumed register
           ldxa
           phi     rd
           ldx
           plo     rd
           sep     sret                ; and return

; ***********************************************************************


cd:        sep     scall               ; move past any leading spaces
           dw      f_ltrim
           ghi     rf                  ; copy argument address to rf
           phi     ra
           glo     rf
           plo     ra
           ldn     ra                  ; get first byte of args
           lbz     cd_view             ; view if no path
cd_loop1:  lda     ra                  ; look for first less <= space
           smi     33
           lbdf    cd_loop1
           dec     ra                  ; backup to char
           ldi     0                   ; need proper termination
           str     ra
chdirgo:   ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldn     rf                  ; get first byte of pathname
           lbz     cd_view             ; jump if going to view dir
           ldi     0                   ; flags for open
           sep     scall               ; attempt to change directory
           dw      o_chdir
           lbnf    cd_opened           ; jump if file was opened
           ldi     high direrr         ; get error message
           phi     rf
           ldi     low direrr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
cd_opened: sep     sret                ; return to os
cd_view:   ldi     high dta            ; point to suitable buffer
           phi     rf
           ldi     low dta
           plo     rf
           ldi     0
           str     rf                  ; place terminator
           sep     scall               ; get current directory
           dw      o_chdir
           ldi     high dta            ; point to retrieved path
           phi     rf
           ldi     low dta
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           ldi     high crlf           ; display a cr/lf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           sep     sret                ; return to caller

; ***********************************************************************

md:        sep     scall               ; move past any leading spaces
           dw      f_ltrim
           ghi     rf                  ; copy argument address to rf
           phi     ra
           glo     rf
           plo     ra
md_loop1:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    md_loop1
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           ghi     ra                  ; back to beginning of name
           phi     rf
           glo     ra
           plo     rf
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; flags for open
           sep     scall               ; attempt to make directory
           dw      o_mkdir
           lbnf    md_opened           ; jump if file was opened
           ldi     high direrr         ; get error message
           phi     rf
           ldi     low direrr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
md_opened: sep     sret                ; return to os

; ***********************************************************************

cp:        sep     scall               ; move past any leading spaces
           dw      f_ltrim
           ghi     rf                  ; copy argument address to rf
           phi     ra
           glo     rf
           plo     ra
cp_loop1:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    cp_loop1
           ghi     rf                  ; make copy of 2nd filename start
           phi     r9
           glo     rf
           plo     r9
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           inc     rf                  ; now find end of 2nd filename
cp_loop2:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    cp_loop2
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf

           ghi     ra                  ; back to beginning of name
           phi     rf
           glo     ra
           plo     rf
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; flags for open
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           lbnf    cp_opened           ; jump if file was opened
           ldi     high fileerr        ; get error message
           phi     rf
           ldi     low fileerr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           sep     sret                ; return to caller
cp_opened: ghi     rd                  ; make copy of descriptor
           phi     r7
           glo     rd
           plo     r7
           ghi     r9                  ; back to beginning of name
           phi     rf
           glo     r9
           plo     rf
           ldi     high dfildes        ; get file descriptor
           phi     rd
           ldi     low dfildes
           plo     rd
           glo     r7                  ; save first descriptor
           stxd
           ghi     r7
           stxd
           ldi     3                   ; flags for open, create if nonexist
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           irx                         ; recover first descriptor
           ldxa
           phi     r7
           ldx
           plo     r7
           ghi     rd                  ; make copy of descriptor
           phi     r8
           glo     rd
           plo     r8
cp_mainlp: ldi     0                   ; want to read 255 bytes
           phi     rc
           ldi     255
           plo     rc 
           ldi     high buffer         ; buffer to rettrieve data
           phi     rf
           ldi     low buffer
           plo     rf
           ghi     r7                  ; get descriptor
           phi     rd
           glo     r7
           plo     rd
           sep     scall               ; read the header
           dw      o_read
           glo     rc                  ; check for zero bytes read
           lbz     cp_done             ; jump if so
           ldi     high buffer         ; buffer to rettrieve data
           phi     rf
           ldi     low buffer
           plo     rf
           ghi     r8                  ; get descriptor
           phi     rd
           glo     r8
           plo     rd
           sep     scall               ; write to destination file
           dw      o_write
           br      cp_mainlp           ; loop back til done


cp_done:   sep     scall               ; close the file
           dw      o_close
           ghi     r8                  ; get destination descriptor
           phi     rd
           glo     r8
           plo     rd
           sep     scall               ; and close it
           dw      o_close
           sep     sret                ; return to os

; ***********************************************************************

cat:       sep     scall               ; move past any leading spaces
           dw      f_ltrim
           ghi     rf                  ; copy argument address to rf
           phi     ra
           glo     rf
           plo     ra
ct_loop1:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    ct_loop1
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           ghi     ra                  ; back to beginning of name
           phi     rf
           glo     ra
           plo     rf
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; flags for open
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           lbnf    ct_opened           ; jump if file was opened
           ldi     high fileerr        ; get error message
           phi     rf
           ldi     low fileerr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           sep     sret
ct_opened: ghi     rd                  ; make copy of descriptor
           phi     rb
           glo     rd
           plo     rb
           ldi     high buffer         ; buffer to rettrieve data
           phi     rf
           ldi     low buffer
           plo     rf

           ldi     0
           phi     r7
           plo     r7

ct_mainlp: ldi     0                   ; want to read 16 bytes
           phi     rc
           ldi     16
           plo     rc 
           ldi     high buffer         ; buffer to rettrieve data
           phi     rf
           ldi     low buffer
           plo     rf
           ghi     rb                  ; get descriptor
           phi     rd
           glo     rb
           plo     rd
           sep     scall               ; read the header
           dw      o_read
           glo     rc                  ; check for zero bytes read
           lbz     ct_done             ; jump if so
           ldi     high buffer         ; buffer to rettrieve data
           phi     r8
           ldi     low buffer
           plo     r8
ct_linelp: lda     r8                  ; get next byte
           sep     scall 
           dw      o_type
           dec     rc                  ; decrement read count
           glo     rc                  ; see if done
           lbnz    ct_linelp           ; loop back if not
           lbr     ct_mainlp           ; and loop back til done

ct_done:   sep     scall               ; close the file
           dw      o_close
           sep     sret                ; return to os

; ***********************************************************************

rm:        sep     scall               ; move past any leading spaces
           dw      f_ltrim
           ghi     rf                  ; copy argument address to rf
           phi     ra
           glo     rf
           plo     ra
rm_loop1:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    rm_loop1
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           ghi     ra                  ; back to beginning of name
           phi     rf
           glo     ra
           plo     rf
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; flags for open
           sep     scall               ; attempt to delete file
           dw      o_delete
           lbnf    rm_opened           ; jump if file was opened
           ldi     high fileerr        ; get error message
           phi     rf
           ldi     low fileerr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
rm_opened: sep     sret                ; return to os

; ***********************************************************************

rn:        sep     scall               ; move past any leading spaces
           dw      f_ltrim
           ghi     rf                  ; copy argument address to rf
           phi     ra
           glo     rf
           plo     ra
rn_loop1:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    rn_loop1
           ghi     rf                  ; make copy of 2nd filename start
           phi     rc
           glo     rf
           plo     rc
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           inc     rf                  ; now find end of 2nd filename
rn_loop2:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    rn_loop2
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           ghi     ra                  ; get source filename
           phi     rf
           glo     ra
           plo     rf
           sep     scall               ; rename the file
           dw      o_rename
           lbnf    renamed             ; jump if file was opened
           ldi     high fileerr        ; get error message
           phi     rf
           ldi     low fileerr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
renamed:   sep     sret                ; return to os

; ***********************************************************************

rd:        sep     scall               ; move past any leading spaces
           dw      f_ltrim
           ghi     rf                  ; copy argument address to rf
           phi     ra
           glo     rf
           plo     ra
rd_loop1:  lda     rf                  ; look for first less <= space
           smi     33
           lbdf    rd_loop1
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           ghi     ra                  ; back to beginning of name
           phi     rf
           glo     ra
           plo     rf
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; flags for open
           sep     scall               ; attempt to change directory
           dw      o_rmdir
           lbnf    rd_opened           ; jump if file was opened
           ldi     high direrr         ; get error message
           phi     rf
           ldi     low direrr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
rd_opened: sep     sret                ; return to os

; ***********************************************************************


crlf:      db      10,13,0
mode:      db      0
size:      db      0
fileerr:   db      'File not found',10,13,0
direrr:    db      'Invalid Directory'
cmderr:    db      'Invalid Command',10,13,0
fildes:    db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0
dfildes:   db      0,0,0,0
           dw      ddta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

endcheck:  db      0                   ; end of checksum

buffer2:   ds      64
cbuffer:   ds      80
dta:       ds      512
ddta:      ds      512
buffer:    ds      32
; ***********************************************************************

           org     07e00h
stub:      ldi     high stkvalue       ; address for stack
           phi     r7
           ldi     low stkvalue
           plo     r7
           ghi     r2                  ; save stack address
           str     r7
           inc     r7
           glo     r2
           str     r7
           sep     scall               ; get input buffer address
           dw      setbuf
           sep     scall               ; attempt to exec external command
           dw      o_exec
           bnf     reload
           sep     scall               ; get input buffer address
           dw      setbuf
           sep     scall               ; attempt to exec external command
           dw      o_execbin
           bnf     reload
sterror:   ldi     high cmderr         ; indicate command error
           phi     rf
           ldi     low cmderr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
reload:    sep     scall               ; get checksum status of shell
           dw      (chksum-05f00h)
           plo     re                  ; save it
           ldi     high chkvalue       ; point to check value
           phi     rf
           ldi     low chkvalue
           plo     rf
           sex     rf                  ; setup for compare
           glo     re
           xor                         ; see if checksums match
           sex     r2                  ; point x back to stack
           lbz     main                ; no reload is needed
           ldi     high wrmvalue       ; point to warm start vector
           phi     rf
           ldi     low wrmvalue
           plo     rf
           ldi     high (o_wrmboot+1)  ; need to set warmboot vector
           phi     rd
           ldi     low (o_wrmboot+1)
           plo     rd
           lda     rf                  ; copy vector back to o_wrmboot
           str     rd
           inc     rd
           ldn     rf
           str     rd
           ldi     high (shell-05f00h) ; point to shell command line
           phi     rf
           ldi     low (shell-05f00h)
           plo     rf
           sep     scall               ; reload the shell
           dw      o_exec
           lbnf    main                ; back to main loop
wrm_rest:  ldi     high wrmvalue       ; point to warm start vector
           phi     rf
           ldi     low wrmvalue
           plo     rf
           ldi     high (o_wrmboot+1)  ; need to set warmboot vector
           phi     rd
           ldi     low (o_wrmboot+1)
           plo     rd
           lda     rf                  ; copy vector back to o_wrmboot
           str     rd
           inc     rd
           ldn     rf
           str     rd
           lbr     o_wrmboot           ; and back to kernel prompt

stub_wrm:  ldi     high stkvalue       ; address for stack
           phi     r7
           ldi     low stkvalue
           plo     r7
           lda     r7                  ; reset the stack
           phi     r2
           lda     r7
           plo     r2
           br      reload              ; check if shell reload is needed

chksum:    ldi     70h                 ; beginning of shell memory
           phi     rf
           ldi     00
           plo     rf
           ldi     high endcheck       ; size of memory to check
           smi     070h
           phi     rc
           ldi     low endcheck
           plo     rc
           ldi     0ffh                ; set starting value
           plo     re                  ; holder for checksum
           sex     rf                  ; point to memory data
chksmlp:   glo     re                  ; get current checksum
           xor                         ; xor with memory byte
           inc     rf                  ; point to next byte
           shl                         ; shift high bit to DF
           glo     re                  ; now do a ring shift
           shlc
           plo     re                  ; store it
           dec     rc                  ; decrement count
           glo     rc                  ; see if done
           bnz     chksmlp             ; jump if not
           ghi     rc                  ; check high byte as well
           bnz     chksmlp
           sex     r2                  ; point x back to stack
           glo     re                  ; recover checksum
           sep     sret                ; and return

shell:     db      '/BIN/SHELL',0
endrom:    equ     $



