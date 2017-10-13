module TomasPuto
#(parameter RESERVATIONSIZE=2,parameter ROBSIZE=2,)
(clock,done,run);
	input clock,run;
	output done;
	// Instrucões
	reg [15:0] instrMem [0:63];//instructions mem
		reg [5:0] pc;
	// Banco de registadores
	reg [15:0] registersBank [0:15];
		reg [5:0] registersBankLabel [0:15]; // Guarda a instrucao que precisa do valor
		reg registersBankHaveLabel [0:15]; // Indica se há label em determinada posicao

	// ROB
		reg [$clog2(ROBSIZE):0] ReordenationBufferIndex; // Indicador do index do ROB
			reg ReordenationBufferBusy [0:ROBSIZE-1];	// Indica se a posicao esta cheia
			reg [3:0] ReordenationBufferOp [0:ROBSIZE-1];  // Indica a operacao da instrucao do ROB
			reg [5:0] ReordenationBufferLabel [0:ROBSIZE-1]; // Indica a label da instrucao do ROB que tambem serve para indicar o (pc-1) se o desvio n for tomado
			reg [15:0] ReordenationBufferValue [0:ROBSIZE-1]; // Indica o valor da instrucao do ROB se for o mesmo da label o desvio foi tomado
			reg ReordenationBufferHaveValue [0:ROBSIZE-1]; // Indica se o valore da instrucao ja foi gravado
		
	// Estacao de reserva de soma
		reg [3:0] reservationStationAddOp [0:RESERVATIONSIZE-1]; // Indica operacao que existe na Estacao de reserva
		reg [5:0] reservationStationAddLabel [0:RESERVATIONSIZE-1]; // Indica o label da operacao da estacao de reserva
		reg reservationStationAddBusy [0:RESERVATIONSIZE-1]; // Indica se há instrucao na Estacao de reserva
		reg [3:0] reservationStationAddVj [0:RESERVATIONSIZE-1]; // Operando 1 se nao houver dependencia
		reg [3:0] reservationStationAddQj [0:RESERVATIONSIZE-1]; // Operando 1 se houver dependencia
			reg reservationStationAddJusy [0:RESERVATIONSIZE-1]; // Indica se há dependencia no Op 1
		reg [3:0] reservationStationAddVk [0:RESERVATIONSIZE-1]; // Operando 2 se nao houver dependencia
		reg [3:0] reservationStationAddQk [0:RESERVATIONSIZE-1]; // Operando 2 se houver dependencia
			reg reservationStationAddKusy [0:RESERVATIONSIZE-1]; // Indica se há dependencia no Op 2
		
	// Estacao de reserva de multiplicacao
		reg [3:0] reservationStationMulOp [0:RESERVATIONSIZE-1]; // Indica operacao que existe na Estacao de reserva
		reg [5:0] reservationStationMulLabel [0:RESERVATIONSIZE-1]; // Indica o label da operacao da estacao de reserva
		reg reservationStationMulBusy [0:RESERVATIONSIZE-1]; // Indica se há instrucao na Estacao de reserva
		reg [3:0] reservationStationMulVj [0:RESERVATIONSIZE-1]; // Operando 1 se nao houver dependencia
		reg [3:0] reservationStationMulQj [0:RESERVATIONSIZE-1]; // Operando 1 se houver dependencia
			reg reservationStationMulJusy [0:RESERVATIONSIZE-1]; // Indica se há dependencia no Op 1
		reg [3:0] reservationStationMulVk [0:RESERVATIONSIZE-1]; // Operando 2 se nao houver dependencia
		reg [3:0] reservationStationMulQk [0:RESERVATIONSIZE-1]; // Operando 2 se houver dependencia
			reg reservationStationMulKusy [0:RESERVATIONSIZE-1]; // Indica se há dependencia no Op 2
			
	// Estacao de reserva de memoria
		reg reservationStationLdBusy [0:RESERVATIONSIZE-1]; // Indica se há instrucao na Estacao de reserva
		reg [5:0] reservationStationLdLabel [0:RESERVATIONSIZE-1]; // Indica o label da operacao da estacao de reserva
		reg [3:0] reservationStationLdVj [0:RESERVATIONSIZE-1]; // Operando 1 se nao houver dependencia
		reg [3:0] reservationStationLdQj [0:RESERVATIONSIZE-1]; // Operando 1 se houver dependencia
			reg reservationStationLdJusy [0:RESERVATIONSIZE-1]; // Indica se há dependencia no Op 1
		reg [5:0] reservationStationLdOffset [0:RESERVATIONSIZE-1]; // Indica qual o offset

		reg reservationStationStBusy [0:RESERVATIONSIZE-1]; // Indica se há instrucao na Estacao de reserva
		reg [5:0] reservationStationStLabel [0:RESERVATIONSIZE-1]; // Indica o label da operacao da estacao de reserva
		reg [3:0] reservationStationStVj [0:RESERVATIONSIZE-1]; // Operando 1 se nao houver dependencia
		reg [3:0] reservationStationStQj [0:RESERVATIONSIZE-1]; // Operando 1 se houver dependencia
			reg reservationStationStJusy [0:RESERVATIONSIZE-1]; // Indica se há dependencia no Op 1
		reg [5:0] reservationStationStOffset [0:RESERVATIONSIZE-1]; // Indica qual o offset
		reg [3:0] reservationStationStVk [0:RESERVATIONSIZE-1]; // Valor se nao houver dependencia
		reg [3:0] reservationStationStQk [0:RESERVATIONSIZE-1]; // Valor se houver dependencia
			reg reservationStationStKusy [0:RESERVATIONSIZE-1]; // Indica se há dependencia no Valor

		
	// CDB Unit
		reg CDBusy; // Indica se o CDB esta ocupado
	
	// SUM Unit
		reg[1:0] SumBusy; // Indica se a unidade de soma esta ocupada
			reg[15:0] SumParamB; // Indica o operando 1
			reg[15:0] SumParamC; // Indica o operando 2
			reg[15:0] SumValue; // Guarda o resultado da operacao
			reg[1:0] SumState; // Indica o estado da operacao
			reg SumDone; // Indica se a operacao acabou
			reg[0:RESERVATIONSIZE] SumIndex; // Indica o index da operacao na estacao de reserva
			reg SumOp; // Indica o tipo de operacao

	// MUL Unit
		reg MulBusy; // Indica se a unidade de multipliacao esta ocupada
			reg[15:0] MulParamB; // Indica o operando 1
			reg[15:0] MulParamC; // Indica o operando 2
			reg[15:0] MulValue; // Guarda o resultado da operacao
			reg[2:0] MulState; // Indica o estado da operacao
			reg MulDone; // Indica se a operacao acabou
			reg[0:RESERVATIONSIZE-1] MulIndex; // Indica o index da operacao na estacao de reserva
			reg MulOp; // Indica o tipo de operacao

	// ADDR Unit
		reg AddrBusy; // Indica se a unidade de enderecamento esta ocupada
			reg AddrOp; // Indica o tipo de instrucao
			reg[5:0] AddrLabel; // Indica a label da instrucao
			reg[15:0] AddrParamB; // Indica o operando 1
			reg[15:0] AddrParamC; // Indica o operando 2
			reg[15:0] AddrValue; // Indica o estado da operacao
			reg[0:RESERVATIONSIZE-1] AddrIndex; // Indica o index da operacao na estacao de reserva
			reg[1:0] AddrState; // Indica o estado da operacao
			reg AddrDone; // Indica se a operacao acabou

	// MEM Unit
		reg MemBusy; // Indica se a unidade de enderecamento esta ocupada
		reg [15:0] dataMem [63:0]; // Memoria de dados
		
	// temporaries
		reg [3:0]instr0;
			reg [3:0]instr0ParamA;
			reg [3:0]instr0ParamB;
			reg [3:0]instr0ParamC;
		reg [3:0]instr1;
			reg [3:0]instr1ParamA;
			reg [3:0]instr1ParamB;
			reg [3:0]instr1ParamC;
		reg[$clog2(ROBSIZE):0] ROBSlots;
		integer i,j; // Iteration var
		reg iHateVerilog666;		
		
		always @(posedge clock) 
		begin
			if (run) 
			begin
				instr0 = instrMem[pc][15:12];
					instr0ParamA = instrMem[pc][11:8];
					instr0ParamB = instrMem[pc][7:4];
					instr0ParamC = instrMem[pc][3:0];
				instr1 = instrMem[pc+1][15:12];
					instr1ParamA = instrMem[pc+1][11:8];
					instr1ParamB = instrMem[pc+1][7:4];
					instr1ParamC = instrMem[pc+1][3:0];
				iHateVerilog666=1; // Grrr 
				ROBSlots=0;
				for(i=0;i<ROBSIZE;i=i+1)
					if(ReordenationBufferBusy[i]==0)
						ROBSlots=ROBSlots+1;

				// 2 - Coloca instrucões nas unides funcionais
				if(SumBusy==0)
				begin
					for (i=0; i<RESERVATIONSIZE; i=i+1)
					begin
						if(SumBusy==0)
						if (reservationStationAddBusy[i] == 1'b1) // Indices que estao ocupados
						begin
							if(reservationStationAddJusy[i]==0 & reservationStationAddKusy[i]==0) // Nao há dependencia
							begin
								SumBusy=1;
								SumParamB=reservationStationAddVj[i];
								SumParamC=reservationStationAddVk[i];
								SumIndex=i;
								SumState=0;
								SumDone=0;
								if(reservationStationAddOp[i]==4'b0001) // soma
									SumOp=1;
								else if(reservationStationAddOp[i]==4'b0001) // subtracao
									SumOp=0;
								else if(reservationStationAddOp[i]==4'b0001) // beq
									SumOp=2;
							end
						end
					end
				end
				if(MulBusy==0)
				begin
					for (i=0; i<RESERVATIONSIZE; i=i+1)
					begin
						if(MulBusy==0)
						if (reservationStationMulBusy[i] == 1'b1) // Indices que estao ocupados
						begin
							if(reservationStationMulJusy[i]==0 & reservationStationMulKusy[i]==0) // Nao há dependencia
							begin
								MulBusy=1;
								MulParamB=reservationStationMulVj[i];
								MulParamC=reservationStationMulVk[i];
								MulIndex=i;
								MulState=0;
								MulDone=0;
								if(reservationStationMulOp[i]==4'b0011)
									MulOp=1;
								else
									MulOp=0;
							end
						end
					end
				end
				if(AddrBusy==0)
				begin
					for (i=0; i<RESERVATIONSIZE; i=i+1)
					begin
						if(AddrBusy==0)
						if (reservationStationStBusy[i] == 1'b1) // Indices que estao ocupados
						begin
							if(reservationStationStJusy[i]==0 & reservationStationStKusy[i]==0) // Nao há dependencia
							begin
								AddrBusy=1;
								AddrParamB=reservationStationStOffset[i];
								AddrParamC=reservationStationStVj[i];
								AddrIndex=i;
								AddrState=0;
								AddrDone=0;
								AddrOp=1; // store
							end
						end
					end
				end
				if(AddrBusy==0)
				begin
					for (i=0; i<RESERVATIONSIZE; i=i+1)
					begin
						if(AddrBusy==0)
						if (reservationStationLdBusy[i] == 1'b1) // Indices que estao ocupados
						begin
							if(reservationStationLdJusy[i]==0) // Nao há dependencia
							begin
								AddrBusy=1;
								AddrParamB=reservationStationLdOffset[i];
								AddrParamC=reservationStationLdVj[i];
								AddrIndex=i;
								AddrState=0;
								AddrDone=0;
								AddrOp=0; // load
							end
						end
					end
				end
					
				// 1 - Despacho (todas as instrucões em um clock)
				if(ROBSlots>0) // Ve se ha espaco no ROB
				begin
					if(instr0 == 4'b0001 | instr0 == 4'b0010 | instr0 == 4'b0111) // Estacao de reserva ADD SUB e BEQ
					begin
						iHateVerilog666=1;
						for (i=0; i<RESERVATIONSIZE; i=i+1)
						begin
							if(iHateVerilog666)
							begin
								if (reservationStationAddBusy[i] == 1'b0) // Primeiro indice vazio
								begin
									reservationStationAddBusy[i]=1'b1; // Ocupa a posicao
									reservationStationAddOp[i]=instr0; // Indica operacao da estacao de reserva
									reservationStationAddLabel[i]=pc; // Coloca a label na estacao de reserva
									if (registersBankHaveLabel[instr0ParamB]) // Verifica se há dependencia de dados em B
									begin
										reservationStationAddJusy[i]=1'b1; // Habilita escrita em Qj
										reservationStationAddQj[i]=registersBankLabel[instr0ParamB]; // Escreve em Qj a label
									end
									else
									begin
										reservationStationAddJusy[i]=1'b0; // Habilita escrita em Vj
										reservationStationAddVj[i]=registersBank[instr0ParamB]; // Escreve em Vj o valor
									end
									
									if (registersBankHaveLabel[instr0ParamC])// Verifica se há dependencia de dados em C
									begin
										reservationStationAddKusy[i]=1'b1; // Habilita escrita em Qk
										reservationStationAddQk[i]=registersBankLabel[instr0ParamC]; // Escreve em Qk a label
									end
									else
									begin
										reservationStationAddKusy[i]=1'b0; // Habilita escrita em Vk
										reservationStationAddVk[i]=registersBank[instr0ParamC]; // Escreve em Vk o valor
									end
									if(reservationStationAddJusy[i]==0&reservationStationAddKusy[i]==0)//sem dependencia
									begin
										registersBankHaveLabel[instr0ParamA]=1'b1; // Habilita a label no banco de registradores
										registersBankLabel[instr0ParamA] = pc; // Coloca a label no banco de registradores 
									end
									for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
									begin
										if(iHateVerilog666)
										begin
											if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
											begin
												ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
												ReordenationBufferOp[ReordenationBufferIndex+j]=instr0; // identifica a operacao
												ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
												ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
												iHateVerilog666=0; // Break
											end
										end
									end
									if(instr0 == 4'b0111) // desvio
										pc=instr0ParamA;
									iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
								end
							end
						end
					end
					else if(instr0 == 4'b0011 | instr0 == 4'b0100) // Estacao de reserva MUL e DIV
					begin
						iHateVerilog666=1;
						for (i=0; i<RESERVATIONSIZE; i=i+1)
						begin
							if(iHateVerilog666)
							begin
								if (reservationStationMulBusy[i] == 1'b0) // Primeiro indice vazio
								begin
									reservationStationMulBusy[i]=1'b1; // Ocupa a posicao
									reservationStationMulOp[i]=instr0; // Indica operacao da estacao de reserva
									reservationStationMulLabel[i]=pc; // Coloca a label na estacao de reserva
									if (registersBankHaveLabel[instr0ParamB]) // Verifica se há dependencia de dados em B
									begin
										reservationStationMulJusy[i]=1'b1; // Habilita escrita em Qj
										reservationStationMulQj[i]=registersBankLabel[instr0ParamB]; // Escreve em Qj a label
									end
									else
									begin
										reservationStationMulJusy[i]=1'b0; // Habilita escrita em Vj
										reservationStationMulVj[i]=registersBank[instr0ParamB]; // Escreve em Vj o valor
									end
									
									if (registersBankHaveLabel[instr0ParamC])// Verifica se há dependencia de dados em C
									begin
										reservationStationMulKusy[i]=1'b1; // Habilita escrita em Qk
										reservationStationMulQk[i]=registersBankLabel[instr0ParamC]; // Escreve em Qk a label
									end
									else
									begin
										reservationStationMulKusy[i]=1'b0; // Habilita escrita em Vk
										reservationStationMulVk[i]=registersBank[instr0ParamC]; // Escreve em Vk o valor
									end
									if(reservationStationMulJusy[i]==0&reservationStationMulKusy[i]==0)//sem dependencia
									begin
										registersBankHaveLabel[instr0ParamA]=1'b1; // Habilita a label no banco de registradores
										registersBankLabel[instr0ParamA] = pc; // Coloca a label no banco de registradores 
									end
									for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
									begin
										if(iHateVerilog666)
										begin
											if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
											begin
												ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
												ReordenationBufferOp[ReordenationBufferIndex+j]=instr0; // identifica a operacao
												ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
												ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
												iHateVerilog666=0; // Break
											end
										end
									end
									iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
								end
							end
						end
					end
					else if(instr0 == 4'b0101) // Estacao de reserva LD
					begin
						iHateVerilog666=1;
						for (i=0; i<RESERVATIONSIZE; i=i+1)
						begin
							if(iHateVerilog666)
							begin
								if (reservationStationLdBusy[i] == 1'b0) // Primeiro indice vazio
								begin
									reservationStationLdBusy[i]=1'b1; // Ocupa a posicao
									reservationStationLdLabel[i]=pc; // Coloca a label na estacao de reserva
									reservationStationLdOffset[i]=instr0ParamB; // Grava o Offset
									if (registersBankHaveLabel[instr0ParamC]) // Verifica se há dependencia de dados em B
									begin
										reservationStationLdJusy[i]=1'b1; // Habilita escrita em Qj
										reservationStationLdQj[i]=registersBankLabel[instr0ParamC]; // Escreve em Qj a label
									end
									else
									begin
										reservationStationLdJusy[i]=1'b0; // Habilita escrita em Vj
										reservationStationLdVj[i]=registersBank[instr0ParamC]; // Escreve em Vj o valor
									end
									
									if(reservationStationLdJusy[i]==0)//sem dependencia
									begin
										registersBankHaveLabel[instr0ParamA]=1'b1; // Habilita a label no banco de registradores
										registersBankLabel[instr0ParamA] = pc; // Coloca a label no banco de registradores 
									end
									for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
									begin
										if(iHateVerilog666)
										begin
											if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
											begin
												ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
												ReordenationBufferOp[ReordenationBufferIndex+j]=instr0; // identifica a operacao
												ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
												ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
												iHateVerilog666=0; // Break
											end
										end
									end
									iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
								end
							end
						end
					end
					else if(instr0 == 4'b0110) // Estacao de reserva ST
					begin
						iHateVerilog666=1;
						for (i=0; i<RESERVATIONSIZE; i=i+1)
						begin
							if(iHateVerilog666)
							begin
								if (reservationStationStBusy[i] == 1'b0) // Primeiro indice vazio
								begin
									reservationStationStBusy[i]=1'b1; // Ocupa a posicao
									reservationStationStLabel[i]=pc; // Coloca a label na estacao de reserva
									reservationStationStOffset[i]=instr0ParamB; // Grava o Offset
									if (registersBankHaveLabel[instr0ParamC]) // Verifica se há dependencia de dados em B
									begin
										reservationStationStJusy[i]=1'b1; // Habilita escrita em Qj
										reservationStationStQj[i]=registersBankLabel[instr0ParamC]; // Escreve em Qj a label
									end
									else
									begin
										reservationStationStJusy[i]=1'b0; // Habilita escrita em Vj
										reservationStationStVj[i]=registersBank[instr0ParamC]; // Escreve em Vj o valor
									end
									if (registersBankHaveLabel[instr0ParamA])// Verifica se há dependencia de dados em Valor
									begin
										reservationStationStKusy[i]=1'b1; // Habilita escrita em Qk
										reservationStationStQk[i]=registersBankLabel[instr0ParamA]; // Escreve em Qk a label
									end
									else
									begin
										reservationStationStKusy[i]=1'b0; // Habilita escrita em Vk
										reservationStationStVk[i]=registersBank[instr0ParamA]; // Escreve em Vk o valor
									end

									for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
									begin
										if(iHateVerilog666)
										begin
											if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
											begin
												ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
												ReordenationBufferOp[ReordenationBufferIndex+j]=instr0; // identifica a operacao
												ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
												ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
												iHateVerilog666=0; // Break
											end
										end
									end
									iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
								end
							end
						end
					end
					if(iHateVerilog666 == 0)
					begin
						pc=pc+1;
						if(instr0 != 4'b1001 && ROBSlots>1) // segundo despacho
						begin
							//--------------------------------
							if(instr1 == 4'b0001 | instr1 == 4'b0010 | instr1 == 4'b0111) // Estacao de reserva ADD SUB e BEQ
							begin
								iHateVerilog666=1;
								for (i=0; i<RESERVATIONSIZE; i=i+1)
								begin
									if(iHateVerilog666)
									begin
										if (reservationStationAddBusy[i] == 1'b0) // Primeiro indice vazio
										begin
											reservationStationAddBusy[i]=1'b1; // Ocupa a posicao
											reservationStationAddOp[i]=instr1; // Indica operacao da estacao de reserva 
											reservationStationAddLabel[i]=pc; // Coloca a label na estacao de reserva
											if (registersBankHaveLabel[instr1ParamB]) // Verifica se há dependencia de dados em B
											begin
												reservationStationAddJusy[i]=1'b1; // Habilita escrita em Qj
												reservationStationAddQj[i]=registersBankLabel[instr1ParamB]; // Escreve em Qj a label
											end
											else
											begin
												reservationStationAddJusy[i]=1'b0; // Habilita escrita em Vj
												reservationStationAddVj[i]=registersBank[instr1ParamB]; // Escreve em Vj o valor
											end
											
											if (registersBankHaveLabel[instr1ParamC])// Verifica se há dependencia de dados em C
											begin
												reservationStationAddKusy[i]=1'b1; // Habilita escrita em Qk
												reservationStationAddQk[i]=registersBankLabel[instr1ParamC]; // Escreve em Qk a label
											end
											else
											begin
												reservationStationAddKusy[i]=1'b0; // Habilita escrita em Vk
												reservationStationAddVk[i]=registersBank[instr1ParamC]; // Escreve em Vk o valor
											end
											if(reservationStationAddJusy[i]==0&reservationStationAddKusy[i]==0)//sem dependencia
											begin
												registersBankHaveLabel[instr1ParamA]=1'b1; // Habilita a label no banco de registradores
												registersBankLabel[instr1ParamA] = pc; // Coloca a label no banco de registradores 
											end
											for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
											begin
												if(iHateVerilog666)
												begin
													if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
													begin
														ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
														ReordenationBufferOp[ReordenationBufferIndex+j]=instr1; // identifica a operacao
														ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
														ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
														iHateVerilog666=0; // Break
													end
												end
											end
											if(instr0 == 4'b0111)//desvio
												pc=instr0ParamA;
											iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
										end
									end
								end
							end
							else if(instr1 == 4'b0011 | instr1 == 4'b0100) // Estacao de reserva MUL e DIV
							begin
								iHateVerilog666=1;
								for (i=0; i<RESERVATIONSIZE; i=i+1)
								begin
									if(iHateVerilog666)
									begin
										if (reservationStationMulBusy[i] == 1'b0) // Primeiro indice vazio
										begin
											reservationStationMulBusy[i]=1'b1; // Ocupa a posicao
											reservationStationMulOp[i]=instr1; // Indica operacao da estacao de reserva 
											reservationStationAddLabel[i]=pc; // Coloca a label na estacao de reserva
											if (registersBankHaveLabel[instr1ParamB]) // Verifica se há dependencia de dados em B
											begin
												reservationStationMulJusy[i]=1'b1; // Habilita escrita em Qj
												reservationStationMulQj[i]=registersBankLabel[instr1ParamB]; // Escreve em Qj a label
											end
											else
											begin
												reservationStationMulJusy[i]=1'b0; // Habilita escrita em Vj
												reservationStationMulVj[i]=registersBank[instr1ParamB]; // Escreve em Vj o valor
											end
										
											if (registersBankHaveLabel[instr1ParamC])// Verifica se há dependencia de dados em C
											begin
												reservationStationMulKusy[i]=1'b1; // Habilita escrita em Qk
												reservationStationMulQk[i]=registersBankLabel[instr1ParamC]; // Escreve em Qk a label
											end
											else
											begin
												reservationStationMulKusy[i]=1'b0; // Habilita escrita em Vk
												reservationStationMulVk[i]=registersBank[instr1ParamC]; // Escreve em Vk o valor
											end
											if(reservationStationMulJusy[i]==0&reservationStationMulKusy[i]==0)//sem dependencia
											begin
												registersBankHaveLabel[instr1ParamA]=1'b1; // Habilita a label no banco de registradores
												registersBankLabel[instr1ParamA] = pc; // Coloca a label no banco de registradores 
											end
											for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
											begin
												if(iHateVerilog666)
												begin
													if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
													begin
														ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
														ReordenationBufferOp[ReordenationBufferIndex+j]=instr1; // identifica a operacao
														ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
														ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
														iHateVerilog666=0; // Break
													end
												end
											end
											iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
										end
									end
								end
							end
							else if(instr1 == 4'b0101) // Estacao de reserva LD
							begin
								//--------------------------------
								iHateVerilog666=1;
								for (i=0; i<RESERVATIONSIZE; i=i+1)
								begin
									if(iHateVerilog666)
									begin
										if (reservationStationLdBusy[i] == 1'b0) // Primeiro indice vazio
										begin
											reservationStationLdBusy[i]=1'b1; // Ocupa a posicao
											reservationStationLdLabel[i]=pc; // Coloca a label na estacao de reserva
											reservationStationLdOffset[i]=instr1ParamB; // Grava o Offset
											if (registersBankHaveLabel[instr1ParamC]) // Verifica se há dependencia de dados em B
											begin
												reservationStationLdJusy[i]=1'b1; // Habilita escrita em Qj
												reservationStationLdQj[i]=registersBankLabel[instr1ParamC]; // Escreve em Qj a label
											end
											else
											begin
												reservationStationLdJusy[i]=1'b0; // Habilita escrita em Vj
												reservationStationLdVj[i]=registersBank[instr1ParamC]; // Escreve em Vj o valor
											end
											
											if(reservationStationLdJusy[i]==0)//sem dependencia
											begin
												registersBankHaveLabel[instr1ParamA]=1'b1; // Habilita a label no banco de registradores
												registersBankLabel[instr1ParamA] = pc; // Coloca a label no banco de registradores 
											end
											for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
											begin
												if(iHateVerilog666)
												begin
													if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
													begin
														ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
														ReordenationBufferOp[ReordenationBufferIndex+j]=instr1; // identifica a operacao
														ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
														ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
														iHateVerilog666=0; // Break
													end
												end
											end
											iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
										end
									end
								end
								//--------------------------------
							end
							//--------------------------------
							else if(instr0 == 4'b0110) // Estacao de reserva ST
							begin
								iHateVerilog666=1;
								for (i=0; i<RESERVATIONSIZE; i=i+1)
								begin
									if(iHateVerilog666)
									begin
										if (reservationStationStBusy[i] == 1'b0) // Primeiro indice vazio
										begin
											reservationStationStBusy[i]=1'b1; // Ocupa a posicao
											reservationStationStLabel[i]=pc; // Coloca a label na estacao de reserva
											reservationStationStOffset[i]=instr1ParamB; // Grava o Offset
											if (registersBankHaveLabel[instr1ParamC]) // Verifica se há dependencia de dados em B
											begin
												reservationStationStJusy[i]=1'b1; // Habilita escrita em Qj
												reservationStationStQj[i]=registersBankLabel[instr1ParamC]; // Escreve em Qj a label
											end
											else
											begin
												reservationStationStJusy[i]=1'b0; // Habilita escrita em Vj
												reservationStationStVj[i]=registersBank[instr1ParamC]; // Escreve em Vj o valor
											end
											if (registersBankHaveLabel[instr0ParamA])// Verifica se há dependencia de dados em Valor
											begin
												reservationStationStKusy[i]=1'b1; // Habilita escrita em Qk
												reservationStationStQk[i]=registersBankLabel[instr1ParamA]; // Escreve em Qk a label
											end
											else
											begin
												reservationStationStKusy[i]=1'b0; // Habilita escrita em Vk
												reservationStationStVk[i]=registersBank[instr1ParamA]; // Escreve em Vk o valor
											end

											for(j=0;j<ROBSIZE;j=j+1) // vai pro buffer de reordenacao
											begin
												if(iHateVerilog666)
												begin
													if(ReordenationBufferBusy[ReordenationBufferIndex+j]==0) // Espaco no ROB na posicao mais proxima
													begin
														ReordenationBufferBusy[ReordenationBufferIndex+j]=1; // Ocupa o espaco
														ReordenationBufferOp[ReordenationBufferIndex+j]=instr1; // identifica a operacao
														ReordenationBufferLabel[ReordenationBufferIndex+j]=pc; // Funciona como a tag
														ReordenationBufferHaveValue[ReordenationBufferIndex+j]=0; // limpa o valor
														iHateVerilog666=0; // Break
													end
												end
											end
											iHateVerilog666=0; // Break indicando que houve despacho da primeira instrucao
										end
									end
								end
							end
							//--------------------------------
							if(iHateVerilog666 == 0)
								pc=pc+1;
						end
					end
				end
				// 5 - Confirma ROB
				if(ReordenationBufferHaveValue[ReordenationBufferIndex]==1&ReordenationBufferBusy[ReordenationBufferIndex]==1) // Confirma
				begin
					if(ReordenationBufferOp[ReordenationBufferIndex]==4'b0111) // se for desvio verifica
					begin
						if(ReordenationBufferValue[ReordenationBufferIndex]!=ReordenationBufferLabel[ReordenationBufferIndex]) // erowww
						begin
							pc=ReordenationBufferValue[ReordenationBufferIndex]+1; // coloca o pc certo
							ReordenationBufferIndex=0;
							for(i=0;i<ROBSIZE;i=i+1) // limpa o rob
								ReordenationBufferBusy[i]=0;
							for(i=0;i<RESERVATIONSIZE;i=i+1) // limpa as estacoes
							begin
								reservationStationAddBusy[i]=0;
								reservationStationMulBusy[i]=0;
								reservationStationLdBusy[i]=0;
								reservationStationStBusy[i]=0;
							end
						end
					end
					else if(ReordenationBufferOp[ReordenationBufferIndex]==4'b0110) // se for store grava na memoria
					begin
						MemBusy=1;
						for(i=0;i<RESERVATIONSIZE;i=i+1)
						begin
							if(reservationStationStLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
								dataMem[ReordenationBufferValue[ReordenationBufferIndex]]=reservationStationStVk[i];
						end
					end
					else begin // se nao for store
						for(i=0;i<16;i=i+1) // percorre o banco de registradores para gravar o resultado
						begin
							if(registersBankHaveLabel[i])
							if(registersBankLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
							begin
								registersBankHaveLabel[i]=0;
								registersBank[i]=ReordenationBufferValue[ReordenationBufferIndex];
							end
						end

						for(i=0;i<RESERVATIONSIZE;i=i+1) // percorre estacoes de reserva para atualizar dependencias
						begin
							if(reservationStationAddJusy[i]==0&reservationStationAddKusy[i]==0&reservationStationAddOp[i]!=4'b0111)//grava nos registradores a label
							begin
								registersBankLabel[instrMem[reservationStationAddLabel[i]][11:8]]=reservationStationAddLabel[i];
								registersBankHaveLabel[instrMem[reservationStationAddLabel[i]][11:8]]=1;
							end
							if(reservationStationMulJusy[i]==0&reservationStationMulKusy[i]==0)//grava nos registradores a label
							begin
								registersBankLabel[instrMem[reservationStationMulLabel[i]][11:8]]=reservationStationMulLabel[i];
								registersBankHaveLabel[instrMem[reservationStationMulLabel[i]][11:8]]=1;
							end
							if(reservationStationLdJusy[i]==0)//grava nos registradores a label
							begin
								registersBankLabel[instrMem[reservationStationLdLabel[i]][11:8]]=reservationStationLdLabel[i];
								registersBankHaveLabel[instrMem[reservationStationLdLabel[i]][11:8]]=1;
							end
						end
					end
					if(ReordenationBufferBusy[ReordenationBufferIndex]==1) // evita de limpar e avancar se errou o desvio
					begin
						for(i=0;i<RESERVATIONSIZE;i=i+1) // limpa a estacao de reserva usada
						begin
							if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0001 | ReordenationBufferOp[ReordenationBufferIndex] == 4'b0010 | ReordenationBufferOp[ReordenationBufferIndex] == 4'b1001)
							begin
								if(reservationStationAddLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
									reservationStationAddBusy[i]=0;
							end
							else if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0011 | ReordenationBufferOp[ReordenationBufferIndex] == 4'b0100) 
							begin
								if(reservationStationMulLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
									reservationStationMulLabel[i]=0;
							end
							else if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0101)
							begin
								if(reservationStationLdLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
									reservationStationLdBusy[i]=0;
							end
							else if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0110)
							begin
								if(reservationStationStLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
									reservationStationStBusy[i]=0;
							end
						end

						ReordenationBufferBusy[ReordenationBufferIndex]=0; // desocupa o ROB
						ReordenationBufferIndex=ReordenationBufferIndex+1; // avanca no ponteiro
					end
					// Confirmacao dupla
					//--------------------------------
						if(ReordenationBufferHaveValue[ReordenationBufferIndex]==1&ReordenationBufferBusy[ReordenationBufferIndex]==1) // Confirma
						begin
							if(ReordenationBufferOp[ReordenationBufferIndex]==4'b0111) // se for desvio verifica
							begin
								if(ReordenationBufferValue[ReordenationBufferIndex]!=ReordenationBufferLabel[ReordenationBufferIndex]) // erowww
								begin
									pc=ReordenationBufferValue[ReordenationBufferIndex]+1; // coloca o pc certo
									ReordenationBufferIndex=0;
									for(i=0;i<ROBSIZE;i=i+1) // limpa o rob
										ReordenationBufferBusy[i]=0;
									for(i=0;i<RESERVATIONSIZE;i=i+1) // limpa as estacoes
									begin
										reservationStationAddBusy[i]=0;
										reservationStationMulBusy[i]=0;
										reservationStationLdBusy[i]=0;
										reservationStationStBusy[i]=0;
									end
								end
							end
							else if(ReordenationBufferOp[ReordenationBufferIndex]==4'b0110) // se for store grava na memoria
							begin
								MemBusy=1;
								for(i=0;i<RESERVATIONSIZE;i=i+1)
								begin
									if(reservationStationStLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
										dataMem[ReordenationBufferValue[ReordenationBufferIndex]]=reservationStationStVk[i];
								end
							end
							else begin // se nao for store
								for(i=0;i<16;i=i+1) // percorre o banco de registradores para gravar o resultado
								begin
									if(registersBankHaveLabel[i])
									if(registersBankLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
									begin
										registersBankHaveLabel[i]=0;
										registersBank[i]=ReordenationBufferValue[ReordenationBufferIndex];
									end
								end

								for(i=0;i<RESERVATIONSIZE;i=i+1) // percorre estacoes de reserva para atualizar dependencias
								begin
									if(reservationStationAddJusy[i]==0&reservationStationAddKusy[i]==0&reservationStationAddOp[i]!=4'b0111)//grava nos registradores a label
									begin
										registersBankLabel[instrMem[reservationStationAddLabel[i]][11:8]]=reservationStationAddLabel[i];
										registersBankHaveLabel[instrMem[reservationStationAddLabel[i]][11:8]]=1;
									end
									if(reservationStationMulJusy[i]==0&reservationStationMulKusy[i]==0)//grava nos registradores a label
									begin
										registersBankLabel[instrMem[reservationStationMulLabel[i]][11:8]]=reservationStationMulLabel[i];
										registersBankHaveLabel[instrMem[reservationStationMulLabel[i]][11:8]]=1;
									end
									if(reservationStationLdJusy[i]==0)//grava nos registradores a label
									begin
										registersBankLabel[instrMem[reservationStationLdLabel[i]][11:8]]=reservationStationLdLabel[i];
										registersBankHaveLabel[instrMem[reservationStationLdLabel[i]][11:8]]=1;
									end
								end
							end
							if(ReordenationBufferBusy[ReordenationBufferIndex]==1) // evita de limpar e avancar se errou o desvio
							begin
								for(i=0;i<RESERVATIONSIZE;i=i+1) // limpa a estacao de reserva usada
								begin
									if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0001 | ReordenationBufferOp[ReordenationBufferIndex] == 4'b0010 | ReordenationBufferOp[ReordenationBufferIndex] == 4'b1001)
									begin
										if(reservationStationAddLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
											reservationStationAddBusy[i]=0;
									end
									else if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0011 | ReordenationBufferOp[ReordenationBufferIndex] == 4'b0100) 
									begin
										if(reservationStationMulLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
											reservationStationMulLabel[i]=0;
									end
									else if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0101)
									begin
										if(reservationStationLdLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
											reservationStationLdBusy[i]=0;
									end
									else if(ReordenationBufferOp[ReordenationBufferIndex] == 4'b0110)
									begin
										if(reservationStationStLabel[i]==ReordenationBufferLabel[ReordenationBufferIndex])
											reservationStationStBusy[i]=0;
									end
								end

								ReordenationBufferBusy[ReordenationBufferIndex]=0; // desocupa o ROB
								ReordenationBufferIndex=ReordenationBufferIndex+1; // avanca no ponteiro
							end
						end	
					//--------------------------------
				end
	
			
				// 4 - Escreve no CDB
				if(SumDone==1|MulDone==1|AddrDone==1) // verifica se há algo para gravar
				begin
					if(MulDone==1 & CDBusy==0) // prioridade de gravar uma multiplicacao, vê se há alguma pronta
					begin
						CDBusy=1;

						for(i=0;i<ROBSIZE;i=i+1) // Grava o resultado no ROB
						begin
							if(ReordenationBufferBusy[i]==1 & ReordenationBufferLabel[i]==reservationStationMulLabel[MulIndex]) // tag deu match
							begin
								ReordenationBufferValue[i]=MulValue;
								ReordenationBufferHaveValue[i]=1;
							end
						end

						for(i=0;i<RESERVATIONSIZE;i=i+1) // percorre estacoes de reserva procurando dependencia
						begin
							if(reservationStationAddJusy[i]==1) //  ha dependencia
							if(reservationStationAddQj[i]==reservationStationMulLabel[MulIndex])
							begin
								reservationStationAddVj[i]=MulValue; // grava o valor
								reservationStationAddJusy[i]=0; // remove a dependencia
							end
							if(reservationStationAddKusy[i]==1) //  ha dependencia
							if(reservationStationAddQk[i]==reservationStationMulLabel[MulIndex])
							begin
								reservationStationAddVk[i]=MulValue; // grava o valor
								reservationStationAddKusy[i]=0; // remove a dependencia
							end
							if(reservationStationMulJusy[i]==1) //  ha dependencia
							if(reservationStationMulQj[i]==reservationStationMulLabel[MulIndex])
							begin
								reservationStationMulVj[i]=MulValue; // grava o valor
								reservationStationMulJusy[i]=0; // remove a dependencia
							end
							if(reservationStationMulKusy[i]==1) //  ha dependencia
							if(reservationStationMulQk[i]==reservationStationMulLabel[MulIndex])
							begin
								reservationStationMulVk[i]=MulValue; // grava o valor
								reservationStationMulKusy[i]=0; // remove a dependencia
							end
							if(reservationStationLdJusy[i]==1) //  ha dependencia
							if(reservationStationLdQj[i]==reservationStationLdLabel[MulIndex])
							begin
								reservationStationLdVj[i]=MulValue; // grava o valor
								reservationStationLdJusy[i]=0; // remove a dependencia
							end
							if(reservationStationStJusy[i]==1) //  ha dependencia
							if(reservationStationStQj[i]==reservationStationStLabel[MulIndex])
							begin
								reservationStationStVj[i]=MulValue; // grava o valor
								reservationStationStJusy[i]=0; // remove a dependencia
							end
							if(reservationStationStKusy[i]==1) //  ha dependencia
							if(reservationStationStQk[i]==reservationStationStLabel[MulIndex])
							begin
								reservationStationStVk[i]=MulValue; // grava o valor
								reservationStationStKusy[i]=0; // remove a dependencia
							end
						end
						MulDone=0; MulBusy=0;// desocupa a unidade
						CDBusy=0; // desocupa o cdb
					end
					else if(SumDone==1 & CDBusy==0 & SumOp != 2)
					begin
						CDBusy=1;

						for(i=0;i<ROBSIZE;i=i+1) // Grava o resultado no ROB
						begin
							if(ReordenationBufferBusy[i]==1 & ReordenationBufferLabel[i]==reservationStationAddLabel[SumIndex]) // tag deu match
							begin
								ReordenationBufferValue[i]=SumValue;
								ReordenationBufferHaveValue[i]=1;
							end
						end
						
						for(i=0;i<RESERVATIONSIZE;i=i+1) // percorre estacoes de reserva procurando dependencia
						begin
							if(reservationStationAddJusy[i]==1) //  ha dependencia
							if(reservationStationAddQj[i]==reservationStationAddLabel[SumIndex])
							begin
								reservationStationAddVj[i]=SumValue; // grava o valor
								reservationStationAddJusy[i]=0; // remove a dependencia
							end
							if(reservationStationAddKusy[i]==1) //  ha dependencia
							if(reservationStationAddQk[i]==reservationStationAddLabel[SumIndex])
							begin
								reservationStationAddVk[i]=SumValue; // grava o valor
								reservationStationAddKusy[i]=0; // remove a dependencia
							end
							if(reservationStationMulJusy[i]==1) //  ha dependencia
							if(reservationStationMulQj[i]==reservationStationAddLabel[SumIndex])
							begin
								reservationStationMulVj[i]=SumValue; // grava o valor
								reservationStationMulJusy[i]=0; // remove a dependencia
							end
							if(reservationStationMulKusy[i]==1) //  ha dependencia
							if(reservationStationMulQk[i]==reservationStationAddLabel[SumIndex])
							begin
								reservationStationMulVk[i]=SumValue; // grava o valor
								reservationStationMulKusy[i]=0; // remove a dependencia
							end
							if(reservationStationLdJusy[i]==1) //  ha dependencia
							if(reservationStationLdQj[i]==reservationStationAddLabel[SumIndex])
							begin
								reservationStationLdVj[i]=SumValue; // grava o valor
								reservationStationLdJusy[i]=0; // remove a dependencia
							end
							if(reservationStationStJusy[i]==1) //  ha dependencia
							if(reservationStationStQj[i]==reservationStationStLabel[SumIndex])
							begin
								reservationStationStVj[i]=SumValue; // grava o valor
								reservationStationStJusy[i]=0; // remove a dependencia
							end
							if(reservationStationStKusy[i]==1) //  ha dependencia
							if(reservationStationStQk[i]==reservationStationStLabel[SumIndex])
							begin
								reservationStationStVk[i]=SumValue; // grava o valor
								reservationStationStKusy[i]=0; // remove a dependencia
							end
						end
						SumDone=0; SumBusy=0; // desocupa a unidade
						CDBusy=0; // desocupa o cdb
					end
					else if(AddrDone==1 & AddrOp==0 & CDBusy==0 & MemBusy==0) // Load usa cdb
					begin
						CDBusy=1;
						MemBusy=1;

						for(i=0;i<ROBSIZE;i=i+1) // Grava o resultado no ROB
						begin
							if(ReordenationBufferBusy[i]==1 & ReordenationBufferLabel[i]==reservationStationLdLabel[AddrIndex]) // tag deu match
							begin
								ReordenationBufferValue[i]=dataMem[AddrValue];
								ReordenationBufferHaveValue[i]=1;
							end
						end

						for(i=0;i<RESERVATIONSIZE;i=i+1) // percorre estacoes de reserva procurando dependencia
						begin
							if(reservationStationAddJusy[i]==1) //  ha dependencia
							if(reservationStationAddQj[i]==reservationStationLdLabel[AddrIndex])
							begin
								reservationStationAddVj[i]=dataMem[AddrValue]; // grava o valor
								reservationStationAddJusy[i]=0; // remove a dependencia
							end
							if(reservationStationAddKusy[i]==1) //  ha dependencia
							if(reservationStationAddQk[i]==reservationStationLdLabel[AddrIndex])
							begin
								reservationStationAddVk[i]=dataMem[AddrValue]; // grava o valor
								reservationStationAddKusy[i]=0; // remove a dependencia
							end
							if(reservationStationMulJusy[i]==1) //  ha dependencia
							if(reservationStationMulQj[i]==reservationStationLdLabel[AddrIndex])
							begin
								reservationStationMulVj[i]=dataMem[AddrValue]; // grava o valor
								reservationStationMulJusy[i]=0; // remove a dependencia
							end
							if(reservationStationMulKusy[i]==1) //  ha dependencia
							if(reservationStationMulQk[i]==reservationStationLdLabel[AddrIndex])
							begin
								reservationStationMulVk[i]=dataMem[AddrValue]; // grava o valor
								reservationStationMulKusy[i]=0; // remove a dependencia
							end
							if(reservationStationLdJusy[i]==1) //  ha dependencia
							if(reservationStationLdQj[i]==reservationStationLdLabel[AddrIndex])
							begin
								reservationStationLdVj[i]=dataMem[AddrValue]; // grava o valor
								reservationStationLdJusy[i]=0; // remove a dependencia
							end
							if(reservationStationStJusy[i]==1) //  ha dependencia
							if(reservationStationStQj[i]==reservationStationStLabel[AddrIndex])
							begin
								reservationStationStVj[i]=AddrValue; // grava o valor
								reservationStationStJusy[i]=0; // remove a dependencia
							end
							if(reservationStationStKusy[i]==1) //  ha dependencia
							if(reservationStationStQk[i]==reservationStationStLabel[AddrIndex])
							begin
								reservationStationStVk[i]=AddrValue; // grava o valor
								reservationStationStKusy[i]=0; // remove a dependencia
							end
						end
						AddrDone=0; AddrBusy=0; // desocupa a unidade
						CDBusy=0; // desocupa o cdb
					end
				end
				
				// 3 - Executa Instrucões
				if(AddrBusy==1)
				begin
					if(AddrDone==0)
						case(AddrState)
							0:AddrState=AddrState+1; // Comeca a somar
							1:AddrState=AddrState+1; // Continua a somar
							2:// Termina de somar
							begin
								AddrDone=1;
								AddrValue=AddrParamB+AddrParamC; 
							end
						endcase
				end
				if(SumBusy==1)
				begin
					if(SumDone==0)
						case(SumState)
							0:SumState=SumState+1; // Comeca a somar
							1:SumState=SumState+1; // Continua a somar
							2:// Termina de somar
							begin
								SumDone=1;
								if(SumOp==1)
									SumValue=SumParamB+SumParamC; 
								else
									SumValue=SumParamB-SumParamC;
							end
						endcase
				end
				if(MulBusy==1)
				begin
					if(MulDone==0)
						case(MulState)
							0:MulState=MulState+1; // Comeca a Multiplicar/Dividir
							1:MulState=MulState+1; // Continua a Multiplicar/Dividir
							2:MulState=MulState+1; // Continua a Multiplicar/Dividir
							3:// Termina de Multiplicar ou Continua a Dividir
							begin
								if(MulOp==1)
								begin
									MulValue=MulParamB*MulParamC;
									MulDone=1;
								end
								else
									MulState=MulState+1;
							end
							4:MulState=MulState+1; // Comeca a Dividir
							5:MulState=MulState+1; // Continua a Dividir
							6:MulState=MulState+1; // Continua a Dividir
							3:// Termina de Dividir
							begin
								if(MulOp==0)
								begin
									MulValue=MulParamB/MulParamC;
									MulDone=1;
								end
							end
						endcase
				end

				if(AddrDone==1 & AddrOp==1 & MemBusy==0) // Store nao usa cdb
				begin
					MemBusy=1;
					for(i=0;i<ROBSIZE;i=i+1) // Grava o resultado no ROB
					begin
						if(ReordenationBufferBusy[i]==1 & ReordenationBufferLabel[i]==reservationStationStLabel[AddrIndex]) // tag deu match
						begin
							ReordenationBufferValue=AddrValue;
							ReordenationBufferHaveValue=1;
						end
					end
					AddrDone=0; AddrBusy=0; // desocupa a unidade
				end
				if(SumDone==1 & SumOp==2) // BEQ nao usa cdb
				begin
					for(i=0;i<ROBSIZE;i=i+1) // Grava o resultado no ROB
					begin
						if(ReordenationBufferBusy[i]==1 & ReordenationBufferLabel[i]==reservationStationAddLabel[AddrIndex]) // tag deu match
						begin
							if(SumValue==0) // desvio
								ReordenationBufferValue[i]=instrMem[reservationStationAddLabel[i]][11:8];
							else // sem desvio
								ReordenationBufferValue[i]=reservationStationAddLabel[AddrIndex]
							ReordenationBufferHaveValue[i]=1;
						end
					end
					SumDone=0; SumBusy=0; // desocupa a unidade
				end
				MemBusy=0;
			end
		end
		
		// TODO STORE fazer estacao
		// TODO BEQ (considerar 100% desvio tomado) (TRATAR O QUE MANIPULA ESTACAO DE RESERVA DA SOMA PARA N FAZER OPERACOES COM BEQ)
		
		initial 
		begin

		//TODO INITIAL LD,ST RS
		//TODO INITIAL ADDR UNIT
		//TODO INITIAL ROB

		for(i=0;i<64;i=i+1)
		begin
			instrMem[i]=0;
			dataMem[i]=0;
		end
		
		// Instrucao	 ID 
		instrMem[0]=16'b0001000000010010; // r0=r1+r2
		instrMem[1]=16'b0001000000000011;	// r0=r0+r2
		// END
		
		pc=0;
		for(i=0;i<16;i=i+1)
		begin
			registersBank[i]=i;
			registersBankHaveLabel[i]=0;
		end
		for(i=0;i<RESERVATIONSIZE;i=i+1)
		begin
			reservationStationAddBusy[i]=0;
			reservationStationMulBusy[i]=0;
			reservationStationLdBusy[i]=0;
		end
		CDBusy=0;
		SumBusy=0;
		MulBusy=0;
		AddrBusy=0;
		MemBusy=0;
		end
endmodule 
//mostrar estacao de reserva cheia/vazia, hazard estrutural, cdb(1 por vez), dependencia de dados verdadeira, reomeacao, estacao de reserva funcionando

//STALL - 0 - Stall used splash... Nothing happens!
//ADD   - 1 - 0001 Destino Operando1 Operando2
//SUB   - 2 - 0010 Destino Operando1 Operando2
//MUL   - 3 - 0011 Destino Operando1 Operando2
//DIV   - 4 - 0100 Destino Operando1 Operando2
//LD    - 5 - 0101 Destino Offset Operando1
//SD    - 6 - 0110 Fonte Offset Operando2
//Beck   - 7 - 0111 Endereco Operando1 Operando2