     ;MICRO SPARTA DOS 3.0s

; nowa koncepcja:

; 1. wywali� turbo 'top-drive'

; 2. przerobi� loader i menu na obs�ug� sektor�w dow. d�ugo�ci

; 3. przepisac czytanie tablicy sektor�w indeksowych z loadera do menu:
;    a. w menu odczytywane s� wszystkie sektory tablicy indeksowej
;    b. budowana jest "skompresowana" tablica offset�w w stosunku do pierwszego sektora na nast. zasadzie:
;       mamy nast. znaczniki :
;       1xxxxxxx  -- (0xxxxxxx = ile sektor�w omin��) nast�pny bajt to liczba kolejno wczytanych sektor�w 
;       00000000  -- nast�pny bajt to liczba kolejno wczytanych sektor�w (razem z ew. pierwszym sektorem pliku)	
;       00000001  -- nast�pne 2 bajty to numer kolejnego sektora do odczytania,
;                    nast�pny bajt to liczba kolejno wczytanych sektor�w

; 4. nowa 'skompresowana' tablica indeksowa podwyzsza memlo

; 5. w wolne miejsca kitramy co si� da (np. do buforu magnetofonu)

;  po bledzie odczytu program zawsze wraca na dysk nr.1 - jesli nie jest podpiety - to mamy petle nieskonczona - poprawic!!!

	 
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
BootSHIFT = START-1

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

JCIOMAIN   = $e456
JSIOINT   = $e459
JTESTROM = $e471
JRESETWM = $e474
JRESETCD = $e477

	org $1FFD

; przesuniecia potrzebne do relokacji
offset1 = movedproc-$0700
offset2 = TopDriveMovedProc-$0a00
; adres bufora na sektor wczytywanego pliku w oryginale $0800, ale moze wydluzyc sie procedura
; uwaga, ty juz odjety offset, wiec w procedurze nie odejmujemy!!!
FileSecBuff = loader.FirstMapSectorNr   ; po przepisaniu
; adres bufora na sektor mapy wczytywanego pliku
FileMapBuff = FileSecBuff + $0100  ; oba bufory powinny miec taki sam mlodszy bajt adresu  ; po przepisaniu
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
     LDA   SecLen
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
     BEQ   GoGetNextFileSect       		;; skok do procedury pobrania nastepnego sektora 
     LDA   FileSecBuff,X
     INX
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
GetMapSector
     LDX  #>FileMapBuff
     .BY $2c  						; rozkaz BIT powodujacy ominiecie nastepnyc dwoch bajtow ...
GetDataSector
     LDX  #>FileSecBuff
     STX   blokDanychIO1+5
     STY   DAUX1
     STA   DAUX2
     ORA   DAUX1
     BEQ   GoSelfTest  					; jesli sektor numer 0 - selftest
ReadErrorLoop
     LDX  #$09
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
SecLen = blokDanychIO1+8 ; SecLen wskazuje na komurki do wpisania d�ugo�ci sektora przed przepisaniem procki na stron� $0700
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
     BEQ   GetNextFileSect				;; jesli tak to pobieramy nastepny
ByteToACCU
     LDA   FileSecBuff,X  				;; pobranie bajtu z pliku do A 
     INX
     SEC
Jrts
     RTS
; Wczytanie do bufora kolejnego sektora pliku, kolejny bajt pliku w A, a CARRY ustawiony!!!
GetNextFileSect
     TYA
     PHA
     LDX   PointInMap
     CPX   SecLenZ						;; jesli koniec mapy to trzeba pobrac jej nastepny sektor
     BNE   NotMapEnd
     LDY   FileMapBuff					;; pobranie numeru nastepnego sektora mapy
     LDA   FileMapBuff+$01				;; (dwa pierwsze bajty sektora mapy)
     JSR   GetMapSector		; zaladowanie sektora mapy do bufora
     LDX  #$04
NotMapEnd
     LDA   FileMapBuff,X				; pobranie z mapy numeru kolejnego sektora pliku
     TAY
     LDA   FileMapBuff+1,X
     INX 
     INX								; zwiekszenie wskaznika pozycji w mapie
     STX   PointInMap					; i zapisanie go
     JSR   GetDataSector		; wczytanie kolejnego sektora pliku do bufora
     PLA
     TAY
     LDX  #$00							; wyzerowanie wskaznika bajtu w sektorze
     BEQ   ByteToACCU					; skok do pobrania bajtu z pliku do A i koncie procedury
