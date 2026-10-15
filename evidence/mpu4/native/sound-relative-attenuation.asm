5F92: A6 C0       LDA    ,U+
5F94: 27 14       BEQ    $5FAA
5F96: A6 2B       LDA    $B,Y
5F98: 43          COMA
5F99: 84 0F       ANDA   #$0F
5F9B: AB 5F       ADDA   -$1,U
5F9D: 2A 03       BPL    $5FA2
5F9F: 4F          CLRA
5FA0: 20 1C       BRA    $5FBE
5FA2: 81 0F       CMPA   #$0F
5FA4: 23 18       BLS    $5FBE
5FA6: 86 0F       LDA    #$0F
5FA8: 20 14       BRA    $5FBE
5FAA: 86 0D       LDA    #$0D
5FAC: 20 02       BRA    $5FB0
5FAE: A6 C0       LDA    ,U+
5FB0: D6 50       LDB    <$50
5FB2: 3D          MUL
5FB3: 4D          TSTA
5FB4: 27 02       BEQ    $5FB8
5FB6: C6 FF       LDB    #$FF
5FB8: 1F 98       TFR    B,A
5FBA: 44          LSRA
5FBB: 44          LSRA
5FBC: 44          LSRA
5FBD: 44          LSRA
5FBE: 43          COMA
5FBF: A8 2B       EORA   $B,Y
5FC1: 84 0F       ANDA   #$0F
5FC3: A8 2B       EORA   $B,Y
5FC5: A7 2B       STA    $B,Y
5FC7: E6 2A       LDB    $A,Y
5FC9: 10 2B FD 6E LBMI   $5D3B
5FCD: 8E 02 7E    LDX    #$027E
5FD0: CB 30       ADDB   #$30
5FD2: BD 60 AB    JSR    $60AB
5FD5: C0 30       SUBB   #$30
5FD7: E6 85       LDB    B,X
5FD9: 2A F5       BPL    $5FD0
5FDB: 7E 5D 3B    JMP    $5D3B
