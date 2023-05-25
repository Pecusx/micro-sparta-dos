     ;MICRO SPARTA DOS 4.2e
	 
	; wersja e powinna odczytac program zapisany na dysku o dowolnej dlugosci sektora
	; przetestowane dla 126 i 256b .... czekamy na testy KMK dla 512b
	; nie jest zrobiona obsluga wczytywania meny dla dluzszych sektorow, ale loader uznajemy za skonczony !!!

; nowa koncepcja:

; 1. wywali� turbo 'top-drive'

; 2. przerobi� loader i menu na obs�ug� sektor�w dow. d�ugo�ci

; 3. przepisac czytanie tablicy sektor�w indeksowych z loadera do menu:
;    a. w menu odczytywane s� wszystkie sektory tablicy indeksowej
;    b. budowana jest "skompresowana" tablica offset�w w stosunku do pierwszego sektora na nast. zasadzie:
;       mamy nast. znaczniki : (nowa koncepcja)
;       1xxxxxxx  -- (0xxxxxxx = ile sektor�w omin��) . Op�aci si� u�ywa� do max 255 sektor�w do przeskoczenia.
;       0xxxxxxx  -- (0xxxxxxx = ile kolejnych sektor�w wczyta�)
;       00000000  -- nast�pne 2 bajty to numer kolejnego sektora do odczytania
;               

; 4. nowa 'skompresowana' tablica indeksowa podwyzsza memlo

; 5. w wolne miejsca kitramy co si� da (np. do buforu magnetofonu) 

	 
     ;START ADDR = 1FFD
     ;END ADDR = 28C9
         ;.OPT noList
acktimeout = $a
readtimeout = 2


STACKP = $0318
CRITIC = $42
DRETRY = $02BD
CASFLG = $030F
CRETRY = $029C


CASINI = $02
BOOT   = $09
DOSVEC = $0a
DOSINI = $0c
APPMHI = $0e

IRQENS = $10


; zmienne procedury ladowania pliku (w miejscu zmiennych CIO - ktore sa nieuzywane)

; adres komorki pamieci do ktorej zapisujemy kolejny ladowany bajt pliku
InBlockAddr = $24  ; word
; dlugosc ladowanego bloku odjeta od $10000 (zwiekszana osiaga ZERO po zaladowaniu bloku w calosci)
ToBlockEnd = $26  ; word
; mlodszy bajt dlugosci sektora (pomocniczo na stronie zerowej)
SecLenZ = $28
; najmlodszy z trzech bajtow zliczajacych do konca pliku - patrz ToFileEndH
ToFileEndL = $29
CompressedMapPos = $3D ; pozycja w skompresowanej mapie pliku

CheckSUM = $30
SecLenUS = $31
SecBuffer = $32
CRETRYZ = $34
TransmitError =$35
Looperka = $36
StackCopy = $37


SAVMSC = $58

; Adres bufora przechowywania Aktualnie obrabianego sektora zawierajacego
; katalog
CurrentDirBuf = $CA
; Adres (w buforze CurrentDirBuff, ale bezwzgledny) poczatku informacji
; o obrabianym pliku (skok co $17)
CurrentFileInfoBuff = $D0
; Aders bufora mapy sektorow aktualnego katalogu
DirMapSect = $D2

; Stan klawisza Shift w chwili uruchomienia programu (zapamietany toz przed nim)

VSERIN = $020a

COLPF2S = $02c6
COLBAKS = $02c8

COLDST = $0244
MEMTOP = $02e5
MEMLO  = $02e7

KBCODES = $02fc

DDEVIC = $0300
DUNIT  = $0301
DCOMND = $0302
DBUFA  = $0304
DBYT   = $0308
DAUX1  = $030a
DAUX2  = $030b

ICCMD = $0342
ICBUFA = $0344
;ICBUFA+1 = $0345
ICBUFL = $0348
;ICBUFL+1 = $0349
ICAX1 = $034a
ICAX2 = $034b

AUDF3  = $d204
AUDF4 = $d206
AUDC4 = $d207
AUDCTL = $d208
SKSTRES = $d20a
SEROUT = $D20d
SERIN = $D20d
IRQEN = $D20e
IRQST = $D20e


SKSTAT = $d20f
SKCTL = $d20f


PBCTL  = $d303
PORTB  = $d301

JCIOMAIN   = $e456
JSIOINT   = $e459
JTESTROM = $e471
JRESETWM = $e474
JRESETCD = $e477

	org $1FFD

; przesuniecia potrzebne do relokacji
offset1 = movedproc-$0700
offset2 = HappyUSMovedProc-$0a00
; adres bufora na sektor wczytywanego pliku w oryginale $0800, ale moze wydluzyc sie procedura
; uwaga, ty juz odjety offset, wiec w procedurze nie odejmujemy!!!
FileSecBuff = loader.FirstMapSectorNr   ; po przepisaniu
; adres bufora na sektor mapy wczytywanego pliku
FileMapBuff = FileSecBuff + $0100  ; oba bufory powinny miec taki sam mlodszy bajt adresu  ; po przepisaniu
;TempMEMLO = FileMapBuff + $0100  ; Memlo bez procedur turbo (wartosc wyjsciowa)
TempMEMLO = loader.FirstMapSectorNr   ; Koniec procedury loader (poczatek bufora)
; Adres (offset) w mapie sektorow z ktorego nalezy pobrac adres nastepnego sektora
; startuje od $04 (pierwsze 4 bajty mapy, to numer nastepnego i poprzedniego jej sektora)
; jesli rowna sie dlugosci sektora to osiagnieto koniec tego sektora mapy
; i trzeba zaladowac nastepny
; obecnie zmienna trzymana w buforze mapy (zamazuje numer poprzedniego sektora)
PointInMap = FileMapBuff+$02   ; po przepisaniu

START
     JMP   FirstRun           ;1FFD  4C 70 21
; procedura ladujaca, ktora zostanie przepisana pod adres $0700 po wybraniu programu
; do wczytania (wszystkie skoki bezwzgledne i samomodyfikacje "-offset1" !!!)

movedproc 
	.local loader, $0700
 
; dwa starsze bajty (bo to wielkosc 3 bajtowa) dlugosci pliku odjetej od $1000000
; dzieki czemu mozna stwierdzic osiagniecie konca pliku przez zwiekszanie tych
; bajtow (wraz z najmlodszym) i sprawdzanie czy osiagnieto ZERO
ToFileEndH
     .WO $0000
FileInit		; skok JSR pod adres inicjalizacji po (przed) kazdym nastepnym bloku binarnym
     TXA
     PHA
     LDA   ToFileEndL
     PHA
     JSR   GoInitAddr
     PLA
     STA   ToFileEndL
     PLA
     TAX
FileNextBlock							; wczytanie kolejnego bloku binarnego
     LDA   SecLen					; przepisanie mlodszego bajtu dlugosci sektora na ZP - zeby kod byl krotszy!
     STA   SecLenZ
     JSR   FileGetBlockStart  ; pobranie dwoch bajtow (adres poczatku bloku)
     AND   InBlockAddr
     CMP  #$FF							; jesli oba sa $FF to.....
     BNE   FileNoFFFFHead
     JSR   FileGetBlockStart 	; pobranie jeszcze raz  
FileNoFFFFHead
     JSR   FileGetByte        ; Pobranie adresu konca ladowanego bloku
     SBC   InBlockAddr         			; i wyliczenie jego dlugosci
     EOR  #$FF             				; UWAGA! Dlugosc jest zEORowana z $FFFF
     STA   ToBlockEnd       			; czyli odjeta od $10000
     PHP                   				; odliczanie ilosci pobranych bajtow jest wiec potem robione
     JSR   FileGetByte     	; przez dodawanie i sprawdzanie czy nie ZERO
     PLP
     SBC   InBlockAddr+1
     EOR  #$FF
     STA   ToBlockEnd+1
     SEC
WhatIsIt
     BCS   FileNoFirstBlock 			; tu wstawiany jest raz (na poczatku) rozkaz LDA ($0D),Y
										; ktory tylko wylacza skok !!!
     DEC   WhatIsIt  			; Przywraca poprzednie BCS z poprzedniego wiersza!!
     LDA   InBlockAddr          		; Czyli TO wykona sie tylko RAZ
     STA   $02E0           				; Wpisujac adres pierwszego bloku do ard. startu
     LDA   InBlockAddr+1          		; na wypadek gdyby plik nie konczyl sie blokiem
     STA   $02E1           				; z adresem startu (bywa i tak).
FileNoFirstBlock
     LDA  #<Jrts         		; do adresu inicjacji wpisanie adresu rozkazu RTS
     STA   $02E2          				; bo po kazdym bloku odbywa sie tam skok
     LDA  #>Jrts          	; jesli nie jest to blok z adresem inicjacji
     STA   $02E3       					; to dzieki temu nic sie nie stanie
     LDY  #$00
BlockReadLoop							;; petla odczytujaca z pliku blok binarny 
     INC   ToFileEndL          			;; zwiekszenie licznika bajtow w calym pliku i jesli ZERO
     BEQ   GoCheckEOF          			;; skok do procedury sprawdzajacej dwa starsze jego bajty
     CPX   SecLenZ         				;; sprawdzenie czy juz caly sektor przepisany jesli tak 
	 bne   NoNextSector1            ; --
	 lda   InSectorCountH            ; -- obsluga sektorow ponad 256b
	 cmp   SecLen+1                  ; --
     BEQ   GoGetNextFileSect       		;; skok do procedury pobrania nastepnego sektora 
NoNextSector1
FileSecBuffHaddr1 = *+2         ; samomodyfikacja kodu potrzebna do obslugi sektorow ponad 256b !!!
     LDA   FileSecBuff,X
     INX
	 bne   InBlockReadLoop		; --
	 jsr   IncrementationXH		; --  obsluga sektorow ponad 256b (ten trik dziala bo tam juz byl RTS :) )
InBlockReadLoop
     STA  (InBlockAddr),Y
     INY
     BNE   label15
     INC   InBlockAddr+1