; koniec czesci glownejprocedury ladowania pliku przepisywanej pod $0700
; tu zaczyna sie (takze przepisywana) procedura wykonujaca sie tylko raz
; w tym miejscu potem bedzie bufor
; Tutaj wpisywany jest przez menu loadera numer pierwszego sektora
; mapy pliku do wczytania, potrzebny tylko na starcie ladowania
zzzzzz  ; dla wygody - ta etykieta powinna miec $2100 jesli procedura ja poprzedzajaca miesci sie na stronie
	.if zzzzzz>$0800
		.error "zzzzz!!!"
	.endif
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
     LDA   FirstMapSectorNr+1
     LDY   FirstMapSectorNr
     JSR   GetMapSector		; ladowanie pierwszego sektora mapy do bufora
     LDA  #$04
     STA   PointInMap
     LDA   tempToFileEndL
     STA   ToFileEndL
     LDA  #$FF
     STA   KBCODES
     INC   WhatIsIt	; zmiana BCS omijajacego procedure na LDA (adres pierwszego bloku do STARTADR)
     LDX   SecLen		; dlugosc sektora do X, czyli wymuszenie przeczytania nastepnego sektora
     JMP   FileNextBlock
; tymczasowe przechowanie najmlodszego bajtu licznika do konca pliku
; sluzy do przepisania tego bajtu z glownego programu do zmiennej loadera
	.endl
tempToFileEndL
     .BY $00             ;2152  00
JAkieTurbo
	 .BY $00     ; 0 - brak turbo
					; 1 - TopDrive lub XF
					; 2 - Speedy/Happy
					; 3 - HDI
; Rozkaz DCB odczytujacy blok PERCOM  (12b) pod FirstSectorBuff
blokDanychIO2
     .BY $31,$01,$4E,$40
     .WO FirstSectorBuff
     .BY $07,$00,$0C,$00    ;2155  31 01
; Zamiana 4 mlodszych bitow z A na liczbe Hex w Ascii (tez w A)
bin2AsciiHex
     AND  #$0F             ;2161  29 0F
     ORA  #$30             ;2163  09 30
     CMP  #$3A             ;2165  C9 3A
     BCC   labelka           ;2167  90 03
     CLC                   ;2169  18
     ADC  #$07             ;216A  69 07
labelka
     RTS    

Edriver
     .BY "E:",$9b      
mainprog
     LDX  #$00             
     JSR   CloseX           ; Zamkniecie Ekranu
     BMI   ErrorDisplay 
     LDX  #$00 
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
     LDA  #$03
     STA   JAkieTurbo           ;wymuszenie sprawdzenia wszystkich turb
     LDA   SKSTAT
	 AND   BootSHIFT   ; sprawdzenie czy byl Shift przy starcie, wtedy obecny nie ma znaczenia
     AND  #$08
     BNE   NoRunShift  ; czy SHIFT w czasie odczytu glownego katalogu 
     ; tu jest 0 w A
     STA   JAkieTurbo      ; wylacza wszystkie turba
     BEQ   ReadMainDir        
NoRunShift
; tutaj sprawdzenie jakie mamy turbo i ustawienie odpowiednio znacznikow.
     jsr CzyHDI ; sprawdzenie czy jest HDI i zaladowanie procedury (jesli jest), jesli nie Wartosc ujemna
	 bpl ReaDMainDir
	 dec JakieTurbo ; 2
	 jsr CzyHappy ; sprawdzenie czy jest Happy/US i pobranie indeksu predkosci
	 bpl ReadMainDir
	 dec JakieTurbo ; 1
	 jsr CzyXF ; sprawdzenie czy jest turbo XF
	 bpl ReadMainDir
	 dec JakieTurbo ; 0
	 beq ReadMainDir ; skoczy zawsze bo 0
Error148
     LDY  #$94             ;21CF  A0 94
ErrorDisplay
     TYA                   ;21D1  98
     PHA                   ;21D2  48
     JSR   Close1           ;21D3  20 5F 28
     PLA                   ;21D6  68
     PHA                   ;21D7  48
     LSR                  ;21D8  4A
     LSR                  ;21D9  4A
     LSR                  ;21DA  4A
     LSR                  ;21DB  4A
     JSR   bin2AsciiHex           ;21DC  20 61 21
     STA   ErrorNumHex           ;21DF  8D F8 21
     PLA                   ;21E2  68
     JSR   bin2AsciiHex           ;21E3  20 61 21
     STA   ErrorNumHex+1           ;21E6  8D F9 21
     JSR   PrintXY           ;21E9  20 88 27
     .BY $00,$00         ;21EC  00
                           ;21ED  00
     .BY $7d             ;21EE  7D 45 52
     .BY "ERROR - $"
