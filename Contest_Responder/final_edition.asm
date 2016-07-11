;---------------------------竞赛抢答器--------------------------------

;---------堆栈段----------
STSEG SEGMENT
DB 64 DUP(?)
STSEG ENDS
;------------------------
;---------数据段----------
DATA SEGMENT

INTA00 EQU 20H    ;8259 端口：读/写ICW1，OCW2，OCW3
INTA01 EQU 21H    ;8259 端口：读/写OCW1，ICW2，ICW3，ICW4

IO8255A EQU 288H    ;A口
IO8255B EQU 28BH    ;控制字端口
IO8255C EQU 28AH    ;C口
LED DB 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H, 7FH   ;七段数码管 1~8

IO8253A EQU 280H
IO8253B EQU 283H
GAOYIN DW 524, 588, 660, 698, 784, 880, 988, 1048
HUANLESONG DB 03H, 03H, 04H, 05H, 05H, 04H, 03H, 02H, 01H, 01H, 02H, 03H, 03H, 02H, 02H   ;欢乐颂乐谱

LS273 EQU 290H    ;用于七段数码管的显示

DENGHUA1 DB 11110000B
DENGHUA2 DB 00001111B

DIANZHENKZ EQU 2B0H     ;8乘8点阵控制端口
DIANZHENY EQU 2B8H      ;控制黄色显示

PATTERN1   DB 0H,0H,0H,18H,18H,0H,0H,0H    ;第一组显示的图案（8乘8）
           DB 0H,0H,3CH,24H,24H,3CH,0H,0H
           DB 0H,7EH,42H,42H,42H,42H,7EH,0H
           DB 0FFH,81H,81H,81H,81H,81H,81H,0FFH

PATTERN2   DB 0H,4H,24H,24H,24H,4H,0H,0H    ;第二组显示的图案
           DB 0H,22H,42H,46H,4AH,32H,2H,0H
           DB 0H,0H,7EH,0H,0H,7EH,0H,0H
           DB 0H,30H,30H,0H,6H,6H,0H,0H

PATTERN3   DB 0H,2H,2AH,2AH,2AH,2H,0H,0H    ;第三组显示的图案
           DB 0H,44H,82H,92H,92H,6CH,0H,0H
           DB 88H,44H,22H,11H,88H,44H,22H,11H
           DB 0H,6H,6H,30H,30H,6H,6H,0H
DATA ENDS
;------------------------

;---------代码段----------
CODE SEGMENT
     ASSUME CS:CODE, DS:DATA, SS:STSEG
MAIN PROC FAR
      CLI   ;关闭中断
      MOV AX, CS             ;CS 不能直接传送DS，必须通过AX
      MOV DS, AX             ;规定：中断服务子程序入口段基址码段CS 送DS
      MOV DX, OFFSET INT3    ;规定：中断服务程序入口偏移地址送DX
      MOV AX, 250BH          ;AH=25H 置中断向量,AL=0BH 中断类型
      INT 21H

      IN AL, INTA01          ;21H 端口，读IMR(中断屏蔽寄存器)各位
      AND AL, 0F7H           ;11110111B 允许IR3 请求中断
      OUT INTA01, AL         ;写中断屏蔽字OCW1

      MOV CX, 3              ;进行三次中断返回

      STI   ;开中断

WAI:  JMP WAI                ;等待中断

INT3: MOV AX, DATA
      MOV DS, AX

      CALL ZHUCHENGXU        ;调用主程序


      MOV AL, 20H
      OUT INTA00, AL         ;写OCW2, 送中断结束命令EOI 为001 普通结束方式

LOOP  INTE

      IN AL, 21H             ;读IMR
      OR AL, 08H
      OUT INTA01, AL
      STI

      MOV AH, 4CH
      INT 21H

INTE: IRET                    ;中断返回
MAIN ENDP
;------------------------

;---------主程序----------
ZHUCHENGXU PROC NEAR
ASSUME CS:CODE, DS:DATA, SS:STSEG
      PUSH AX
      PUSH BX
      PUSH CX
      PUSH DX
      PUSH SI

      MOV DX, IO8255A
      MOV AL, 8BH    ;控制8255为C口输入A口输出
      OUT DX, AL

SSS:  IN DX, AX    ;若输入为零则等待输入
      OR  AL,AL
      JE  SSS

      MOV CL,0
RR:   SHR AL,1    ;判断输入的组号
      INC CL
      JNC RR

      MOV BX,OFFSET LED    ;根据输入的组号控制七段数码管的显示
      MOV AL,CL
      DEC AL
      XLAT
      MOV DX,LS273
      OUT DX,AL

      CMP CL,1    ;将各组对应图案的偏移值送入SI
      JZ TEAM1
      CMP CL,2
      JZ TEAM2
      MOV SI,OFFSET PATTERN1
      JMP GO
TEAM1:
      MOV SI,OFFSET PATTERN2
      JMP GO
TEAM2:
      MOV SI,OFFSET PATTERN3
      JMP GO

GO:   MOV DX,IO8255B    ;数值8255工作方式为A口输出，C口输出
      MOV AL,80H
      OUT DX,AL

      PUSH CX
      PUSH DI

;---------帧控制----------
      MOV CX, 0    ;控制帧循环，共15帧
      MOV DI, 1    ;控制8乘8点阵的显示（每4帧更新一次图案）