label15
     INC   ToBlockEnd
     BNE   BlockReadLoop
     INC   ToBlockEnd+1
     BNE   BlockReadLoop
     BEQ   FileInit        				; koniec bloku - skok pod adres inicjalizacji
GoCheckEOF
     JSR   CheckEOF  		; skok do procedury wspolnej dla pobierania bloku i bajtu
     BCS   InBlockReadLoop        		;tu zawsze jest CARRY, a w A kolejny bajt z pliku, wiec powrot do petli
GoGetNextFileSect
     JSR   GetNextFileSect
     BCS   InBlockReadLoop          	; tu zawsze jest CARRY, a w A kolejny bajt z pliku, wiec powrot do petli
FileGetBlockStart
     JSR   FileGetByte
     STA   InBlockAddr
     JSR   FileGetByte
     STA   InBlockAddr+1
     RTS
GoInitAddr
     JMP  ($02E2)
GoSelfTest
     JMP   JTESTROM
GetDataSector
     LDA   SectorNumber+1
     ORA   SectorNumber
     BEQ   GoSelfTest  					; jesli sektor numer 0 - selftest
ReadErrorLoop
     LDX  #$0B
SetDCB
     LDA   blokDanychIO1,X
     STA   DDEVIC,X
     DEX
     BPL   SetDCB
SioJMP
     JSR   JSIOINT
     BMI   ReadErrorLoop				; jesli blad odczytu sektora to czytamy ponownie
     RTS
blokDanychIO1
    .BY $31,$01,$52,$40,<FileSecBuff,>FileSecBuff,$0A,$00,$80,$00
; Dlugosc sektora to dwa ostatnie bajty bloku danych ($0080 lub $0100)
SecLen = blokDanychIO1+8 ; SecLen wskazuje na kom�rki do wpisania d�ugo�ci sektora przed przepisaniem procki na stron� $0700
SectorNumber
    .WO $0000
CheckEOF
     INC   ToFileEndH
     BNE   NotEOF
     INC   ToFileEndH+1
     BNE   NotEOF
EndOfFile								; to wykona sie przy nieoczekiwanym (i oczekiwanym) koncu pliku
     LDA  #>(JTESTROM-1)
     PHA
     LDA  #<(JTESTROM-1)
     PHA
     JMP  ($02E0)
; Pobranie z pliku pojedynczego bajtu danych ... wynik w A, a CARRY ustawiony!!!
FileGetByte
     INC   ToFileEndL
     BEQ   CheckEOF
NotEOF
     CPX   SecLenZ						;; nie EOF, ale moze koniec sektora
	 bne   ByteToACCU				; --
	 lda   InSectorCountH			; -- obsluga sektorow ponad 256b
	 cmp   SecLen+1				; --
     BEQ   GetNextFileSect				;; jesli tak to pobieramy nastepny
ByteToACCU
FileSecBuffHaddr2 = *+2         ; samomodyfikacja kodu potrzebna do obslugi sektorow ponad 256b !!!
     LDA   FileSecBuff,X  				;; pobranie bajtu z pliku do A 
     INX
	 bne   GoToSec					; --
IncrementationXH					; taki trik - to przypadkiem jest podprogram, wiec mozna tu wskoczyc zamiast zwiekszac liczniki w innym miejscu po raz drugi
	 inc   InSectorCountH			; --
	 inc   FileSecBuffHaddr1		; --  obsluga sektorow ponad 256b
	 inc   FileSecBuffHaddr2		; --
GoToSec
     SEC
Jrts
     RTS
; Wczytanie do bufora kolejnego sektora pliku, kolejny bajt pliku w A, a CARRY ustawiony!!!
GetNextFileSect
	tya
	pha
ReadNextInSequence	
SectorSequenceCount = *+1
    lda #$00 ; to ju� ma by� zainicjowane!!!
	beq NextMapPosition
	dec SectorSequenceCount
	inc SectorNumber
	bne noIncDAUX2
	inc SectorNumber+1
noIncDAUX2
	bne ReadyToRead
	;jak jest tutaj to jest b��d...
	;powinien by� skok do self-testu...
NextMapPosition
	jsr incCompressedMapPos
	;UWAGA! adres w mapie jest zawsze zwi�kszany o 1
	;wi�c przed uruchomieniem loadera trzeba zainicjowa� adresem-1
	ldy #0
	lda (CompressedMapPos),y
	bmi HowManyToSkip
	beq SetNewStartSector
	;tutaj jest ile kolejnych sektor�w przeczyta� w sekwencji
	sta SectorSequenceCount
	bne ReadNextInSequence ;zawsze skoczy
HowManyToSkip
	and #%01111111
	clc
	adc SectorNumber
	sta SectorNumber
	bcc noIncDAUX2_v2
	inc SectorNumber+1
noIncDAUX2_v2
	bne ReadyToRead
	;jak jest tutaj to jest b��d...
	;powinien by� skok do self-testu...
SetNewStartSector
	jsr incCompressedMapPos
	lda (CompressedMapPos),y
	sta SectorNumber
	jsr incCompressedMapPos
	lda (CompressedMapPos),y
	sta SectorNumber+1	
ReadyToRead	
	JSR   GetDataSector		; wczytanie kolejnego sektora pliku do bufora

	pla
	tay
	lda   #>FileSecBuff			; --
	sta   FileSecBuffHaddr1		; --  obsluga sektorow ponad 256b
	sta   FileSecBuffHaddr2		; --
	LDX  #$00							; wyzerowanie wskaznika bajtu w sektorze
	stx   InSectorCountH			; --
	JEQ   ByteToACCU					; skok do pobrania bajtu z pliku do A i konc

incCompressedMapPos
	inc CompressedMapPos
	bne skipIncCompressedMapPos
	inc CompressedMapPos+1
skipIncCompressedMapPos
	rts
; starszy bajt licznika pozycji bajtu w sektorze - mlodszy jest caly czas w X
; potrzebny do obslugi sektorow wiekszych od 256b
InSectorCountH
    .BY $00
; koniec czesci glownejprocedury ladowania pliku przepisywanej pod $0700
; tu zaczyna sie (takze przepisywana) procedura wykonujaca sie tylko raz
; w tym miejscu potem bedzie bufor
; Tutaj wpisywany jest przez menu loadera numer pierwszego sektora
; mapy pliku do wczytania, potrzebny tylko na starcie ladowania
zzzzzz  ; dla wygody - ta etykieta powinna miec $2100 jesli procedura ja poprzedzajaca miesci sie na stronie
FirstMapSectorNr
     .WO $0000
LoadStart
	 ; na poczatek czyszczenie pamieci od MEMLO do MEMTOP
     LDY   MEMLO
     LDA   MEMLO+1
     STA   InMemClearLoop+2
OutMemClearLoop
     LDA  #$00
InMemClearLoop
     STA   $0900,Y
     INY
     BNE   InMemClearLoop
     INC   InMemClearLoop+2
     LDA   InMemClearLoop+2
     CMP   MEMTOP+1
     BCC   OutMemClearLoop
     LDA   MEMTOP+1
     STA   LastMemPageClear+2
     LDY   MEMTOP
     LDA  #$00
LastMemPageClear
     STA   $8000,Y
     DEY
     CPY  #$FF
     BNE   LastMemPageClear
	 ; wyczyszczona, wiec ....
FirstFileSectorL=*+1
	 LDA   #$FF   ; kod samomodyfikujacy - tu wpisany bedzie numer pierwszego sektora pliku
	 STA   DAUX1
FirstFileSectorH=*+1
	 LDA   #$FF
	 STA   DAUX2
     LDA   tempToFileEndL
     STA   ToFileEndL
     LDA  #$FF
     STA   KBCODES
     INC   WhatIsIt	; zmiana BCS omijajacego procedure na LDA (adres pierwszego bloku do STARTADR)
     LDX   SecLen		; dlugosc sektora do X, czyli wymuszenie przeczytania nastepnego sektora
	 LDA   Seclen+1
	 STA   InSectorCountH   ; obsluga sektorow ponad 256b
     ;jmp *
     JMP   FileNextBlock
; tymczasowe przechowanie najmlodszego bajtu licznika do konca pliku
; sluzy do przepisania tego bajtu z glownego programu do zmiennej loadera
tempToFileEndL
     .BY $00             ;2152  00
    .endl
JAkieTurbo
USmode
	 .BY $01     ; 0 - brak turbo   1 - Ultra Speed
QMEG
     .BY $01    ;1 - brak QMEGa     0 - jest QMEG
BootDrive
     .BY $00    ;Numer stacji dysk�w z kt�rej sie BOOT robi
BootShift
     .BY $01	; stan Shift w czasie bootowania (przyda sie jednak)  1 - bez shift  0 - Shift wcisniety
; Zamiana 4 mlodszych bitow z A na liczbe Hex w Ascii (tez w A)
bin2AsciiHex
     AND  #$0F 
     ORA  #$30 
     CMP  #$3A
     BCC   labelka 
     CLC
     ADC  #$07
labelka
     RTS    

Edriver
     .BY "E:",$9b      
mainprog
     LDX  #$00             ; kanal nr 0
     JSR   CloseX           ; Zamkniecie Ekranu
     BMI   ErrorDisplay 
     LDX  #$00             ; kanal nr 0
     LDA  #$03 
     STA   ICCMD,X 
     LDA  #$0C 
     STA   ICAX1,X
     STA   ICBUFL,X
     LDA  #$00 
     STA   ICAX2,X
     STA   ICBUFL+1,X
     LDA  #<Edriver
     STA   ICBUFA,X
     LDA  #>Edriver
     STA   ICBUFA+1,X
     JSR   JCIOMAIN            ; Otwarcie "E:" w trybie Gr.0
     BMI   ErrorDisplay
     LDA  #$C4 	; ustawienie koloru t�a
     STA   COLPF2S
     STA   COLBAKS
     LDA   QMEG       ; jesli jest QMEG to wylacza sie tryb US
	 AND   BootShift  ; i jak byl Shift w czasie bootowania tez sie wylacza
     STA   USmode           
     BEQ   NoUSSpeed
     ; Pytanie stacji o predkosc transmisji Happy/US-Doubler
     ldy  #<blokDanychIO6    
     ldx  #>blokDanychIO6
     jsr   Table2DCB
     jsr   JSIOINT             ; wysylamy "?"
     bpl   USSpeed
     lda   #0		; blad odczytu wiec nie ma USspeed - zerujemy wiec flage
	 sta   USmode
	 beq   NoUSSpeed