ErrorNumHex
     .BY "00",$00        ;21F8  30
                           ;21F9  30 00
     LDA  #$FF             ;21FB  A9 FF
     STA   KBCODES              ;21FD  8D FC 02
WaitKloop
     LDX   KBCODES              ;2200  AE FC 02
     INX                   ;2203  E8
     BEQ   WaitKloop           ;2204  F0 FA
     LDA  #$FF             ;2206  A9 FF
     STA   KBCODES              ;2208  8D FC 02
     ; ------------------
     ; na wypadek wybrania nieistniejacej stacji
     ; po bledzie prechodzimy na D1
     LDA #$01
     JSR SeTDriveNR
     ; -----------------
     JMP   mainprog           ;220B  4C 70 21
ReadMainDir
     LDX  #>FirstSectorBuff             ;220E  A2 29
     LDY  #<FirstSectorBuff             ;2210  A0 00
     JSR   ReadFirstSect           ;2212  20 3A 27
; Sprawdzenie wersji DOSa pod ktora formatowany byl dysk
     LDA   FirstSectorBuff+$20           ;2215  AD 20 29
     CMP  #$11             ;2218  C9 11
     BEQ   SpartaDisk           ;221A  F0 04
     CMP  #$20
     BEQ	SpartaDisk
	 CMP  #$21				; Nowy format dysku
     BNE   Error148           ;221E  D0 AF
SpartaDisk
     LDX  #$00             ;2220  A2 00
; pobranie dlugosci sektora ($00 lub $80)
     LDA   FirstSectorBuff+$1F
     STA   .adr loader.SecLen	; przed przepisaniem
     BMI   Sektor128b
	 STX   .adr loader.SecLen	; przed przepisaniem
	 TAX
     INX                   ; i wyliczenie starszego bajtu
Sektor128b
label38
     STX   .adr loader.SecLen+1	; przed przepisaniem
; pobranie numeru pierwszego sektora mapy sektorow glownego katalogu
     LDY   FirstSectorBuff+$09           ;222E  AC 09 29
     LDX   FirstSectorBuff+$0A           ;2231  AE 0A 29
label02
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
     BMI   label44           ;228C  30 19
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
label44
     LDY  #$01             ;22A7  A0 01
     LDA  (CurrentFileInfoBuff),Y          ;22A9  B1 D0
     STA   DirMapSect             ;22AB  85 D2
     INY                   ;22AD  C8
     LDA  (CurrentFileInfoBuff),Y          ;22AE  B1 D0
     STA   DirMapSect+1             ;22B0  85 D3
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
label71
     JSR   PrintXY           ;22EF  20 88 27
     .BY $00,$00         ;22F2  00
     .BY $7d             ;22F4  7D A0 CD
     .BY +$80," Drv: D"
DriveDisp1        ;                               "
     .BY +$80,"1:MSDOS 3.3c by BEWESOFT 93-2009 "  ; w inversie
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
  ; sprawdzenie czy to podkatalog jesni nie 'label55' (czyli plik)
     BEQ   label55           ;23C6  F0 0B
  ; obsluga wyswietlenia nazwy podlatalogu (dopisanie "<SUB-DIR>")
     LDX  #$08             ;23C8  A2 08
label56
     LDA   SubDirText,X         ;23CA  BD 0C 25
     STA   GameName+12         ;23CD  9D 40 24
     DEX                   ;23D0  CA
     BPL   label56           ;23D1  10 F7
label55
     JMP   label57           ;23D3  4C 24 24
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
     LDY  #$0A             ;23FC  A0 0A
label62
     LDA  ($D4),Y          ;23FE  B1 D4
     CMP   GameName,Y         ;2400  D9 34 24
     BNE   label61           ;2403  D0 11
     DEY                   ;2405  88
     BPL   label62           ;2406  10 F6
; Wpisanie nazwy "ekranowej" zamiast nazwy pliku
     LDY  #$0B             ;2408  A0 0B
