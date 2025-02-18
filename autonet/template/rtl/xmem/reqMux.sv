
`include "common.vh"

module reqMux import xmem_param_pkg::*; #(
	parameter string RANGE_TYPE = "SCALAR",
	parameter MUX_NUM	= 16,
	parameter AW			= 32,
	parameter DW			= 32,
    parameter PORT_IDX      = 0
)
(
	input 								rstn,
	input 								clk,
	//connected to config registers
	input [7:0]		                    mux_num,
	input [XMEM_AW-1:0]					rangeStart 	[MAX_PARTITION],
	
	input [XMEM_AW-1:0]					base		[MUX_NUM],
	input [1:0]							in2Type		[MUX_NUM],
	input [7:0]							in2Width	[MUX_NUM],
	input [7:0]							in2Wport	[MUX_NUM],
	//connected to hls functions
	input 								f_argVld	[MUX_NUM],
	output logic 						f_argAck	[MUX_NUM],
	input [AW-1:0]						f_adr		[MUX_NUM],
	input [DW-1:0]						f_wdat		[MUX_NUM],
	output logic [DW-1:0]				f_rdat,
	output logic                        f_rdat_vld[MUX_NUM],
    //--
    input                               matched,
	input [3:0] 						risc_argWe,
    input [LOG2_MAX_PARTITION-1:0]      risc_argPartIdx,
	input 								risc_argRe,
	output logic 						risc_argAck,
	input [XMEM_AW-1:0]					risc_argAdr,
	input [DW-1:0]						risc_argWdat,
	output logic [DW-1:0]				risc_argRdat,

	//--
	output logic 						    mux_re,
	output logic 						    mux_we,
	output logic [1:0]					    mux_len,
	output logic [LOG2_MAX_PARTITION-1:0]   mux_part_idx,
	output logic [XMEM_AW-1:0]			    mux_adr,
	output logic [DW-1:0]				    mux_din,
	input [DW-1:0]						    mux_dout
);

//-----------------------------------------
//signals
//-----------------------------------------
logic [$clog2(MUX_NUM)-1:0]     selPort;
logic [$clog2(MUX_NUM)-1:0]     selPort_r, selPort_2r;
logic 							f_argRunning	[MUX_NUM];
logic 							f_argRunning_r	[MUX_NUM];
logic 							f_argRunning_2r	[MUX_NUM];
logic 							risc_argRunning;
logic 							risc_argRunning_r, risc_argRunning_2r;
logic [AW+3:0]					inc, inc_r;
logic [DW-1:0]					f_wdat_r;

logic                           mem_type_cyclic;
logic [LOG2_MAX_PARTITION-1:0]  mux_part_idx_w, mux_part_idx_r;
logic 						    mux_re_r;


generate
    if ((RANGE_TYPE=="SCALAR") || (RANGE_TYPE=="ARRAY")) begin
        assign mem_type_cyclic = 0;
    end
    else begin
        assign mem_type_cyclic = 1;
    end
endgenerate

always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		f_argRunning_r	<= '{default: '0};
        f_argRunning_2r <= '{default: '0};
        risc_argRunning_r <= 0;
        risc_argRunning_2r <= 0;
		selPort_r 		<= 0;
        selPort_2r      <= 0;
        inc_r           <= 0;
        f_wdat_r        <= 0;
        //hls_adr_r       <= 0;
        mux_part_idx_r  <= 0;
        mux_re_r        <= 0;
	end
	else begin
		f_argRunning_r	<= f_argRunning;
        f_argRunning_2r <= f_argRunning_r;
        risc_argRunning_r <= risc_argRunning;
        risc_argRunning_2r <= risc_argRunning_r;
		selPort_r 		<= selPort;
        selPort_2r      <= selPort_r;
        inc_r           <= inc;
        f_wdat_r        <= f_wdat[selPort];
        //hls_adr_r       <= hls_adr;
        mux_part_idx_r  <= mux_part_idx_w;
        mux_re_r        <= mux_re;
	end
end

always_comb begin
	f_argRunning 	= '{default: '0};
	selPort 		= selPort_r;
	f_argAck		= '{default: '0};

	mux_re	 	= 0;
	mux_we	 	= 0;
    mux_len = 0;


    risc_argRunning = 0;
    if (((risc_argWe!=0) || risc_argRe) && matched && (PORT_IDX==0)) begin
        risc_argRunning = 1;
        //selPort = risc_argWe ? 0 : 1;
        if (RANGE_TYPE=="CYCLIC") begin
            mux_len = 0;
        end
        else if (risc_argWe!=0) begin
            case (risc_argWe)
                4'h1, 4'h2, 4'h4, 4'h8: mux_len = 0;
                4'h3, 4'hC:             mux_len = 1;
                4'hF:                   mux_len = 3;
                default:                mux_len = 2;	//not used
            endcase
        end
        else if (risc_argRe) begin
            mux_len = 3;
        end
    end
    else begin
        for (int a=0; a<MUX_NUM; a++) begin
            if (f_argVld[a]) begin
                f_argRunning [a] = 1;
                f_argAck[a] = 1;
                selPort = a;
                break;
            end
        end
        if (mem_type_cyclic) begin
            `ifndef XMEM_LATENCY_1
            case (in2Width[selPort_r])
            `else
            case (in2Width[selPort])
            `endif
                'd32:    mux_len = 0;
                'd64:    mux_len = 1;
                'd96:    mux_len = 2;
                'd128:   mux_len = 3;
            endcase
        end
        else begin
            `ifndef XMEM_LATENCY_1
            case (in2Width[selPort_r])
            `else
            case (in2Width[selPort])
            `endif
                'd8:     mux_len = 0;
                'd16:    mux_len = 1;
                'd32:    mux_len = 3;
                default: mux_len = 2;	//not used
            endcase
        end
    end

    /*`ifndef XMEM_LATENCY_1
    	f_argAck[selPort_2r] = f_argRunning_2r[selPort_2r];
    `else
    	f_argAck[selPort_r] = f_argRunning_r[selPort_r];
    `endif*/
    //f_argAck[selPort_r] = f_argRunning_r[selPort_r];
    risc_argAck = risc_argRunning_r;

    if (risc_argRe && matched && (PORT_IDX==0)) begin
        mux_re = 1;
    end
    else if (risc_argWe && matched && (PORT_IDX==0)) begin
        mux_we = 1;
    end
    else begin
    `ifndef XMEM_LATENCY_1
            mux_re	 = f_argRunning_r [selPort_r] && (in2Type[selPort_r] == READ);
            mux_we	 = f_argRunning_r [selPort_r] && (in2Type[selPort_r] == WRITE);
    `else
            mux_re	 = f_argRunning [selPort] && (in2Type[selPort] == READ);
            mux_we	 = f_argRunning [selPort] && (in2Type[selPort] == WRITE);
    `endif
    end

    mux_part_idx_w = f_adr[selPort][XMEM_PART_AW+LOG2_MAX_PARTITION-1:XMEM_PART_AW];
    inc = f_adr[selPort][XMEM_PART_AW-1:0];//<<2;

	//mux_adr	 = base		[selPort] + inc;
	//mux_din	 = f_wdat	[selPort];	//in2Wport
    if ((risc_argWe || risc_argRe) && matched && (PORT_IDX==0)) begin
	    mux_adr	 = risc_argAdr;
	    mux_din	 = risc_argWdat;
        mux_part_idx = risc_argPartIdx;
    end
    `ifndef XMEM_LATENCY_1
        else begin
            mux_part_idx = mux_part_idx_r;
            mux_din	 = f_wdat_r;
			mux_adr	= base[selPort_r] + inc_r;
			//for (int p=0; p<MAX_PARTITION; p++) begin
			//	mux_adr	= base[selPort_r] + inc_r + rangeStart[p];
			//	if (p== mux_part_idx) begin
			//		break;
			//	end
			//end
        end
    `else
        else begin
            mux_part_idx = mux_part_idx_w;
            mux_din	 = f_wdat[selPort];
			mux_adr	= base[selPort] + inc;
			//for (int p=0; p<MAX_PARTITION; p++) begin
			//	mux_adr	= base[selPort] + inc + rangeStart[p];
			//	if (p== mux_part_idx) begin
			//		break;
			//	end
			//end
        end
    `endif

    risc_argRdat = mux_dout;
	f_rdat   = mux_dout;
    f_rdat_vld = '{default: 0};
    `ifndef XMEM_LATENCY_1
    	f_rdat_vld[selPort_2r] = mux_re_r && f_argRunning_2r[selPort_2r] && ~risc_argRunning_r;
    `else
    	f_rdat_vld[selPort_r] = mux_re_r && f_argRunning_r[selPort_r];
    `endif

end





endmodule