USSpeed
	 LDY #$2
USstatprint
	 LDA ONtext,y
	 STA USstatus,y
	 DEY
	 bpl USstatprint

NoUSSpeed
     JMP   ReadMainDir        
Error148
     LDY  #$94             ; kod bledu do Y
     ; wyswietlenie komunikatu o bledzie - kod bledu w Y
ErrorDisplay
     TYA
     PHA
     JSR   Close1
     PLA 
     PHA
     LSR
     LSR 
     LSR
     LSR
     JSR   bin2AsciiHex  ; 4 starsze bity na HEX
     STA   ErrorNumHex
     PLA 
     JSR   bin2AsciiHex  ; 4 mlodsze bity na HEX
     STA   ErrorNumHex+1 
     JSR   PrintXY
     .BY $00,$00  
     .BY $7d              ; kod czyszczenia ekranu
     .BY "ERROR - $"
ErrorNumHex
     .BY "00",$00        ;21F8  30
     ; czekamy na dowolny klawisz
     LDA  #$FF
     STA   KBCODES 
WaitKloop
     LDX   KBCODES
     INX 
     BEQ   WaitKloop 
     LDA  #$FF
     STA   KBCODES
     ; ------------------
     ; na wypadek wybrania nieistniejacej stacji
     ; po bledzie przechodzimy na te z ktorej sie ladowalismy
     LDA BootDrive
	 LDA #1
     JSR SeTDriveNR
     ; -----------------
     JMP   mainprog     ; i odpalamy program od nowa
ReadMainDir
     LDX  #>FirstSectorBuff             ;220E  A2 29
     LDY  #<FirstSectorBuff             ;2210  A0 00
     JSR   ReadFirstSect           ;2212  20 3A 27
; Sprawdzenie wersji DOSa pod ktora formatowany byl dysk
     LDA   FirstSectorBuff+$20
     CMP  #$11            ; Sparta DOS 1.1
     BEQ   SpartaDisk
     CMP  #$20            ; Sparta DOS 2.x 3.x Sparta DOS X 4.1x/4.2x
     BEQ	SpartaDisk
	 CMP  #$21			   ; Nowy format Sparta DOS X >= 4.39 (moga byc sektory wieksze niz 256b)
     BNE   Error148       ; Nieobslugiwany format dyskietki
SpartaDisk
     LDX  #$00 
; pobranie dlugosci sektora ($00 lub $80) - poprawione dla wiekszych niz 256
     LDA   FirstSectorBuff+$1F
     BMI   Sektor128b
	 TAX
	 LDA  #$00
     INX                   ; i wyliczenie starszego bajtu
Sektor128b
     STA   .adr loader.SecLen	; przed przepisaniem
     STX   .adr loader.SecLen+1	; przed przepisaniem
	 ; pokazanie na ekranie
	 LDA   DensityCodes,X
	 STA   DensityDisplay
; pobranie numeru pierwszego sektora mapy sektorow glownego katalogu
     LDY   FirstSectorBuff+$09           ;222E  AC 09 29
     LDX   FirstSectorBuff+$0A           ;2231  AE 0A 29
; odczyt katalogu, ktorego mapa zaczyna sie w sektorze y*256+x
ReadDIR
     STY   DirMapSect             ;2234  84 D2
     STX   DirMapSect+1             ;2236  86 D3
     LDA  #>DirSectorBuff             ;2238  A9 2A
     STA   CurrentFileInfoBuff+1             ;223A  85 D1
     STA   CurrentDirBuf+1             ;223C  85 CB
     LDA  #<DirSectorBuff             ;223E  A9 80
     STA   CurrentFileInfoBuff             ;2240  85 D0
     STA   CurrentDirBuf             ;2242  85 CA
     LDA  #$00             ;2244  A9 00
     STA   $D4             ;2246  85 D4
     STA   $D5             ;2248  85 D5
     LDA  #$17             ;224A  A9 17
     JSR   label39           ;224C  20 5C 26
     LDA   CurrentFileInfoBuff             ;224F  A5 D0
     STA   $CC             ;2251  85 CC
     LDA   CurrentFileInfoBuff+1             ;2253  A5 D1
     STA   $CD             ;2255  85 CD
     LDA  #$00             ;2257  A9 00
     STA   $D7             ;2259  85 D7
     STA   $D8             ;225B  85 D8
     LDA   CurrentDirBuf             ;225D  A5 CA
     STA   CurrentFileInfoBuff             ;225F  85 D0
     LDA   CurrentDirBuf+1             ;2261  A5 CB
     STA   CurrentFileInfoBuff+1             ;2263  85 D1
label46
     LDA   CurrentFileInfoBuff+1             ;2265  A5 D1
     CMP   $CD             ;2267  C5 CD
     BCC   label40           ;2269  90 08
     BNE   label41           ;226B  D0 71
     LDA   CurrentFileInfoBuff             ;226D  A5 D0
     CMP   $CC             ;226F  C5 CC
     BCS   label41           ;2271  B0 6B
label40
     LDY  #$00             ;2273  A0 00
     LDA  (CurrentFileInfoBuff),Y          ;2275  B1 D0
     AND  #$38             ;2277  29 38
     CMP  #$08             ;2279  C9 08
     BNE   label42           ;227B  D0 1C
     LDY  #$10             ;227D  A0 10
     LDX  #$0A             ;227F  A2 0A
label43
     LDA  (CurrentFileInfoBuff),Y          ;2281  B1 D0
     CMP   ProgName,X         ;2283  DD 8E 22
     BNE   label42           ;2286  D0 11
     DEY                   ;2288  88
     DEX                   ;2289  CA
     BPL   label43           ;228A  10 F5
     BMI   DATfileFound           ;228C  30 19
ProgName
     .BY "MSDOS   DAT"   ;228E  4D 53 44
label42
     LDA   CurrentFileInfoBuff             ;2299  A5 D0
     CLC                   ;229B  18
     ADC  #$17             ;229C  69 17
     STA   CurrentFileInfoBuff             ;229E  85 D0
     BCC   label45           ;22A0  90 02
     INC   CurrentFileInfoBuff+1             ;22A2  E6 D1
label45
     JMP   label46           ;22A4  4C 65 22
; znaleziono plik z dlugimi nazwami
DATfileFound
     ; numer pierwszego sektora mapy sektorow pliku MSDOS.DAT przepisujemy na
	 ; poczatek bufora na sektor mapy. Dzieki temu przy skoku do procedury czytania
	 ; nastepnego sektora mapy, przeczyta sie wlasnie ten pierwszy
     LDY  #$01
     LDA  (CurrentFileInfoBuff),Y
     STA   DirMapSect 
     INY
     LDA  (CurrentFileInfoBuff),Y 
     STA   DirMapSect+1
     INY                   ;22B2  C8
     LDA  (CurrentFileInfoBuff),Y          ;22B3  B1 D0
     STA   $D4             ;22B5  85 D4
     INY                   ;22B7  C8
     LDA  (CurrentFileInfoBuff),Y          ;22B8  B1 D0
     STA   $D5             ;22BA  85 D5
     INY                   ;22BC  C8
     LDA  (CurrentFileInfoBuff),Y          ;22BD  B1 D0
     BEQ   label47           ;22BF  F0 06
     LDA  #$FF             ;22C1  A9 FF
     STA   $D4             ;22C3  85 D4
     STA   $D5             ;22C5  85 D5
label47
     LDA   $CC             ;22C7  A5 CC
     STA   CurrentFileInfoBuff             ;22C9  85 D0
     LDA   $CD             ;22CB  A5 CD
     STA   CurrentFileInfoBuff+1             ;22CD  85 D1
     LDA  #$2E             ;22CF  A9 2E
     JSR   label39           ;22D1  20 5C 26
     LDA   CurrentFileInfoBuff             ;22D4  A5 D0
     STA   $CE             ;22D6  85 CE
     LDA   CurrentFileInfoBuff+1             ;22D8  A5 D1
     STA   $CF             ;22DA  85 CF
     INC   $D8             ;22DC  E6 D8
label41
     LDA  #$00             ;22DE  A9 00
     STA   $D6             ;22E0  85 D6
     LDA   CurrentDirBuf             ;22E2  A5 CA
     CLC                   ;22E4  18
     ADC  #$17             ;22E5  69 17
     STA   CurrentFileInfoBuff             ;22E7  85 D0
     LDA   CurrentDirBuf+1             ;22E9  A5 CB
     ADC  #$00             ;22EB  69 00
     STA   CurrentFileInfoBuff+1             ;22ED  85 D1
StatusBarPrint
     JSR   PrintXY           ;22EF  20 88 27
     .BY $00,$00         ;22F2  00
     .BY $7d             ;22F4  7D A0 CD
DensityDisplay
     .BY +$80," D"
DriveDisp1        ;                               "
     .BY +$80,"1: MSDOS 4.2e QMEG:"
QMEGstatus
	 .BY +$80,"OFF/BAS:"
BASstatus
	 .BY +$80,"OFF/US:"
USstatus
	 .BY +$80,"OFF "  ; w inversie
     .BY $00             ;231D  00
     JSR   PrintXY           ;231E  20 88 27
     .BY $01,$16         ;2321  01 16
     .BY +$80,"SPACE"
     .BY ":Continue  "
     .BY +$80,"SHIFT"
     .BY "+...No High Speed"     ;2323  D3
     .BY $00             ;2349  00
     JSR   PrintXY           ;234A  20 88 27
     .BY $02,$17
     .BY +$80,"ESC"
     .BY ":All files  "
     .BY +$80,">"
     .BY ":Main Dir.  "
     .BY +$80,"<"
     .BY ":UP-DIR."
     .BY $00             ;2374  00
     LDA  #$00             ;2375  A9 00
     STA   $D9             ;2377  85 D9