label63
     LDA  ($D4),Y          ;240A  B1 D4
     STA   GameName-$0B,Y         ;240C  99 29 24
     INY                   ;240F  C8
     CPY  #$2E             ;2410  C0 2E
     BCC   label63           ;2412  90 F6
     BCS   label57           ;2414  B0 0E
label61
     LDA   $D4             ;2416  A5 D4
     CLC                   ;2418  18
     ADC  #$2E             ;2419  69 2E
     STA   $D4             ;241B  85 D4
     BCC   label64           ;241D  90 02
     INC   $D5             ;241F  E6 D5
label64
     JMP   label65           ;2421  4C EE 23
label57
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
     BCS   label67           ;2477  B0 35
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
     JMP   label02           ;249A  4C 34 22
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
     JMP   label71           ;24AB  4C EF 22
label67
     JSR   PrintXY           ;24AE  20 88 27
     .BY $01,$15         ;24B1  01 15
     .BY $1D
     .BY $00             ;24B3  1D 00
     JSR   PrintXY           ;24B5  20 88 27
     .BY $0E,$15           ;24B8  0E 15
     .BY $1D
     .BY $00             ;24BA  1D 00
     JMP   KeyboardProc           ;24BC  4C C1 24
label58
     INC   $D6             ;24BF  E6 D6
KeyboardProc
     JSR   GetKey           ;24C1  20 69 28
     PHA                   ;24C4  48
     LDA   SKSTAT          ;24C5  AD 0F D2
	 AND   BootSHIFT   ; sprawdzenie czy byl Shift przy starcie, wtedy obecny nie ma znaczenia
     AND  #$08             ;24C8  29 08
     BNE   NoSHIFT           ;24CA  D0 08
     LDA  #$00             ;24CC  A9 00
     STA   JakieTurbo           ;24CE  8D 53 21
NoSHIFT
     PLA                   ;24D4  68
     CMP  #$3E  ; ">"           ;24D5  C9 3E
     BEQ   MainDirKEY           ;24D7  F0 B1
     CMP  #$3C  ; "<"           ;24D9  C9 3C
     BEQ   UpDirKEY           ;24DB  F0 B0
     CMP  #$1B  ; Esc           ;24DD  C9 1B
     BEQ   EscKEY           ;24DF  F0 BC
     CMP  #$20             ;24E1  C9 20
     BEQ   SpaceKEY           ;24E3  F0 C2
     ; ----------------
     ; sprawdzenie klawiszy 1-8
	 ; ale najpierw odshiftowanie (za pomoca tabelki tyle ze tu od 0 do 9 zeby miec na przyszlosc)
	 STA SprawdzShiftCyfra+1   ; zapamietujemy kod do porownan (przy okazji)
	 LDX #9
PetlaShiftNaCyfre
	 LDA TablShift,X
SprawdzShiftCyfra	 
	 CMP #'!'   ; tu jest wstawiony kod wcisnietego klawisza do przeliczenia
	 BNE NieShiftCyfra
	 ; liczba wg tablicy
	 TXA
	 CLC
	 ADC #'0'
	 BNE JestShiftCyfra
NieShiftCyfra
	 DEX
	 BPL PetlaShiftNaCyfre
	 LDA SprawdzShiftCyfra+1  ; Jesli nie bylo w tablicy to przywracamy stary Accu
JestShiftCyfra
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
TablShift
	 .BY $29,$21,$22,$23,$24,$25,$26,$27,$40,$28,$29  ; cyfry 0-9 z Shift (kody)
NoNumber
     SEC                   ;24E5  38
     SBC  #'A'  ; "A"           ;24E6  E9 41
     CMP   $D9             ;24E8  C5 D9
     BCS   KeyboardProc           ;24EA  B0 D5
     ASL               ;24EC  0A
     TAX                   ;24ED  AA
     LDA   FirstSectorsTable,X         ;24EE  BD CA 28
     STA   $D4             ;24F1  85 D4
     LDA   FirstSectorsTable+1,X         ;24F3  BD CB 28
     STA   $D5             ;24F6  85 D5
     LDY  #$00             ;24F8  A0 00
     LDA  ($D4),Y          ;24FA  B1 D4
     AND  #$20             ;24FC  29 20
     BEQ   label01           ;24FE  F0 15
     LDY  #$02             ;2500  A0 02
     LDA  ($D4),Y          ;2502  B1 D4
     TAX                   ;2504  AA
     DEY                   ;2505  88
     LDA  ($D4),Y          ;2506  B1 D4
     TAY                   ;2508  A8
     JMP   label02           ;2509  4C 34 22
