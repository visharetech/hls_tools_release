`ifndef XMEM_INIT_TASK_VH
`define XMEM_INIT_TASK_VH

`define xmem0 inst_top.inst_xcache

//-----------------------------------------------------------------------
//enum declaration
//-----------------------------------------------------------------------
enum {SCALAR, ARRAY, CYCLIC, RANGE_ALL} range_t;


//----------------------------------------------------------
//include xmem parameter 
//----------------------------------------------------------
`include "xmem_param.vh"



//----------------------------------------------------------
//signals 
//----------------------------------------------------------
logic xmem_init_param_done = 0;

int   subBankDepth[PARTITION][RANGE_ALL];


//----------------------------------------------------------
//task
//----------------------------------------------------------






task automatic load_xadr_cmd;
    begin
        xadr_cmd (CMD_PART_NUM, 0, PARTITION);
        //edward 2025-01-22: new address mapping that no partition for array & cyclic
        xadr_cmd (CMD_ARRAY_SUB_RNG_START, 0, subRangeStart[0][ARRAY_S ]);
        xadr_cmd (CMD_CYCLIC_SUB_RNG_START, 0, subRangeStart[0][CYCLIC_S]);
        xadr_cmd (CMD_CYCLIC_MAX_SUB_RNG_START, 0, subRangeStart[0][CYCLIC_S+1]);
        for (int pid= 0; pid<PARTITION; pid++) begin
            xadr_cmd (CMD_SCALAR_SUB_PART_START, pid, subBankStart[pid][SCALAR]);
        end
        xadr_cmd (CMD_ARRAY_SUB_PART_START, 0, subBankStart[0][ARRAY ]);				
        xadr_cmd (CMD_CYCLIC_SUB_PART_START, 0, subBankStart[0][CYCLIC]);
        for (int pid= 0; pid<PARTITION; pid++) begin
            xadr_cmd (CMD_SCALAR_SUB_PART_SIZE, pid, subBankSize[pid][SCALAR]);
        end
        xadr_cmd (CMD_ARRAY_SUB_PART_SIZE, 0, subBankSize[0][ARRAY ]);
        xadr_cmd (CMD_CYCLIC_SUB_PART_SIZE, 0, subBankSize[0][CYCLIC]);        
        /*
        for (int pid= 0; pid<partNum; pid++) begin
            xadr_cmd (CMD_RANGE_START, pid, rangeStart[pid]);
            //$display("rangeStart[%d]: %d\n", pid, rangeStart[pid]);
        end

        for (int pid=0; pid<partNum; pid++) begin
            xadr_cmd (CMD_ARRAY_SUB_RNG_START,   pid, subRangeStart[pid][ARRAY_S ]);
            xadr_cmd (CMD_CYCLIC_SUB_RNG_START,  pid, subRangeStart[pid][CYCLIC_S]);
            xadr_cmd (CMD_CYCLIC_MAX_SUB_RNG_START,  pid, subRangeStart[pid][CYCLIC_S+1]);

            xadr_cmd (CMD_SCALAR_SUB_PART_START, pid, subBankStart[pid][SCALAR]);
            xadr_cmd (CMD_ARRAY_SUB_PART_START,  pid, subBankStart[pid][ARRAY ]);
			
            //$display("subBankStart[%d]: %d\n", pid, subBankStart[pid][ARRAY ]);
			
			
            xadr_cmd (CMD_CYCLIC_SUB_PART_START, pid, subBankStart[pid][CYCLIC]);

            xadr_cmd (CMD_SCALAR_SUB_PART_SIZE, pid, subBankSize[pid][SCALAR]);
            xadr_cmd (CMD_ARRAY_SUB_PART_SIZE,  pid, subBankSize[pid][ARRAY ]);
            xadr_cmd (CMD_CYCLIC_SUB_PART_SIZE, pid, subBankSize[pid][CYCLIC]);
        end
        */
    end
endtask


task load_reqMux_cmd;
	input int offset; 
	input int typeId; 
	input int width; 
	input int muxNum;
	input int s;
	input int ba;
	input int d; 
	input int ap; 
	int b;
	begin 
	
		if (s < bankNum[SCALAR]) begin
			b = s;
			//$display ("[SCALAR] adr: %d, bankAdr: %d, sBank: %d, d: %d, a: %d", offset, ba, b, d, ap);
			reqMux_cmd(CMD_SCALAR_BASE,	 		b, d, ap, offset	);	//byte address
			reqMux_cmd(CMD_SCALAR_TYPE, 		b, d, ap, typeId	);
			reqMux_cmd(CMD_SCALAR_WIDTH,		b, d, ap, width		);
			reqMux_cmd(CMD_SCALAR_MUX_NUM,		b, d, ap, muxNum	);
		end 
		else if (s < bankNum[SCALAR] + bankNum[ARRAY]) begin 
			b = s - bankNum[SCALAR];
			//$display  ("[ARRAY] adr: %d, bankAdr: %d, aBank: %d, d: %d, a: %d", offset, ba, b, d, ap);
			reqMux_cmd(CMD_ARRAY_BASE,	 		b, d, ap, offset 	);	//byte address
			reqMux_cmd(CMD_ARRAY_TYPE, 		b, d, ap, typeId	);
			reqMux_cmd(CMD_ARRAY_WIDTH,		b, d, ap, width		);
			reqMux_cmd(CMD_ARRAY_MUX_NUM,		b, d, ap, muxNum	);
				
		end
		else begin
			b = s - bankNum[SCALAR] - bankNum[ARRAY];
			//$display  ("[CYCLIC] adr: %d, bankAdr: %d, cBank: %d, d: %d, a: %d", offset, ba, b, d, ap);
			reqMux_cmd(CMD_CYCLIC_BASE,	 	b, d, ap, offset	);	//byte address
			reqMux_cmd(CMD_CYCLIC_TYPE, 		b, d, ap, typeId	);
			reqMux_cmd(CMD_CYCLIC_WIDTH,		b, d, ap, width		);
			reqMux_cmd(CMD_CYCLIC_MUX_NUM,		b, d, ap, muxNum	);
			
		end 
	
	end 
endtask 

task automatic reqMux_cmd;
	input [7:0]						cmd;
	input [$clog2(SUPERBANK)-1:0]	s;
    input 						 	d;
	input [7:0]	                    a;
	input [RISC_DWIDTH-1:0]			dat;
	logic [RISC_AWIDTH-1:0]			adr;
	begin
		risc_cmd_write(CMD_SET_SBANK, s);
		risc_cmd_write(CMD_SET_RPORT, d);
		risc_cmd_write(CMD_SET_APORT, a);
		risc_cmd_write(cmd, dat);
	end
endtask

task automatic xadr_cmd;
    input [7:0]							cmd;
    input [$clog2(MAX_PARTITION):0]		pid;
    input [RISC_DWIDTH-1:0]				dat;
    logic [RISC_AWIDTH-1:0]				adr;
    begin
        risc_cmd_write(CMD_SET_PART, pid);
        risc_cmd_write(cmd, dat);
    end
endtask

task automatic risc_cmd_write;
    input [RISC_AWIDTH-1:0] 	adr;
    input [RISC_DWIDTH-1:0] 	dat;
    begin
		riscv_wr(0, XMEM_ACCESS, (adr << 2), dat, 4'b1111);
    end
endtask






`endif