label68
     LDA   CurrentFileInfoBuff+1             ;2379  A5 D1
     CMP   $CD             ;237B  C5 CD
     BCC   label48           ;237D  90 08
     BNE   label49           ;237F  D0 55
     LDA   CurrentFileInfoBuff             ;2381  A5 D0
     CMP   $CC             ;2383  C5 CC
     BCS   label49           ;2385  B0 4F
label48
     LDY  #$00             ;2387  A0 00
     LDA  (CurrentFileInfoBuff),Y          ;2389  B1 D0
     BEQ   label49           ;238B  F0 49
     LDX  #$22             ;238D  A2 22
     LDA  #$20    ; spacja         ;238F  A9 20
label50
     STA   GameName,X         ;2391  9D 34 24
     DEX                   ;2394  CA
     BPL   label50           ;2395  10 FA
     LDY  #$10             ;2397  A0 10
     LDX  #$0A             ;2399  A2 0A
label51
     LDA  (CurrentFileInfoBuff),Y          ;239B  B1 D0
     STA   GameName,X         ;239D  9D 34 24
     DEY                   ;23A0  88
     DEX                   ;23A1  CA
     BPL   label51           ;23A2  10 F7
     LDA   $D9             ;23A4  A5 D9
     CLC                   ;23A6  18
     ADC  #$41   ; literka "A"          ;23A7  69 41
     STA   GameKeySymbol           ;23A9  8D 31 24
     LDA   $D8             ;23AC  A5 D8
     BNE   label52           ;23AE  D0 2C
     LDY  #$00             ;23B0  A0 00
  ; status sprawdzanego pliku
     LDA  (CurrentFileInfoBuff),Y          ;23B2  B1 D0
     AND  #$19             ;23B4  29 19
     CMP  #$09             ;23B6  C9 09
  ; sprawdzamy czy Nie skasowany, zabezpieczony i "w uzyciu"
     BEQ   label53           ;23B8  F0 08
     LDX   $D7             ;23BA  A6 D7
     BEQ   label54           ;23BC  F0 1B
     CMP  #$08             ;23BE  C9 08
     BNE   label54           ;23C0  D0 17
label53
  ; jeszcze raz status sprawdzanego pliku
     LDA  (CurrentFileInfoBuff),Y          ;23C2  B1 D0
     AND  #$20             ;23C4  29 20
  ; sprawdzenie czy to podkatalog jesli nie 'label55' (czyli plik)
     BEQ   label55           ;23C6  F0 0B
  ; obsluga wyswietlenia nazwy podlatalogu (dopisanie "<SUB-DIR>")
     LDX  #$08             ;23C8  A2 08
label56
     LDA   SubDirText,X         ;23CA  BD 0C 25
     STA   GameName+12         ;23CD  9D 40 24
     DEX                   ;23D0  CA
     BPL   label56           ;23D1  10 F7
label55
     JMP   GameNamePrint           ;23D3  4C 24 24
label49
     JMP   label58           ;23D6  4C BF 24
label54
     JMP   label59           ;23D9  4C 7C 24
label52
     LDY  #$00             ;23DC  A0 00
     LDA  (CurrentFileInfoBuff),Y          ;23DE  B1 D0
     AND  #$18             ;23E0  29 18
     CMP  #$08             ;23E2  C9 08
     BNE   label54           ;23E4  D0 F3
     LDA   $CC             ;23E6  A5 CC
     STA   $D4             ;23E8  85 D4
     LDA   $CD             ;23EA  A5 CD
     STA   $D5             ;23EC  85 D5
label65
     LDA   $D5             ;23EE  A5 D5
     CMP   $CF             ;23F0  C5 CF
     BCC   label60           ;23F2  90 08
     BNE   label54           ;23F4  D0 E3
     LDA   $D4             ;23F6  A5 D4
     CMP   $CE             ;23F8  C5 CE
     BCS   label54           ;23FA  B0 DD
; Porownanie nazwy pliku do wyswietlenia z nazwa z MSDOS.DAT
label60
     LDY  #$0A      ; 8+3 znaki
Checking62
     LDA  ($D4),Y 
     CMP   GameName,Y 
     BNE   CheckNextName  ; jesli to nie ta nazwa sprawdzamy nastepna z bufora dlugich nazw
     DEY
     BPL   Checking62
; Wpisanie nazwy "ekranowej" zamiast nazwy pliku
     LDY  #$0B     ; przesuniecie o 11 bajtow zeby ominac nazwe DOSowa pliku
ReplacingName
     LDA  ($D4),Y 
     STA   GameName-$0B,Y  ; nadpisujemy nazwe pliku w buforze wyswietlania
     INY 
     CPY  #$2E
     BCC   ReplacingName
     BCS   GameNamePrint           ;2414  B0 0E
CheckNextName
     LDA   $D4             ;2416  A5 D4
     CLC                   ;2418  18
     ADC  #$2E             ;2419  69 2E
     STA   $D4             ;241B  85 D4
     BCC   label64           ;241D  90 02
     INC   $D5             ;241F  E6 D5
label64
     JMP   label65           ;2421  4C EE 23
GameNamePrint
     LDA   $D9             ;2424  A5 D9
     CLC                   ;2426  18
     ADC  #$02             ;2427  69 02
     STA   YposGameName           ;2429  8D 30 24
     JSR   PrintXY           ;242C  20 88 27
     .BY $01             ;242F  01
YposGameName
     .BY $02
GameKeySymbol
     .BY "A) "            ;2431  41 29 20
GameName
     .BY "                                   "           ;2434  20 20 20
     .BY $00             ;2457  00
     LDA   $D9             ;2458  A5 D9
     ASL                ;245A  0A
     TAX                   ;245B  AA
     LDA   CurrentFileInfoBuff             ;245C  A5 D0
     STA   FirstSectorsTable,X         ;245E  9D CA 28
     LDA   CurrentFileInfoBuff+1             ;2461  A5 D1
     STA   FirstSectorsTable+1,X         ;2463  9D CB 28
     LDA   CurrentFileInfoBuff             ;2466  A5 D0
     CLC                   ;2468  18
     ADC  #$17             ;2469  69 17
     STA   CurrentFileInfoBuff             ;246B  85 D0
     BCC   label66           ;246D  90 02
     INC   CurrentFileInfoBuff+1             ;246F  E6 D1
label66
     INC   $D9             ;2471  E6 D9
     LDA   $D9             ;2473  A5 D9
     CMP  #$13             ;2475  C9 13
     BCS   ContArrowsPrint    ; jest wiecej plikow niz sie zmiescilo na ekranie
     JMP   label68           ;2479  4C 79 23
label59
     LDA   CurrentFileInfoBuff             ;247C  A5 D0
     CLC                   ;247E  18
     ADC  #$17             ;247F  69 17
     STA   CurrentFileInfoBuff             ;2481  85 D0
     BCC   label69           ;2483  90 02
     INC   CurrentFileInfoBuff+1             ;2485  E6 D1
label69
     JMP   label68           ;2487  4C 79 23
MainDirKEY
     JMP   ReadMainDir           ;248A  4C 0E 22
UpDirKEY
     LDY  #$02             ;248D  A0 02
     LDA  (CurrentDirBuf),Y          ;248F  B1 CA
     TAX                   ;2491  AA
     DEY                   ;2492  88
     ORA  (CurrentDirBuf),Y          ;2493  11 CA
     BEQ   KeyboardProc           ;2495  F0 2A
     LDA  (CurrentDirBuf),Y          ;2497  B1 CA
     TAY                   ;2499  A8
     JMP   ReadDIR           ;249A  4C 34 22
EscKEY
     LDX  #$00             ;249D  A2 00
     STX   $D8             ;249F  86 D8
     INX                   ;24A1  E8
     STX   $D7             ;24A2  86 D7
label70
     JMP   label41           ;24A4  4C DE 22
SpaceKEY
     LDA   $D6             ;24A7  A5 D6
     BNE   label70           ;24A9  D0 F9
     JMP   StatusBarPrint
; Wyswietlenie strzalek pokazujacych ze jest wiecej plikow niz miesci sie na ekranie
ContArrowsPrint
     JSR   PrintXY
     .BY $01,$15
     .BY $1D		; strzalka w dol
     .BY $00
     JSR   PrintXY
     .BY $0E,$15
     .BY $1D		; strzalka w dol
     .BY $00
     JMP   KeyboardProc
label58
     INC   $D6             ;24BF  E6 D6
KeyboardProc
     JSR   GetKey   
     CMP  #$3E  ; ">"           ;24D5  C9 3E
     BEQ   MainDirKEY           ;24D7  F0 B1
     CMP  #$3C  ; "<"           ;24D9  C9 3C
     BEQ   UpDirKEY           ;24DB  F0 B0
     CMP  #$1B  ; Esc           ;24DD  C9 1B
     BEQ   EscKEY           ;24DF  F0 BC
     CMP  #$20  ; Spacja           ;24E1  C9 20
     BEQ   SpaceKEY           ;24E3  F0 C2
     ; ----------------
     ; sprawdzenie klawiszy 1-8
     CMP #'1'
     BCC NoNumber
     CMP #'9'
     BCS NoNumber
     SEC
     SBC #'0'
     JSR SeTDriveNR
;     jmp MainDirKEY
     JMP mainprog
     ; -----------------
NoNumber
     SEC                   ;24E5  38
     SBC  #'A'  ; "A"     ; czy klawisz A lub wiekszy
     CMP   $D9              ; czy mniejszy lub r�wny ilo�ci plik�w widocznych na ekranie
     BCS   KeyboardProc    ; jesli spoza zakresu wracamy do czekania na klawisz
     ASL 
     TAX 
     LDA   FirstSectorsTable,X         ;24EE  BD CA 28
     STA   $D4             ;24F1  85 D4
     LDA   FirstSectorsTable+1,X         ;24F3  BD CB 28
     STA   $D5             ;24F6  85 D5
     LDY  #$00             ;24F8  A0 00
     LDA  ($D4),Y          ;24FA  B1 D4
     AND  #$20             ; sprawdzamy czy to klatalog czy plik
     BEQ   GOtoLoader     ; jesli plik to skaczemy do pracedury przygotowujacej loader
     ; a jesli katalog, pobieramy poczatek jego mapy sektorow i odczytujemy go na ekran
     LDY  #$02             ;2500  A0 02
     LDA  ($D4),Y          ;2502  B1 D4
     TAX                   ;2504  AA
     DEY                   ;2505  88
     LDA  ($D4),Y          ;2506  B1 D4
     TAY                   ;2508  A8
     JMP   ReadDIR           ;2509  4C 34 22