SubDirText
     .BY "<SUB-DIR>"    ;250C  3C
label01
     JSR DiscChangeCheck             ;2515  20 B3 28
     BEQ   label04           ;2518  F0 03
     JMP   ReadMainDir         ;251A  4C 0E 22
label04
     LDY  #$01             ;251D  A0 01
     LDA  ($D4),Y          ;251F  B1 D4
     STA   .adr loader.FirstMapSectorNr	; przed przepisaniem
     INY                   ;2524  C8
     LDA  ($D4),Y          ;2525  B1 D4
     STA   .adr loader.FirstMapSectorNr+1	; przed przepisaniem
     INY                   ;252A  C8
     LDA  ($D4),Y          ;252B  B1 D4
     EOR  #$FF             ;252D  49 FF
     STA   tempToFileEndL           ;252F  8D 52 21
     INY                   ;2532  C8
     LDA  ($D4),Y          ;2533  B1 D4
     EOR  #$FF             ;2535  49 FF
     STA   .adr loader.ToFileEndH	; przed przepisaniem
     INY                   ;253A  C8
     LDA  ($D4),Y          ;253B  B1 D4
     EOR  #$FF             ;253D  49 FF
     STA   .adr loader.ToFileEndH+1	; przed przepisaniem
     LDA  #$00             ;2542  A9 00
     STA   COLDST          ;2544  8D 44 02
     LDA  #$02             ;2547  A9 02
     STA   BOOT            ;2549  85 09
     STA   $03F8           ;254B  8D F8 03
     LDA  #<label06             ;254E  A9 65
     STA   CASINI          ;2550  85 02
     LDA  #>label06             ;2552  A9 25
     STA   CASINI+1        ;2554  85 03
     LDA  #>JRESETCD         ;2556  A9 E4
     STA   DOSVEC+1        ;2558  85 0B
     STA   DOSINI+1        ;255A  85 0D
     LDA  #<JRESETCD         ;255C  A9 77
     STA   DOSVEC          ;255E  85 0A
     STA   DOSINI          ;2560  85 0C
     JMP   JRESETWM          ;2562  4C 74 E4
label06
     LDA  #$00             ;2565  A9 00
     STA   MEMLO           ;2567  8D E7 02
     STA   BOOT            ;256A  85 09
     STA   APPMHI          ;256C  85 0E
     LDA  #$0A             ;256E  A9 0A
     STA   MEMLO+1         ;2570  8D E8 02
     STA   APPMHI+1        ;2573  85 0F
     LDA  #<JRESETCD         ;2575  A9 77
     STA   CASINI          ;2577  85 02
     LDA  #>JRESETCD         ;2579  A9 E4
     STA   CASINI+1        ;257B  85 03
     INC   $033D           ;257D  EE 3D 03
     INC   $033E           ;2580  EE 3E 03
     DEC   $033F           ;2583  CE 3F 03
     LDX  #$00             ;2586  A2 00
moveloop1
     LDA   movedproc,X         ;2588  BD 00 20
     STA   $0700,X         ;258B  9D 00 07
     LDA   movedproc+$0100,X         ;258E  BD 00 21
     STA   $0800,X         ;2591  9D 00 08
     INX                   ;2594  E8
     BNE   moveloop1           ;2595  D0 F1
     LDX  #$00             ;2597  A2 00
     LDA  #$00             ;2599  A9 00
ClearLoop1
     STA   $0100,X         ;259B  9D 00 01
     STA   $0400,X         ;259E  9D 00 04
     STA   $0500,X         ;25A1  9D 00 05
     STA   $0600,X         ;25A4  9D 00 06
     CPX  #$80             ;25A7  E0 80
     BCC   NoZpage           ;25A9  90 02
     STA   $00,X           ;25AB  95 00
NoZpage
     INX                   ;25AD  E8
     BNE   ClearLoop1           ;25AE  D0 EB
     LDX  #$FF             ;25B0  A2 FF
     TXS                   ;25B2  9A
     JSR   label07           ;25B3  20 B9 25
     JMP   loader.LoadStart     ; po przepisaniu
label07
     LDA   JakieTurbo           ;25B9  AD 53 21
	 CMP   #$01
     BNE   NoTopDriveLoader           ;25BC  F0 11
     LDX  #[EndTopDriveProc-TopDriveMovedProc]-1       ;25BE  A2 34
