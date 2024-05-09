;    .PAGE "FTe SYSTEM EQUATES FOR ATARI"
;
;  FILE = #DN:SYSEQU.ASM
;
;
; I/O CONTROL BLOCK EQUATES
;
;SAVEPC = *      ; SAVE CURRENT ORG
;

IOCB =  $0340   ;START OF SYSTEM IOCBS
;
ICHID = IOCB    ;DEVICE HANDLER IS (SET BY OS)
ICDNO = IOCB+1    ;DEVICE NUMBER (SET BY OS)
ICCOM = IOCB+2    ;I/O COMMAND
ICSTA = IOCB+3    ;I/O STATUS
ICBADR = IOCB+4   ;BUFFER ADDRESS
ICPUT = IOCB+6   ;DH PUT ROUTINE (ADR-1)
ICBLEN = IOCB+8   ;BUFFER LENGTH
ICAUX1 = IOCB+10   ;AUX 1
ICAUX2 = IOCB+11   ;AUX 2
ICAUX3 = IOCB+12   ;AUX 3
ICAUX4 = IOCB+13   ;AUX 4
ICAUX5 = IOCB+14   ;AUX 5
ICAUX6 = IOCB+15   ;AUX 6
;
IOCBLEN = 16 ;LENGTH OF ONE IOCB
;
; IOCB COMMAND VALUE EQUATES
;
COPN =  3       ;OPEN
CGBINR = 7      ;GET BINARY RECORD
CGTXTR = 5      ;GET TEXT RECORD
CPBINR = 11     ;PUT BINARY RECORD
CPTXTR = 9      ;PUT TEXT RECORD
CCLOSE = 12     ;CLOSE 
CSTAT = 13      ;GET STATUS
;
; DEVICE DEPENDENT COMMAND EQUATES FOR FILE MANAGER
;
CREN =  32      ;RENAME
CERA =  33      ;ERASE
CPRO =  35      ;PROTECT
CUNP =  36      ;UNPROTECT
CPOINT = 37     ;POINT
CNOTE = 38      ;NOTE
;
; AUX1 VALUES REQD FOR OPEN
;
OPIN =  4       ;OPEN INPUT
OPOUT = 8       ;OPEN OUTPUT
OPUPD = 12      ;OPEN UPDATE
OPAPND = 9      ;OPEN APPEND
OPDIR = 6       ;OPEN DIRECTORY
;
;    .PAGE 
;
;    EXECUTE FLAG DEFINES
;
EXCYES = $80    ; EXECUTE IN PROGRESS
EXCSCR = $40    ; ECHO EXCUTE INPUT TO SCREEN
EXCNEW = $10    ; EXECUTE START UP MODE
EXCSUP = $20    ; COLD START EXEC FLAG
;
; MISC ADDRESS EQUATES
;
CPALOC = $0A    ; POINTER TO CP/A
WARMST = $08    ; WAR, START (0=COLD)
MEMLO = $02E7   ; AVAIL MEM (LOW) PTR
MEMTOP = $02E5  ; AVAIL MEM (HIGH) PTR
APPMHI = $0E    ; UPPER LIMIT OF APPLICATION MEMORY
INITADR = $02E2 ; ATARI LOAD/INIT ADR
GOADR = $02E0   ; ATARI LOAD/GO ADR
CARTLOC = $BFFA ; CARTRIDGE RUN LOCATION
CIO =   $E456   ;CIO ENTRY ADR
EOL =   $9B     ; END OF LINE CHAR
;
;  CP/A FUNCTION AND VALUE DISPLACEMSNT
;     (INDIRECT THROUGH CPALOC)
;           IE. (CPALOC),Y
;
CPGNFN = 3      ; GET NEXT FILE NAME
CPDFDV = $07    ; DEFAULT DRIVE (3 BYTES)
CPBUFP = $0A    ; CMD BUFF NEXT CHAR POINTR (1 BYTE)
CPEXFL = $0B    ; EXECUTE FLAG
CPEXFN = $0C    ; EXECUTE FILE NAME (16 BYTES)
CPEXNP = $1C    ; EXECUTE NOTE/POINT VALUES
CPFNAM = $21    ; FILENAME BUFFER
RUNLOC = $3D    ; CP/A LOAD/RUN ADR
CPCMDB = $3F    ; COMMAND BUFFER (60 BYTES)
CPCMDGO = $F3
;
;    *=  SAVEPC  ; RESTORE PC
;