SubDirText
     .BY "<SUB-DIR>"    ;250C  3C
GOtoLoader
     JSR   DiscChangeCheck   ; Sprawdzenie czy w miedzyczasie nie zostala zmieniona dyskietka
     BEQ   DiskNotChanged1
     JMP   ReadMainDir        ; jesli zmieniono to skok na poczatek programu i ponowny odczyt katalogu glownego
DiskNotChanged1
     LDA   SKSTAT   ; jesli jest Shift to odpowiednio ustawiamy flage przed samym zaladowaniem pliku !!!
	 and   #$08
     BNE   NoSHIFT
     STA   USmode  ; tutaj mamy 0 w A wiec nie potrzeba LDA #0
NoSHIFT
     LDY  #$01             ;251D  A0 01
     LDA  ($D4),Y          ;251F  B1 D4
     STA   .adr loader.FirstMapSectorNr	; przed przepisaniem
	 sta  blokDanychIO5+$A   ; od razu do bloku IOCB
     INY                   ;2524  C8
     LDA  ($D4),Y          ;2525  B1 D4
     STA   .adr loader.FirstMapSectorNr+1	; przed przepisaniem
	 sta  blokDanychIO5+$B   ; od razu do bloku IOCB
     INY                   ;252A  C8
     LDA  ($D4),Y          ;252B  B1 D4
     EOR  #$FF             ;252D  49 FF
     STA   .adr loader.tempToFileEndL           ;252F  8D 52 21
     INY                   ;2532  C8
     LDA  ($D4),Y          ;2533  B1 D4
     EOR  #$FF             ;2535  49 FF
     STA   .adr loader.ToFileEndH	; przed przepisaniem
     INY                   ;253A  C8
     LDA  ($D4),Y          ;253B  B1 D4
     EOR  #$FF             ;253D  49 FF
     STA   .adr loader.ToFileEndH+1	; przed przepisaniem
; wszystko zapamietane mozna robic mape sektorow....
; skompresowana mapa bedzie tworzona w buforze sektora katalogu
; czyli DirSectorBuff
; sektor mapy przed kompresja leci do DirMapSectorBuff
; UWAGA
; Zeby dzialala ta ladna procedura Bernaska mapa na poczatku musi
; zawierac rozkaz przeczytania pierwszego sektora!!!!!
CompressedMap = DirSectorBuff
; czytamy pierwszy sektor mapy
	 LDY #<DirMapSectorBuff
     LDX #>DirMapSectorBuff
	 Jsr ReadSector
; pobieramy numer pierwszego sektora pliku i od razu robimy wpis w mapie !!!
     LDA #00
	 STA CompressedMapCounter
	 STA CompressedMapCounter+1
	 JSR AddToCompressedMAP
     LDA DirMapSectorBuff+4
	 STA PrevFileSector
	 JSR AddToCompressedMAP
     LDA DirMapSectorBuff+5
	 sta PrevFileSector+1
	 JSR AddToCompressedMAP
 ; Inicjujemy liczniki
    .zpvar MapCounter,CompressedMapCounter, MapCounterMem .word =$80
	.zpvar PrevFileSector, MapPositionMem .word
	.zpvar SectorOffset .word
	.zpvar SectorsCounter .byte
     LDA #$00
	 STA MapCounter+1
	 STA SectorsCounter
	 lda #$06
	 STA MapCounter
GenerateCompressedMap
     CLC
	 LDA #<DirMapSectorBuff
	 ADC MapCounter
	 STA MAPPositionMem
	 LDA #>DirMapSectorBuff
	 ADC MapCounter+1
	 STA MAPPositionMem+1
	 LDX #0
	 LDY #1
 	 LDA (MAPPositionMem,x)
     ORA (MAPPositionMem),y
	 BEQ Sector00
	 SEC
	 LDA (MAPPositionMem,x)
	 SBC PrevFileSector
	 STA SectorOffset
	 LDA (MAPPositionMem),y
	 SBC PrevFileSector+1
	 STA SectorOffset+1
	 ; mamy odstep miedzy poprzednim a nastepnym sektorem
     BNE OffsetToBig
	 LDA SectorOffset
	 CMP #$FF
	 BEQ OffsetToBig
     CMP #$01
	 BNE JumpForward
	 ; kolejny sektor
	 ; zwiekszamy wiec licznik
	 inc SectorsCounter
	 LDA SectorsCounter
	 CMP #%01111111
	 BNE GetNextMapWord
	 ; tu licznik dotarl do konca zerujemy go
	 ; dodajemy wpis do skompresowanej mapy i gotowe
	 JSR AddToCompressedMAP
	 LDA #0
	 STA SectorsCounter
	 BEQ GetNextMapWord
; ominiecie wyznaczonej ilo�ci sektor�w (w A)
JumpForward
     JSR FlushBuffer
     LDA SectorOffset
	 BPL LessThen128
	 LDA #$FF
	 JSR AddToCompressedMAP
	 LDA SectorOffset
	 SEC
	 SBC #%01111111
LessThen128
	 ORA #%10000000
	 JSR AddToCompressedMAP
     JMP GetNextMapWord
; wyznaczenie skoku do nowego sektora pliku
OffsetToBig
     JSR FlushBuffer
     LDA #0
	 JSR AddToCompressedMAP
	 LDY #00
	 LDA (MAPPositionMem),y
	 JSR AddToCompressedMAP
     LDY #01
	 LDA (MAPPositionMem),y
	 JSR AddToCompressedMAP
GetNextMapWord
 ; zapamietanie numeru obecnego sektora do porownania potem	 
	 LDY #00
	 LDA (MAPPositionMem),y
	 STA PrevFileSector
     INY
	 LDA (MAPPositionMem),y
	 STA PrevFileSector+1
Sector00
     ADW MapCounter #2
ops01
     ; CPW MapCounter {.adr loader.SecLen}   ; a to nie dziala
	 LDA MapCounter+1
	 CMP .adr loader.SecLen+1
	 bne noteqal01
	 LDA MapCounter
	 CMP .adr loader.SecLen	 
noteqal01
     JNE GenerateCompressedMap
; czytamy nastepny sektor mapy
     ; sprawdzmy czy nie koniec
     LDA DirMapSectorBuff
     ORA DirMapSectorBuff+1
	 BEQ EndMakingMap
     LDA DirMapSectorBuff
	 sta  blokDanychIO5+$A
	 LDA DirMapSectorBuff+1
	 sta  blokDanychIO5+$B
	 LDY #<DirMapSectorBuff
     LDX #>DirMapSectorBuff
	 Jsr ReadSector
	 ; zerujemy licznik mapy
     LDA #$00
	 STA MapCounter+1
	 lda #$04
	 STA MapCounter
     JMP GenerateCompressedMap
; dpisanie bajtu z A do mapy sektorow skompresowanej
AddToCompressedMAP
     PHA
	 ; wyliczamy adresa
	 CLC
	 LDA CompressedMapCounter
     ;ADC #00
	 ADC #<CompressedMap
	 STA xxxxbla
	 LDA CompressedMapCounter+1
	 ;ADC #$80
	 ADC #>CompressedMap
	 STA xxxxbla+1
	 PLA
xxxxbla=*+1
	 STA $FFFF
	 INC CompressedMapCounter
	 BNE noinc013
	 INC CompressedMapCounter+1
noinc013
     RTS
FlushBuffer
     LDA SectorsCounter
	 BEQ NoFlush
	 JSR AddToCompressedMAP
	 LDA #0
     STA SectorsCounter
NoFlush
     RTS
EndMakingMap
     JSR FlushBuffer
     LDA  #$00             ;2542  A9 00
     STA   COLDST          ;2544  8D 44 02
     LDA  #$02             ;2547  A9 02
     STA   BOOT            ;2549  85 09
     STA   $03F8           ;254B  8D F8 03
     LDA  #<AfterWormStart             ;254E  A9 65
     STA   CASINI          ;2550  85 02
     LDA  #>AfterWormStart             ;2552  A9 25
     STA   CASINI+1        ;2554  85 03
     LDA  #>JRESETCD         ;2556  A9 E4
     STA   DOSVEC+1        ;2558  85 0B
     STA   DOSINI+1        ;255A  85 0D
     LDA  #<JRESETCD         ;255C  A9 77
     STA   DOSVEC          ;255E  85 0A
     STA   DOSINI          ;2560  85 0C
     JMP   JRESETWM        ; wymuszenie cieplego resetu - z ustawionymi odpowiednimi prametrami powrotu
AfterWormStart
     ; wyznaczamy MEMlo, najpierw dodajemy dlugosc bufora na sektor
	 ; do koncowego adresu naszej procedury
	 CLC
     LDA   #<TempMEMLO
	 ADC   .adr loader.SecLen
     STA   MEMLO
	 STA   CompressedMapPos
	 STA   pointerMov2b-1   ; przygotowanie procedury przepisujacej
     STA   APPMHI           ; wlasciwie tu powinno byc to samo co po pozniejszym zwiekszeniu MEMLO !!!!
     LDA   #>TempMEMLO
     ADC   .adr loader.SecLen+1
     STA   MEMLO+1
	 STA   CompressedMapPos+1
	 STA   pointerMov2b
     STA   APPMHI+1
	 ; tu w MEMLO mamy pierwszy wolny bajt za buforem sektora
	 ; jest to jednoczesnie adres umieszczenia skompresowanej
	 ; mapy sektorow pliku dla loadera ale MINUS 1
	 DEW   CompressedMapPos
	 ; teraz trzeba dodac dlugosc skompresowanej mapy bitowej
	 ; i wpisac w procedurze przepisujacej turbo (modyfikacja kodu)
	 CLC
	 LDA MEMLO
	 ADC CompressedMapCounter
	 STA MEMLO
	 STA TurboRelocADDR
	 LDA MEMLO+1
	 ADC CompressedMapCounter+1
	 STA MEMLO+1
	 STA TurboRelocADDR+1
     LDA  #<JRESETCD         ;2575  A9 77
     STA   CASINI          ;2577  85 02
     LDA  #>JRESETCD         ;2579  A9 E4
     STA   CASINI+1        ;257B  85 03
     INC   $033D           ;257D  EE 3D 03
     INC   $033E           ;2580  EE 3E 03
     DEC   $033F           ;2583  CE 3F 03
     LDX  #$00             ;2586  A2 00
	 STX   BOOT