label72
     LDA   TopDriveMovedProc,X         ;25C0  BD 0C 26
     STA   $0A00,X         ;25C3  9D 00 0A
     DEX                   ;25C6  CA
     BPL   label72           ;25C7  10 F7
     LDY  #[EndTopDriveProc-TopDriveMovedProc]             ;25C9  A0 35
     LDX  #$00             ;25CB  A2 00
     BEQ   label73           ;25CD  F0 23
NoTopDriveLoader
;     LDA   CzySpeedy           ;25CF  AD 54 21
;     BEQ   NoSpeedyLoader           ;25D2  F0 37
;; Pytanie stacji o dlugosc procedury szybkiej transmisji
;     LDY  #<blokDanychIO3             ;25D4  A0 41
;     LDX  #>blokDanychIO3             ;25D6  A2 26
;     JSR   Table2DCB           ;25D8  20 4D 28
;     JSR   JSIOINT            ;25DB  20 59 E4
;     BMI   NoSpeedyLoader           ;25DE  30 2B
;; Wczytanie procedury szybkiej transmisji pod $0a00
;     LDY  #<blokDanychIO4             ;25E0  A0 4D
;     LDX  #>blokDanychIO4             ;25E2  A2 26
;     JSR   Table2DCB           ;25E4  20 4D 28
;     JSR   JSIOINT            ;25E7  20 59 E4
;     BMI   NoSpeedyLoader           ;25EA  30 1F
;; Dlugosc procedury szybkiej transmisji do X i Y
;     LDY   blokDanychIO4+8   ;25EC  AC 55 26
;     LDX   blokDanychIO4+9   ;25EF  AE 56 26
;     jmp   label73
NoSpeedyLoader
     CMP #$02
     BNE NoHappyLoader
     ; Pytanie stacji o predkosc transmisji Happy/US-Doubler
;     ldy  #<blokDanychIO6    ; po co pytac jak wiadomo ?
;     ldx  #>blokDanychIO6
;     jsr   Table2DCB
;     jsr   JSIOINT             ; "?"
;     bmi   NoHappyLoader

	LDY #0
	LDX #[$A-1]  ;xjsrA - the last
HappyRelocate
	SEC
	LDA xjsrTableL,x
	STA SecBuffer
	LDA xjsrTableH,x
	STA SecBuffer+1
	LDA (SecBuffer),y
	SBC #<HappyOffset
	STA (SecBuffer),y
	INY
	LDA (SecBuffer),y
	SBC #>HappyOffset
	STA (SecBuffer),y
	DEY
	DEX
	BPL HappyRelocate







     LDX  #[EndHappyUSProc-HappyUSMovedProc]
label72x
     LDA   HappyUSMovedProc-1,X
     STA   $0A00-1,X
     DEX
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
     LDA  #<[TopDriveMovedProc-offset2]     ;2601  A9 00
     STA   loader.SioJMP+1               ; po przepisaniu
     LDA  #>[TopDriveMovedProc-offset2]    ;2606  A9 0A
     STA   loader.SioJMP+2             ; po przepisaniu
NoHappyLoader
     RTS                   ;260B  60



; UWAGA !!!!!!!!!!!!!!
; Ta procedura ma maksymalna dlugosc jaka moze miec!!!!!
; powiekszenie jej O BAJT spowoduje ze przekroczy strone
; i nie przepisze sie prawidlowo na swoje miejsce !!!!!	 
HappyUSMovedProc ;
HappyOffset=[HappyUSMovedProc-$a00]

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
TopDriveMovedProc
     LDA   VSERIN          ;260C  AD 0A 02
     STA   OldSerInJmp-offset2+1          ;260F  8D 33 0A
     PHA                   ;2612  48
     LDA   VSERIN+1           ;2613  AD 0B 02
     STA   OldSerInJmp-offset2+2          ;2616  8D 34 0A
     PHA                   ;2619  48
     LDA   DCOMND          ;261A  AD 02 03
     ORA  #$80             ;261D  09 80
     STA   DCOMND          ;261F  8D 02 03
     LDA  #<(NewSerInInterrupt-offset2)        ;2622  A9 2D
     STA   VSERIN          ;2624  8D 0A 02
     LDA  #>(NewSerInInterrupt-offset2)        ;2627  A9 0A
     STA   VSERIN+1        ;2629  8D 0B 02
     JSR   JSIOINT            ;262C  20 59 E4
     PLA                   ;262F  68
     STA   VSERIN+1        ;2630  8D 0B 02
     PLA                   ;2633  68
     STA   VSERIN          ;2634  8D 0A 02
     TYA                   ;2637  98
     RTS                   ;2638  60