CIR:  CALL DISPLAY_MUSIC
      CALL DISPLAY_DIANZHEN

      INC DI    ;DI自增4次则重新开始计数
      CMP DI, 5
      JE JIAN
      JMP TIAO

JIAN: MOV DI, 1

TIAO: INC CX
      CMP CX, 15
      JNE CIR

      POP CX
      POP DI
;------------------------

      MOV AL,0    ;关闭七段数码管
      OUT DX,AL

      POP SI
      POP DX
      POP CX
      POP BX
      POP AX
      RET
ZHUCHENGXU ENDP
;------------------------

;--------音乐子程序-------
DISPLAY_MUSIC PROC NEAR
ASSUME CS:CODE, DS:DATA, SS:STSEG
      PUSH AX
      PUSH BX
      PUSH DX
      PUSH SI

      MOV BX, OFFSET HUANLESONG     ;将乐谱的偏移值载入BX
      MOV AL, CL
      XLAT
      SHL AL, 1
      MOV BL, AL
      MOV BH, 0

      MOV AX,4240H      ;计数初值 = 1000000 / 频率, 保存到AX
      MOV DX,0FH
      DIV WORD PTR[GAOYIN+BX]
      MOV BX,AX

      MOV DX,IO8253B    ;设置8253计时器0方式3, 先读写低字节, 再读写高字节
      MOV AL,00110110B
      OUT DX,AL

      MOV DX,IO8253A
      MOV AX,BX
      OUT DX,AL    ;写计数初值低字节

      MOV AL,AH
      OUT DX,AL    ;写计数初值高字节

      MOV DX,IO8255A
      MOV AL,03H    ;置PC1,PC0 = 11(开扬声器)
      OUT DX,AL

;---------延时----------
      PUSH CX
      PUSH AX
      MOV AX,15
X1:   MOV CX,0FFFFH
X2:   DEC CX
      JNZ X2
      DEC AX
      JNZ X1
      POP AX
      POP CX
      MOV AL,0H
      OUT DX,AL
;-----------------------

      MOV AL,0H
      OUT DX,AL            ;置PC1,PC0 = 00(关扬声器)

      POP SI
      POP DX
      POP BX
      POP AX
      RET
DISPLAY_MUSIC ENDP

;---------点阵子程序----------
DISPLAY_DIANZHEN PROC NEAR
ASSUME CS:CODE, DS:DATA, SS:STSEG
      PUSH AX
      PUSH BX
      PUSH CX
      PUSH DX
      PUSH DI

      CMP DI, 4    ;DI为4则显示下一个图案
      JE JIA
      JMP AGN

JIA:  ADD SI, 8    ;通过加8更改偏移值为下一个图案


AGN:  MOV CX,40H    ;控制D2对应的程序循环40次
D2:   MOV AH,01H
      PUSH CX
      MOV CX,0008H    ;控制NEXT以显示八行
      MOV DI, 0
NEXT: MOV BH, AH    ;通过AX查表判断要输出的行对应的二进制码
      MOV AX, DI
      MOV AH, BH
      MOV BX,SI
      XLAT
      MOV DX,DIANZHENKZ    ;输出行码
      OUT DX,AL
      MOV AL,AH
      MOV DX,DIANZHENY    ;红灯显示一行信息
      OUT DX,AL
      MOV AL,0
      OUT DX,AL
      SHL AH,01    ;列码（列信号）左移一位，将‘1’移到下一位，为显示下列灯亮做准备
      INC DI    ;显示下一行
      LOOP NEXT
      POP CX
      LOOP D2

;-------调用灯花显示程序--------
      POP DI
      CALL DISPLAY_DENGHUA
      PUSH DI
;-----------------------------
      POP DI
      POP DX
      POP CX
      POP BX
      POP AX
      RET
DISPLAY_DIANZHEN ENDP

;--------灯花子程序----------
DISPLAY_DENGHUA PROC NEAR
ASSUME CS:CODE, DS:DATA, SS:STSEG
      PUSH AX
      PUSH BX
      PUSH CX
      PUSH DX
      PUSH SI

;--------选择灯花类型----------
      CMP DI, 1    ;两种灯花，交替显示
      JE ONE
      CMP DI, 2
      JE TWO
      CMP DI, 3
      JE ONE
      CMP DI, 4
      JE TWO
;----------------------------

ONE:  MOV BX, OFFSET DENGHUA1    ;将灯花1的二进制码送入AL
      MOV AL, [BX]

      MOV DX,IO8255C    ;通过8255C口控制灯花显示
      OUT DX,AL

      JMP EE

TWO:  MOV BX, OFFSET DENGHUA2    ;将灯花2的二进制码送入AL
      MOV AL, [BX]

      MOV DX,IO8255C
      OUT DX,AL

;---------延时----------
EE:   PUSH CX
      PUSH AX
      MOV AX,15
X3:   MOV CX,0FFFFH
X4:   DEC CX
      JNZ X4
      DEC AX
      JNZ X3
      POP AX
      POP CX
;-----------------------

      POP SI
      POP DX
      POP CX
      POP BX
      POP AX
      RET
DISPLAY_DENGHUA ENDP
;-------------------

CODE ENDS
     END MAIN