; przepisanie glownej procedury ladujacej - DWIE STRONY pamieci
moveloop1
     LDA   movedproc,X         ;2588  BD 00 20
     STA   $0700,X         ;258B  9D 00 07
     LDA   movedproc+$0100,X         ;258E  BD 00 21
     STA   $0800,X         ;2591  9D 00 08
     INX                   ;2594  E8
     BNE   moveloop1           ;2595  D0 F1
; przepisanie skompresowanej mapy sektorow pliku za bufor sektora
moveloop2
     DEW   CompressedMapCounter    ; zmiejszamy licznik dlugasci mapy
pointerMov2a=*+2
	 LDA   CompressedMap,x     ; kod samomodyfikujacy sie
pointerMov2b=*+2
     STA   $FFFF,x              ; kod samomodyfikujacy sie
	 LDA   CompressedMapCounter
	 AND   CompressedMapCounter+1
     CMP   #$FF                      ; jesli licznik = -1 to przepisalismy cala mape !!!
	 BEQ   SectorMapReady
  	 INX
	 BNE   moveloop2
	 inc   pointerMov2a
	 inc   pointerMov2b
	 bne   moveloop2 
SectorMapReady
     LDX  #$00
     TXA
; wstepne czyszczenie (reszte RAM czysci procedura ladujaca - dzieki czemu czysci tez program glowny)
ClearLoop1
     STA   $0100,X 		; STOS !!!
     STA   $0400,X			; bufor magnetofonu (128) i obszar zarezerwowany?? (drugie 128b)
     STA   $0500,X 
     STA   $0600,X 
     CPX  #$80             ;tylko ponad $80
     BCC   NoZpage
     STA   $00,X           ; czyli polowa strony zerowej
NoZpage
     INX
     BNE   ClearLoop1
     LDX  #$FF
     TXS 					; "wyzerowanie wskaznika STOSU
	 
     JSR   ADDspeedProc   ; procedura relokujaca procedury turbo (jesli potrzebne) i podnaszaca odpowiednio MEMLO
	 JSR   MEMLOprint     ; wyswietlenie wartosci MEMLO (moze wyswietlac i inne rzeczy)
     JMP   loader.LoadStart     ; po przepisaniu 
; Sprawdzenie odpowiednich flag i przepisanie za loaderem procedury obslugi odpowiedniego Turba
; na koniec odpowiednie zmodyfikowanie MEMLO
ADDspeedProc
     LDA   USmode
	 beq   NoHappyLoader
; wyznaczamy offset procedury
    SEC
	LDA #<HappyUSMovedProc
	SBC MEMLO
	STA HappyOffset
	LDA #>HappyUSMovedProc
	SBC MEMLO+1
	STA HappyOffset+1

	LDY #0
	LDX #[$A-1]  ;xjsrA - the last
	; relokujemy skoki pod offset z MEMLO
HappyRelocate
	SEC
	LDA xjsrTableL,x
	STA SecBuffer
	LDA xjsrTableH,x
	STA SecBuffer+1
	LDA (SecBuffer),y
	SBC HappyOffset
	STA (SecBuffer),y
	INY
	LDA (SecBuffer),y
	SBC HappyOffset+1
	STA (SecBuffer),y
	DEY
	DEX
	BPL HappyRelocate

     LDX  #[EndHappyUSProc-HappyUSMovedProc-1]
label72x
     LDA   HappyUSMovedProc,X
TurboRelocADDR=*+1
     STA   $0A00,X
     DEX
	 CPX #$FF
     BNE   label72x
   LDY   #[EndHappyUSProc-HappyUSMovedProc]
     LDX   #$00
; Zwiekszenie Memlo o dlugosc procedury i przelaczenie skoku do niej.
label73
     TYA                   ;25F2  98
     CLC                   ;25F3  18
     ADC   MEMLO           ;25F4  6D E7 02
     STA   MEMLO           ;25F7  8D E7 02
     TXA                   ;25FA  8A
     ADC   MEMLO+1         ;25FB  6D E8 02
     STA   MEMLO+1         ;25FE  8D E8 02
     LDA   TurboRelocADDR
     STA   loader.SioJMP+1               ; po przepisaniu
     LDA   TurboRelocADDR+1
     STA   loader.SioJMP+2             ; po przepisaniu
NoHappyLoader
     RTS                   ;260B  60



; UWAGA !!!!!!!!!!!!!!
; Ta procedura ma maksymalna dlugosc jaka moze miec!!!!!
; powiekszenie jej O BAJT spowoduje ze przekroczy strone
; i nie przepisze sie prawidlowo na swoje miejsce !!!!!	 
HappyUSMovedProc ;

	LDA DBUFA
	STA SecBuffer
	LDA DBUFA+1
	STA SecBuffer+1

	LDA DBYT
	STA SecLenUS

	SEI
	TSX
	STX StackCopy
	LDA #$0D
	STA CRETRYZ
	 ;command retry on zero page
CommandLoop
HappySpeed = *+1
	LDA #$28 ;here goes speed from "?"
	STA AUDF3
	LDA #$34
	STA PBCTL ;ustawienie linii command
	LDX #$80
DelayLoopCmd
	DEX
	BNE DelayLoopCmd
	STX AUDF4 ; zero
;	STX CheckSum   ; ------------------- nie potrzebne !!!!!
	STX TransmitError
;	pokey init
	LDA #$23
xjsr1	JSR SecTransReg
	;

	CLC
	LDA DDEVIC    ; tu zawsze jest $31 (przynajmniej powinno)
	ADC DUNIT     ; dodajemy numer stacji
	ADC #$FF	; i odejmujemy jeden (jak w systemie Atari)
	STA CheckSum
	STA SEROUT
	LDA DCOMND
xjsr2	JSR PutSIOByte
	LDA DAUX1
xjsr3	JSR PutSIOByte
	LDA DAUX2
xjsr4	JSR PutSIOByte
	LDA CheckSum
xjsr5	JSR PutSIOByte

waitforEndOftransmission
	LDA IRQST
	AND #$08
	BNE waitforEndOftransmission

	LDA #$13
xjsr6	JSR SecTransReg

	LDA #$3c
	STA PBCTL ;command line off
; two ACK's
	LDY #2
DoubleACK
xjsr7	JSR GetSIOByte
	CMP #$44
	BCS ErrorHere
	DEY
	BNE DoubleACK

	;ldy #0
	STY CheckSum
ReadSectorLoop
xjsr8	JSR GetSIOByte
	STA (SecBuffer),y
xjsr9	JSR AddCheckSum
	INY
	CPY SecLenUS
	BNE ReadSectorLoop

xjsrA	JSR GetSIOByte
	CMP CheckSum
	BEQ EndOfTransmission
;error!!!
ErrorHere
	LDY #$90
	STY TransmitError
	LDX StackCopy
	TXS
	DEC CRETRYZ
	BNE CommandLoop

EndOfTransmission
	LDA #0
	STA AUDC4
	LDA IRQENS
	STA IRQEN
	CLI
	LDY TransmitError
	RTS

SecTransReg
	STA SKCTL
	STA SKSTRES
	LDA #$38
	STA IRQEN
	LDA #$28
	STA AUDCTL
	LDA #$A8
	STA AUDC4
	RTS

PutSIOByte
	TAX
waitforSerial
	LDA IRQST
	AND #$10
	BNE waitforSerial

	STA IRQEN
	LDA #$10
	STA IRQEN

	TXA
	STA SEROUT

AddCheckSum
	CLC
	ADC CheckSum
	ADC #0
	STA CheckSum
	RTS

GetSIOByte
	LDX #10  ;acktimeout
ExternalLoop
	LDA #0
	STA looperka
InternalLoop
	LDA IRQST
	AND #$20
	BEQ ACKReceive
	DEC looperka
	BNE InternalLoop
	DEX
	BNE ExternalLoop
	BEQ ErrorHere
ACKReceive
	; zero we have now
	STA IRQST
	LDA #$20
	STA IRQST
	LDA SKSTAT
	STA SKSTRES
	AND #$20
	BEQ ErrorHere
	;
	LDA SERIN
	RTS
EndHappyUSProc


; Rockaz DCB "?" pobierrajacy predkosc dla Happy i US-Doubler
blokDanychIO6
     .BY $31,$01,"?",$40
     .WO HappySpeed
     .BY $07,$00,$01,$00,$00,$0A
DirMapEnd
     JMP   label75           ;2659  4C 0D 27
label39
     STA   $DA             ;265C  85 DA
     LDA   CurrentFileInfoBuff             ;265E  A5 D0
     STA   $DB             ;2660  85 DB
     LDA   CurrentFileInfoBuff+1             ;2662  A5 D1
     STA   $DC             ;2664  85 DC
     JSR   DiscChangeCheck   ; Sprawdzenie czy w miedzyczasie nie zostala zmieniona dyskietka
     BEQ   DiscNotChanged2           ;2669  F0 05
     PLA                   ;266B  68
     PLA                   ;266C  68
     JMP   ReadMainDir           ;266D  4C 0E 22