NewSerInInterrupt
     LDA  #$10             ;2639  A9 10
     STA   AUDF3           ;263B  8D 04 D2
OldSerInJmp
     JMP   $FFFF           ;263E  4C FF FF
EndTopDriveProc
; Rockaz DCB "?" pobierrajacy predkosc dla Happy i US-Doubler
blokDanychIO6
; Rozkazy DCB do wszytania procedury turbo dla Speedy/HDI
     .BY $31,$01,$3f,$40
     .WO HappySpeed
     .BY $07,$00,$01,$00,$00,$0A
;blokDanychIO3
;     .BY $31,$01,$68,$40       ;2641  31 01
;     .WO [blokDanychIO4+8]
;     .BY $07,$00,$02,$00,$00,$0A
;blokDanychIO4
;     .BY $31,$01,$69,$40,$00,$0A,$07,$00,$01,$00,$00,$0A       ;264D  31 01
DirMapEnd
     JMP   label75           ;2659  4C 0D 27
label39
     STA   $DA             ;265C  85 DA
     LDA   CurrentFileInfoBuff             ;265E  A5 D0
     STA   $DB             ;2660  85 DB
     LDA   CurrentFileInfoBuff+1             ;2662  A5 D1
     STA   $DC             ;2664  85 DC
     JSR   DiscChangeCheck           ;2666  20 B3 28
     BEQ   label76           ;2669  F0 05
     PLA                   ;266B  68
     PLA                   ;266C  68
     JMP   ReadMainDir           ;266D  4C 0E 22
label76
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
     BEQ   label76           ;2699  F0 D5
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
     LDA  #$80             ;2744  A9 80
     BNE   ReadSectorA           ;2746  D0 03
; Wczytuje sektror ustalajac jego dlugosc na podstawie blokDanychIO1 (SecLen)
; reszta danych jak nizej (A nie wazne)
ReadSector
     LDA   .adr loader.SecLen	; przed przepisaniem
; Wczytuje sektor (numer musi byc juz podany w blokDanychIO5 !!)
; o dlugosci A($00 lub $80) pod adres X(starszy) Y(mlodszy)
ReadSectorA
     STA   blokDanychIO5+8            ;274B  8D 83 27
     STX   blokDanychIO5+5           ;274E  8E 80 27
     STY   blokDanychIO5+4           ;2751  8C 7F 27
     LDX  #$00             ;2754  A2 00
     LDA   blokDanychIO5+8            ;2756  AD 83 27
     BNE   label84           ;2759  D0 01
     INX                   ;275B  E8
label84
     STX   blokDanychIO5+9            ;275C  8E 84 27
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
; Skok do Sio ze sprawdzeniem czy nie TopDrive i odpowiedna modyfikacja
; procedury
GoSIO
     LDY JakieTurbo
     BEQ  StandardSpeed
     DEY ; sprawdzamy czy 1
	 BEQ XFturbo
	 DEY ; sprawdzamy czy 2
	 BNE HDIturbo ; jesli 3
     JMP  HappyUSMovedProc ; mozna skakac do tej procki
StandardSpeed
HDIturbo ; na razie bez obslugi
     JMP   JSIOINT            ;281D  4C 59 E4
XFturbo
; Obsluga trybu TopDrive (XF)...
     LDA   VSERIN          ;2820  AD 0A 02
     STA   OldSerInJmp+1        ;2823  8D 3F 26
     PHA                   ;2826  48
     LDA   VSERIN+1           ;2827  AD 0B 02
     STA   OldSerInJmp+2        ;282A  8D 40 26
     PHA                   ;282D  48
     LDA   DCOMND          ;282E  AD 02 03
     ORA  #$80             ;2831  09 80
     STA   DCOMND          ;2833  8D 02 03
     LDA  #<NewSerInInterrupt            ;2836  A9 39
     STA   VSERIN          ;2838  8D 0A 02
     LDA  #>NewSerInInterrupt            ;283B  A9 26
     STA   VSERIN+1        ;283D  8D 0B 02
     JSR   JSIOINT            ;2840  20 59 E4
     PLA                   ;2843  68
     STA   VSERIN+1        ;2844  8D 0B 02
     PLA                   ;2847  68
     STA   VSERIN          ;2848  8D 0A 02
     TYA                   ;284B  98
     RTS                   ;284C  60
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
	 