DiscNotChanged2
     LDA   DirMapSect             ;2670  A5 D2
     STA   blokDanychIO5+10           ;2672  8D 85 27
     LDA   DirMapSect+1             ;2675  A5 D3
     STA   blokDanychIO5+11           ;2677  8D 86 27
     ORA   blokDanychIO5+10          ;267A  0D 85 27
     BEQ   DirMapEnd           ;267D  F0 DA
     LDX  #>DirMapSectorBuff            ;267F  A2 29
     LDY  #<DirMapSectorBuff             ;2681  A0 80
     JSR   ReadSector           ;2683  20 48 27
     LDA   DirMapSectorBuff           ;2686  AD 80 29
     STA   DirMapSect             ;2689  85 D2
     LDA   DirMapSectorBuff+1           ;268B  AD 81 29
     STA   DirMapSect+1             ;268E  85 D3
     LDA  #$04             ;2690  A9 04
     STA   $D6             ;2692  85 D6
label80
     LDX   $D6             ;2694  A6 D6
     CPX   .adr loader.SecLen	; przed przepisaniem
     BEQ   DiscNotChanged2           ;2699  F0 D5
     LDA   DirMapSectorBuff,X         ;269B  BD 80 29
     STA   blokDanychIO5+10           ;269E  8D 85 27
     LDA   DirMapSectorBuff+1,X         ;26A1  BD 81 29
     STA   blokDanychIO5+11           ;26A4  8D 86 27
     ORA   blokDanychIO5+10           ;26A7  0D 85 27
     BEQ   label75           ;26AA  F0 61
     INX                   ;26AC  E8
     INX                   ;26AD  E8
     STX   $D6             ;26AE  86 D6
     LDA   MEMTOP          ;26B0  AD E5 02
     SEC                   ;26B3  38
     SBC   CurrentFileInfoBuff             ;26B4  E5 D0
     LDA   MEMTOP+1        ;26B6  AD E6 02
     SBC   CurrentFileInfoBuff+1             ;26B9  E5 D1
     BEQ   label75           ;26BB  F0 50
     LDY   CurrentFileInfoBuff             ;26BD  A4 D0
     LDX   CurrentFileInfoBuff+1             ;26BF  A6 D1
     JSR   ReadSector           ;26C1  20 48 27
     LDA   $D4             ;26C4  A5 D4
     ORA   $D5             ;26C6  05 D5
     BNE   label79           ;26C8  D0 16
     LDY  #$03             ;26CA  A0 03
     LDA  (CurrentFileInfoBuff),Y          ;26CC  B1 D0
     STA   $D4             ;26CE  85 D4
     INY                   ;26D0  C8
     LDA  (CurrentFileInfoBuff),Y          ;26D1  B1 D0
     STA   $D5             ;26D3  85 D5
     INY                   ;26D5  C8
     LDA  (CurrentFileInfoBuff),Y          ;26D6  B1 D0
     BEQ   label79           ;26D8  F0 06
     LDA  #$FF             ;26DA  A9 FF
     STA   $D4             ;26DC  85 D4
     STA   $D5             ;26DE  85 D5
label79
     LDA   CurrentFileInfoBuff             ;26E0  A5 D0
     CLC                   ;26E2  18
     ADC   .adr loader.SecLen	; przed przepisaniem
     STA   CurrentFileInfoBuff             ;26E6  85 D0
     LDA   CurrentFileInfoBuff+1             ;26E8  A5 D1
     ADC   .adr loader.SecLen+1	; przed przepisaniem
     STA   CurrentFileInfoBuff+1             ;26ED  85 D1
     LDA   $D4             ;26EF  A5 D4
     SEC                   ;26F1  38
     SBC   .adr loader.SecLen	; przed przepisaniem
     STA   $D4             ;26F5  85 D4
     LDA   $D5             ;26F7  A5 D5
     SBC   .adr loader.SecLen+1	; przed przepisaniem
     STA   $D5             ;26FC  85 D5
     BCS   label80           ;26FE  B0 94
     LDA   CurrentFileInfoBuff             ;2700  A5 D0
     CLC                   ;2702  18
     ADC   $D4             ;2703  65 D4
     STA   CurrentFileInfoBuff             ;2705  85 D0
     LDA   CurrentFileInfoBuff+1             ;2707  A5 D1
     ADC   $D5             ;2709  65 D5
     STA   CurrentFileInfoBuff+1             ;270B  85 D1
label75
     LDA   $DC             ;270D  A5 DC
     CMP   CurrentFileInfoBuff+1             ;270F  C5 D1
     BCC   label81           ;2711  90 0B
     BNE   label82          ;2713  D0 17
     LDA   $DB             ;2715  A5 DB
     CMP   CurrentFileInfoBuff             ;2717  C5 D0
     BCC   label81           ;2719  90 03
     BNE   label82           ;271B  D0 0F
     RTS                   ;271D  60
label81
     LDA   $DB             ;271E  A5 DB
     CLC                   ;2720  18
     ADC   $DA             ;2721  65 DA
     STA   $DB             ;2723  85 DB
     BCC   label75           ;2725  90 E6
     INC   $DC             ;2727  E6 DC
     JMP   label75           ;2729  4C 0D 27
label82
     LDA   $DB             ;272C  A5 DB
     SEC                   ;272E  38
     SBC   $DA             ;272F  E5 DA
     STA   CurrentFileInfoBuff             ;2731  85 D0
     LDA   $DC             ;2733  A5 DC
     SBC  #$00             ;2735  E9 00
     STA   CurrentFileInfoBuff+1             ;2737  85 D1
     RTS                   ;2739  60
; wczytuje pierwszy sektor dysku pod adres zawarty w X(starszy) i Y(mlodszy)
ReadFirstSect
     LDA  #$01             ;273A  A9 01
     STA   blokDanychIO5+10           ;273C  8D 85 27
     LDA  #$00             ;273F  A9 00
     STA   blokDanychIO5+11           ;2741  8D 86 27
	 STA   blokDanychIO5+9		; --- obsluga sektorow ponad 256b
     LDA  #$80             ;2744  A9 80
     BNE   ReadSectorA           ;2746  D0 03
; Wczytuje sektror ustalajac jego dlugosc na podstawie blokDanychIO1 (SecLen)
; reszta danych jak nizej (A nie wazne)
ReadSector
     LDA   .adr loader.SecLen+1		; --- obsluga sektorow ponad 256b
	 STA   blokDanychIO5+9			; --- obsluga sektorow ponad 256b
     LDA   .adr loader.SecLen	; przed przepisaniem
; Wczytuje sektor (numer musi byc juz podany w blokDanychIO5 !!)
; o dlugosci A($00 lub $80) pod adres X(starszy) Y(mlodszy)
ReadSectorA
     STA   blokDanychIO5+8            ;274B  8D 83 27
     STX   blokDanychIO5+5           ;274E  8E 80 27
     STY   blokDanychIO5+4           ;2751  8C 7F 27
     ;LDX  #$00             ;2754  A2 00
     ;LDA   blokDanychIO5+8            ;2756  AD 83 27
     ;BNE   label84           ;2759  D0 01
     ;INX                   ;275B  E8
;label84                    ; to zostalo zrobione wczesniej przez kod do obslugi dluzszych sektorow !!!
     ;STX   blokDanychIO5+9            ;275C  8E 84 27
     LDA  #$04             ;275F  A9 04
     STA   DiskRetryCount           ;2761  8D 87 27
DiskReadRetry
     LDY  #<blokDanychIO5             ;2764  A0 7B
     LDX  #>blokDanychIO5             ;2766  A2 27
     JSR   Table2DCB           ;2768  20 4D 28
     JSR   GoSIO           ;276B  20 18 28
     BMI   label85           ;276E  30 01
     RTS                   ;2770  60
label85
     DEC   DiskRetryCount           ;2771  CE 87 27
     BNE   DiskReadRetry           ;2774  D0 EE
     PLA                   ;2776  68
     PLA                   ;2777  68
     JMP   ErrorDisplay           ;2778  4C D1 21
blokDanychIO5
     .BY $31,$01,$52,$40
     .WO DirMapSectorBuff
     .BY $0A,$00,$80,$00,$01,$00    ;277B  31 01
DiskRetryCount
     .BY $00      ;2787 00
PrintXY
     PLA                   ;2788  68
     STA   $C8             ;2789  85 C8
     PLA                   ;278B  68
     STA   $C9             ;278C  85 C9
     LDA  #$00             ;278E  A9 00
     STA   $DF             ;2790  85 DF
     JSR   label87           ;2792  20 0A 28
     PHA                   ;2795  48
     JSR   label87           ;2796  20 0A 28
     STA   $DE             ;2799  85 DE
     ASL              ;279B  0A
     ASL                  ;279C  0A
     CLC                   ;279D  18
     ADC   $DE             ;279E  65 DE
     ASL                  ;27A0  0A
     ASL                  ;27A1  0A
     ROL   $DF             ;27A2  26 DF
     ASL                  ;27A4  0A
     ROL   $DF             ;27A5  26 DF
     CLC                   ;27A7  18
     ADC   SAVMSC          ;27A8  65 58
     STA   $DE             ;27AA  85 DE
     LDA   $DF             ;27AC  A5 DF
     ADC   SAVMSC+1        ;27AE  65 59
     STA   $DF             ;27B0  85 DF
     PLA                   ;27B2  68
     TAY                   ;27B3  A8
label92
     JSR   label87           ;27B4  20 0A 28
     CMP  #$00             ;27B7  C9 00
     BEQ   label88           ;27B9  F0 48
     CMP  #$7D             ;27BB  C9 7D
     BEQ   label89           ;27BD  F0 21
     LDX  #$00             ;27BF  A2 00
     STX   $E0             ;27C1  86 E0
     CMP  #$80             ;27C3  C9 80
     ROR   $E0             ;27C5  66 E0
     AND  #$7F             ;27C7  29 7F
     CMP  #$20             ;27C9  C9 20
     BCS   label90           ;27CB  B0 04
     ORA  #$40             ;27CD  09 40
     BNE   label91           ;27CF  D0 07
label90
     CMP  #$60             ;27D1  C9 60
     BCS   label91           ;27D3  B0 03
     SEC                   ;27D5  38
     SBC  #$20             ;27D6  E9 20
label91
     ORA   $E0             ;27D8  05 E0
     STA  ($DE),Y          ;27DA  91 DE
     INY                   ;27DC  C8
     JMP   label92           ;27DD  4C B4 27
label89
     TYA                   ;27E0  98
     PHA                   ;27E1  48
     LDA   SAVMSC          ;27E2  A5 58
     STA   $E0             ;27E4  85 E0
     LDA  #$03             ;27E6  A9 03
     TAX                   ;27E8  AA
     CLC                   ;27E9  18
     ADC   SAVMSC+1        ;27EA  65 59
     STA   $E1             ;27EC  85 E1
     LDY  #$BF             ;27EE  A0 BF
     LDA  #$00             ;27F0  A9 00
label93
     STA  ($E0),Y          ;27F2  91 E0
     DEY                   ;27F4  88
     CPY  #$FF             ;27F5  C0 FF
     BNE   label93           ;27F7  D0 F9
     DEC   $E1             ;27F9  C6 E1
     DEX                   ;27FB  CA
     BPL   label93           ;27FC  10 F4
     PLA                   ;27FE  68
     TAY                   ;27FF  A8
     JMP   label92           ;2800  4C B4 27
label88
     LDA   $C9             ;2803  A5 C9
     PHA                   ;2805  48
     LDA   $C8             ;2806  A5 C8
     PHA                   ;2808  48
     RTS                   ;2809  60
label87
     INC   $C8             ;280A  E6 C8
     BNE   label94           ;280C  D0 02
     INC   $C9             ;280E  E6 C9
label94
     LDX  #$00             ;2810  A2 00
     LDA  ($C8,X)          ;2812  A1 C8
     RTS                   ;2814  60
GoErrorDisp
     JMP   ErrorDisplay           ;2815  4C D1 21
; Skok do Sio lub procedury Turbo
GoSIO
     LDY  USmode
     BEQ  StandardSpeed
     JMP  HappyUSMovedProc ; mozna skakac do tej procki
StandardSpeed
     JMP   JSIOINT            ;281D  4C 59 E4
; Przepisuje 12 bajtow z adresy podanego w X(starszy) i Y(mlodszy)
; do bloku kontroli transmisji szeregowej DCB
Table2DCB
     STY   IOtableAddr+1           ;284D  8C 56 28
     STX   IOtableAddr+2           ;2850  8E 57 28
     LDX  #$0B             ;2853  A2 0B
IOtableAddr
     LDA   $FFFF,X         ;2855  BD FF FF
     STA   DDEVIC,X        ;2858  9D 00 03
     DEX                   ;285B  CA
     BPL   IOtableAddr           ;285C  10 F7
     RTS                   ;285E  60
Close1
     LDX  #$10             ;285F  A2 10
CloseX
     LDA  #$0C             ;2861  A9 0C
     STA   ICCMD,X        ;2863  9D 42 03
     JMP   JCIOMAIN            ;2866  4C 56 E4
GetKey
     LDX  #$10             ;2869  A2 10
     LDA  #$03             ;286B  A9 03
     STA   ICCMD,X        ;286D  9D 42 03
     LDA  #$04             ;2870  A9 04
     STA   ICAX1,X        ;2872  9D 4A 03
     LDA  #$00             ;2875  A9 00
     STA   ICAX2,X        ;2877  9D 4B 03
     STA   ICBUFL+1,X        ;287A  9D 49 03
     LDA  #$FF             ;287D  A9 FF
     STA   ICBUFL,X        ;287F  9D 48 03
     LDA  #<Kdriver             ;2882  A9 B0
     STA   ICBUFA,X        ;2884  9D 44 03
     LDA  #>Kdriver             ;2887  A9 28
     STA   ICBUFA+1,X        ;2889  9D 45 03
     JSR   JCIOMAIN            ;288C  20 56 E4
     BMI   GKeyError           ;288F  30 1C
     LDX  #$10             ;2891  A2 10
     LDA  #$00             ;2893  A9 00
     STA   ICBUFL,X        ;2895  9D 48 03
     STA   ICBUFL+1,X        ;2898  9D 49 03
     LDA  #$07             ;289B  A9 07
     STA   ICCMD,X        ;289D  9D 42 03
     JSR   JCIOMAIN            ;28A0  20 56 E4
     BMI   GKeyError           ;28A3  30 08
     PHA                   ;28A5  48
     JSR   Close1           ;28A6  20 5F 28
     BMI   GKeyError           ;28A9  30 02
     PLA                   ;28AB  68
     RTS                   ;28AC  60
GKeyError
     JMP   GoErrorDisp           ;28AD  4C 15 28
Kdriver
     .BY "K:",$9B                  ;28B0  4B
DiscChangeCheck
     LDY  #<DirMapSectorBuff             ;28B3  A0 80
     LDX  #>DirMapSectorBuff             ;28B5  A2 29
     JSR   ReadFirstSect           ;28B7  20 3A 27
     LDX  #$7F             ;28BA  A2 7F
label98
     LDA   FirstSectorBuff,X         ;28BC  BD 00 29
     CMP   DirMapSectorBuff,X         ;28BF  DD 80 29
     BNE   ChangedD           ;28C2  D0 05
     DEX                   ;28C4  CA
     BPL   label98           ;28C5  10 F5
     LDA  #$00             ;28C7  A9 00
ChangedD
     RTS                   ;28C9  60
	 	 
	 ; Ustawia numer satcji wg A
SeTDriveNR
     STA .adr loader.blokDanychIO1+1	; przed przepisaniem
     STA blokDanychIO5+1
     STA blokDanychIO6+1
     CLC
     ADC #'0'+$80
     STA DriveDisp1
     STA DriveDisp2
     JSR PrintXY
     .BY $02,$00
DriveDisp2
     .BY +$80,"1"
     .BY $00
     RTS

; wyswietlenie na czystm ekranie info zaraz przed rozpoczeciem ladowania pliku	 
MEMLOprint
     LDA MEMLO
     PHA 
     LSR 
     LSR 
     LSR
     LSR
     JSR   bin2AsciiHex 
     STA   MEMLOvalue+2
     PLA
     JSR   bin2AsciiHex 
     STA   MEMLOvalue+3
     LDA MEMLO+1
     PHA 
     LSR 
     LSR 
     LSR
     LSR
     JSR   bin2AsciiHex 
     STA   MEMLOvalue
     PLA
     JSR   bin2AsciiHex 
     STA   MEMLOvalue+1
     JSR PrintXY
     .BY 28,23
     .BY "MEMLO: $"
MEMLOvalue
	 .BY "0000"
     .BY $00	 
	 RTS
	 
; Tablica adresow wszystkich rozkazow skokow w procedurze Turbo

xjsrTableL
	.BY <[xjsr1+1],<[xjsr2+1],<[xjsr3+1]
	.BY <[xjsr4+1],<[xjsr5+1]
	.BY <[xjsr6+1],<[xjsr7+1],<[xjsr8+1]
	.BY <[xjsr9+1],<[xjsrA+1]
xjsrTableH
	.BY >[xjsr1+1],>[xjsr2+1],>[xjsr3+1]
	.BY >[xjsr4+1],>[xjsr5+1]
	.BY >[xjsr6+1],>[xjsr7+1],>[xjsr8+1]
	.BY >[xjsr9+1],>[xjsrA+1]
; miejsce na wyliczony offset o jaki przesuwamy procedure
HappyOffset
    .WO $0000
; kody gestosci do wyswietlenia na ekranie - takie poziome kreski od chudej do grubej :)
DensityCodes
	.by +$80,"sdq"
	;.by "SDQ"
    ;.by $0e,$15,$a0
ONtext
    .BY +$80,"ON "
OFFtext
    .BY +$80,"OFF"
; miejsce na tablice trzymajaca numery pierwszych sektorow map bitoeych plikow aktualnie wyswietlanych na liscie
FirstSectorsTable
     ; zostawiamy $30 bajtow wolnego
	 
FirstSectorBuff=[[>[*+$2f]]+1]*$100 ; ($80 bajtow) ustawienie na granicy strony ale po ominieciu $30 bajtoe
ProgramEnd=FirstSectorBuff
DirMapSectorBuff=FirstSectorBuff+$80 ; tutaj aktualny sektor mapy sektorow katalogu
DirSectorBuff=FirstSectorBuff+$280 ; tutaj sektor katalogu
FirstRun
; odnotowujemy stan Shift z Bootowania
     LDA   SKSTAT 
	 and   #$08
     BNE   NoSHIFTboot  
     STA   BootShift   ; w A jest 0 wiec nie trzeba LDA #0
NoSHIFTboot
;  Sprawdzamy czy jest basic i ustawiamy status na ekranie
     LDA PORTB
	 AND #$02
	 BNE BrakBasica
	 ; jest Basic
	 LDY #$2
BASstatprint
	 LDA ONtext,y
	 STA BASstatus,y
	 DEY
	 bpl BASstatprint
BrakBasica	 
;  Sprawdzamy istnienie QMEGa
     ldy #$06  ; bo 6 znak�w w ROMie testujemy
testQMEGloop
	 LDA $C001,y
	 CMP QMEGstring,y
	 bne brakQMEGa
	 dey
	 bpl testQMEGloop
	 ; jest QMEG 
	 LDA #0
	 STA QMEG
	 LDY #$2
Qstatprint
	 LDA ONtext,y
	 STA QMEGstatus,y
	 DEY
	 bpl Qstatprint
brakQMEGa
     ; kombinacja z dodaniem identyfikatara i odjeciem 1 - bo tak dziwnie OS robi
     LDA DDEVIC
     clc	 
	 ADC DUNIT
     sec
     SBC #$01
     AND #$0F	 ; zapamietanie numeru urzadzenia
	 STA BootDrive
     JSR SeTDriveNR
     JMP mainprog
QMEGstring
	.BY "QMEG-OS"
	.BY "HS procedures for Happy/US-Doubler by Pecus & Pirx 25-08-2002"

	;.OPT List
	




     org $02e0
     .WO START 