; Procedury r�ne
; Sprawdzenie czy HDI i odczyt procedury z urzadzenia
CzyHDI
	LDY #128 ; b��d
	RTS
CzyHappy
	LDY #128 ; b��d
	RTS
CzyXF
	LDY #128 ; b��d
	RTS    
;; Odczyt bloku PERCOM procedura przeznaczona dla Top Drive (bo znacznik ustawiony)
;     LDY  #<blokDanychIO2             ;21BC  A0 55
;     LDX  #>blokDanychIO2             ;21BE  A2 21
;     JSR   Table2DCB           ;21C0  20 4D 28
;     JSR   GoSIO           ;21C3  20 18 28
;     BPL   ReadMainDir           ;21C6  10 46
;; jesli PERCOM sie nie odczytal to nie mamy TopDrive
;     LDA  #$00             ;21C8  A9 00
;     STA   CzyTopDrive           ;21CA  8D 53 21
;     ;sprawdzamy jeszcze Happy/US-Doubler
;     LDY  #<blokDanychIO6
;     LDX  #>blokDanychIO6
;     JSR   Table2DCB
;     JSR   JSIOINT
;     BPL   ReadMainDir
;     ; jezeli predkosc sie nie odczytala to brak Happy/US
;     ; ustawienie standardowej predkosci
;     LDA #$28
;     STA HappySpeed
;     LDA  #$00
;     STA  CzyHappyUS
;     BEQ   ReadMainDir           ;21CD  F0 3F
	 	 
	 
	 ; Ustawia numer satcji wg A
SeTDriveNR
     STA .adr loader.blokDanychIO1+1	; przed przepisaniem
     STA blokDanychIO2+1
;     sta blokDanychIO3
;     sta blokDanychIO4
     STA blokDanychIO5+1
     STA blokDanychIO6+1
     CLC
     ADC #'0'+$80
     STA DriveDisp1
     STA DriveDisp2
     JSR PrintXY
     .BY $08,$00
DriveDisp2
     .BY +$80,"1"
     .BY $00
     RTS

xjsrTableL
	.BY <[xjsr1+1],<[xjsr2+1],<[xjsr3+1],<[xjsr4+1],<[xjsr5+1]
	.BY <[xjsr6+1],<[xjsr7+1],<[xjsr8+1],<[xjsr9+1],<[xjsrA+1]
xjsrTableH
	.BY >[xjsr1+1],>[xjsr2+1],>[xjsr3+1],>[xjsr4+1],>[xjsr5+1]
	.BY >[xjsr6+1],>[xjsr7+1],>[xjsr8+1],>[xjsr9+1],>[xjsrA+1]


; miejsce na tablice trzymajaca numery pierwszych sektorow map bitoeych plikow aktualnie wyswietlanych na liscie
FirstSectorsTable
     org *+$30
	 
ProgramEnd
FirstSectorBuff=[[>[*-1]]+1]*$100 ;$2900 ; tutaj pierwszy sektor dysku ($80 bajtow)
DirMapSectorBuff=FirstSectorBuff+$80 ; tutaj aktualny sektor mapy sektorow katalogu
DirSectorBuff=FirstSectorBuff+$180 ; tutaj sektor katalogu
FirstRun
     LDA   SKSTAT     ; uruchamia sie tylko raz na starcie loadera
     AND  #$08           
     STA   BootSHIFT  ; zapamietanie stanu Shift z bootowania
; ale jesli jest QMEG.... to odwracamy ten stan :)
     ldy #$06  ; bo 6 znak�w w ROMie testujemy
testQMEGloop
	 LDA $C001,y
	 CMP QMEGstring,y
	 bne brakQMEGa
	 dey
	 bpl testQMEGloop
	 ; jest QMEG - EORujemy odpowiedni bit i mamy odwrotny shift
	 LDA BootSHIFT
	 EOR #$08
	 STA BootSHIFT
brakQMEGa	 
	 LDA DUNIT		; zapamietanie numeru urzadzenia
     AND #$0F
     JSR SeTDriveNR
     JMP mainprog
QMEGstring
	.BY "QMEG-OS"
	.BY "HS procedures for Happy/US-Doubler by Pecus & Pirx 25-08-2002"
     org $02e0
     .WO START           ;02E0  FD 1F

	;.OPT List