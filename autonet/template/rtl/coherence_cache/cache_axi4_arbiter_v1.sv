////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2021-05-05
// Description        : AXI4 aribter for MESIF caches.
// Version            : v1.0 - First version.
//                             Assumption:
//                             1. AXI_DATA_WIDTH <= LINE_BITS_SIZE and multiple relationship.
//                             2. If AXI_DATA_WIDTH = DATA_WIDTH, directly connection for data channel.
//                      v1.1 - Handle writeback and refill address conflic.
//                             Writeback must have higher priority.
//                      v1.2 - round-robin arbiter.
//                      v1.3 - m_wlast added.
////////////////////////////////////////////////////////////////////////////////
module cache_axi4_arbiter_v1 import coherence_cache_pkg::*; #(
	parameter CACHE_NUM      = 8,
	parameter ADDR_BITS      = 32,
	parameter SET_NUM        = 1024,
	parameter WORD_PER_LINE  = 8,
	parameter BYTE_PER_WORD  = 4,
	parameter BITS_PER_BYTE  = 8,	
	parameter DATA_WIDTH     = BYTE_PER_WORD * BITS_PER_BYTE,
	parameter LINE_BITS_SIZE = WORD_PER_LINE * DATA_WIDTH,
	parameter AXI_ADDR_WIDTH = ADDR_BITS,
	parameter AXI_DATA_WIDTH = LINE_BITS_SIZE,
	parameter AXI_LEN_WIDTH  = 8,
	parameter AXI_ID_WIDTH   = 8
)
(
	input                                 clk,
	input                                 rstn,
	input                                 en,
	//AXI4 from cache
	output logic                          c_awready[CACHE_NUM],
	input                                 c_awvalid[CACHE_NUM],
	input        [ADDR_BITS - 1 : 0]      c_awaddr [CACHE_NUM],
	//input      [            7 : 0]      c_awlen  [CACHE_NUM],
	output logic                          c_wready [CACHE_NUM],
	input                                 c_wvalid [CACHE_NUM],
	input        [DATA_WIDTH - 1 : 0]     c_wdata  [CACHE_NUM],
	output logic                          c_arready[CACHE_NUM],
	input                                 c_arvalid[CACHE_NUM],
	input        [            7 : 0]      c_arlen  [CACHE_NUM],
	input        [ADDR_BITS - 1 : 0]      c_araddr [CACHE_NUM],
	output logic                          c_rvalid [CACHE_NUM],
	input                                 c_rready [CACHE_NUM],
	output logic [DATA_WIDTH - 1 : 0]     c_rdata  [CACHE_NUM],
	//AXI4 to main memory
	input                                 m_awready,
	output logic                          m_awvalid,	
	output logic [AXI_ADDR_WIDTH - 1 : 0] m_awaddr,
	output logic [AXI_LEN_WIDTH  - 1 : 0] m_awlen,
	output logic [AXI_ID_WIDTH   - 1 : 0] m_awid,
	input                                 m_wready,
	output logic                          m_wvalid,
	output logic                          m_wlast,
	output logic [AXI_DATA_WIDTH - 1 : 0] m_wdata,
	input                                 m_arready,
	output logic                          m_arvalid,	
	output logic [AXI_ADDR_WIDTH - 1 : 0] m_araddr,
	output logic [AXI_LEN_WIDTH  - 1 : 0] m_arlen,
	output logic [AXI_ID_WIDTH   - 1 : 0] m_arid,
	input                                 m_rvalid,
	output logic                          m_rready,
	input        [AXI_DATA_WIDTH - 1 : 0] m_rdata
);

localparam WITH_LINE_BUF     = (AXI_DATA_WIDTH != DATA_WIDTH)? 1 : 0;
localparam CACHE_NUM_BITS    = $clog2(CACHE_NUM);
localparam WORD_BITS         = $clog2(WORD_PER_LINE);
//State
localparam IDLE_STATE  = 2'd0;
localparam START_STATE = 2'd1;
localparam RUN_STATE   = 2'd2;


logic [                 1 : 0] awstate;
logic [CACHE_NUM_BITS - 1 : 0] awsel;
logic                          awsel_vld;
logic [CACHE_NUM_BITS - 1 : 0] aw_rrptr;
logic                          awrun;
logic [WORD_BITS      - 1 : 0] awcnt;
logic                          awaddr_done;
logic                          awdata_done;
logic [                 1 : 0] arstate;
logic [CACHE_NUM_BITS - 1 : 0] arsel;
logic                          arsel_vld;
logic [CACHE_NUM_BITS - 1 : 0] ar_rrptr;
logic [WORD_BITS      - 1 : 0] arcnt;
logic                          araddr_done;
logic                          ardata_done;
logic [LINE_BITS_SIZE - 1 : 0] wbuf;
logic [WORD_BITS      - 1 : 0] wbuf_cnt;
logic                          wbuf_rdy;
logic                          wbuf_vld;
logic [LINE_BITS_SIZE - 1 : 0] rbuf;
logic [WORD_BITS      - 1 : 0] rbuf_cnt;
logic                          rbuf_rdy;
logic                          rbuf_vld;


//---------------------------------------
//Write Channel
//---------------------------------------
always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		c_awready   <= '{default: '0};
		m_awvalid   <= 0;
		m_awaddr    <= 0;
		awsel       <= 0;
		awsel_vld   <= 0;
		aw_rrptr    <= 0;
		awrun       <= 0;
		awcnt       <= 0;
		awaddr_done <= 0;
		awdata_done <= 0;
		awstate     <= IDLE_STATE;
	end
	else if (en) begin
		case (awstate)
			IDLE_STATE: begin								
				//Select write address from caches.
				awsel <= round_robin_arbiter(c_awvalid, aw_rrptr);
				for (int i = 0; i < CACHE_NUM; i = i + 1) begin
					if (c_awvalid[i]) begin
						//awsel  <= i;	
						awsel_vld <= 1;
						awstate   <= START_STATE;
					end
				end
			end
			START_STATE: begin
				//Set valid signal to main memory.
				m_awvalid        <= 1;
				m_awaddr         <= c_awaddr[awsel];
				//Set ready signal to cache.
				c_awready[awsel] <= 1;
				awrun            <= 1;
				awstate          <= RUN_STATE;
				//Update round-robin pointer
				if (awsel == CACHE_NUM - 1) aw_rrptr <= 0;
				else                        aw_rrptr <= awsel + 1;
			end
			RUN_STATE: begin		
				//Cache AXI4 write address channel.
				if (c_awvalid[awsel] & c_awready[awsel]) begin
					c_awready[awsel] <= 0;
				end
				//Wait both write address and write data channel done.
				if (awaddr_done & awdata_done) begin					
					awsel_vld   <= 0;
					awaddr_done <= 0;
					awdata_done <= 0;
					awrun       <= 0;
					awstate     <= IDLE_STATE;					
				end
				else begin
					//Main memory AXI4 write address channel.
					if (m_awvalid && m_awready) begin
						m_awvalid   <= 0;
						awaddr_done <= 1;
					end		
					//Main memory AXI4 write data channel.
					if (m_wvalid & m_wready) begin
						awcnt <= awcnt + 1;
						if (awcnt == m_awlen[WORD_BITS-1:0]) begin
							awcnt       <= 0;
							awdata_done <= 1;
						end
					end				
				end
			end
		endcase
	end	
end
always_comb begin
	//Lenght of main memory AXI4.
	m_awlen = LINE_BITS_SIZE / AXI_DATA_WIDTH - 1;
	
	//Main memory AXI4 ID is selected index
	m_awid = awsel;
	
	//Cache write channel ready if:
	//1. Cache is selected.
	//2. Line buffer is ready if line buffer is used.
	//3. Main memory is ready if line buffer is not used.
	for (int i = 0; i < CACHE_NUM; i = i + 1) begin
		if (i == awsel && awsel_vld == 1) begin
			c_wready[i] = (WITH_LINE_BUF)? wbuf_rdy : m_wready;
		end
		else begin
			c_wready[i] = 0;
		end
	end
	
	//Main memory write channel eihter from:
	//1. Line buffer if line buffer is used.
	//2. Selected cache if line buffer is not used.
	m_wvalid = (WITH_LINE_BUF)? wbuf_vld : c_wvalid[awsel]; 
	m_wdata  = (WITH_LINE_BUF)? wbuf : c_wdata[awsel];
	m_wlast  = (m_wvalid && awcnt == m_awlen[WORD_BITS-1:0])? 1 : 0;
end


//---------------------------------------
//Line buffer (write channel)
//---------------------------------------
always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		wbuf     <= 0;
		wbuf_cnt <= 0;
		wbuf_rdy <= 0;
		wbuf_vld <= 0;
	end
	else if (en && WITH_LINE_BUF == 1) begin
		//After arbitration, ready to write line buffer.
		if (awsel_vld & ~wbuf_rdy & ~wbuf_vld) begin
			wbuf_rdy <= 1;			
		end
		//Cache -> line buffer.
		else if (c_wvalid[awsel] & c_wready[awsel]) begin
			wbuf[(LINE_BITS_SIZE - DATA_WIDTH) +: DATA_WIDTH] <= c_wdata[awsel];
			wbuf[0 +: (LINE_BITS_SIZE - DATA_WIDTH)]          <= wbuf[DATA_WIDTH +: (LINE_BITS_SIZE - DATA_WIDTH)];
			wbuf_cnt <= wbuf_cnt + 1;
			if (wbuf_cnt == LINE_BITS_SIZE / DATA_WIDTH - 1) begin
				wbuf_cnt <= 0;
				wbuf_rdy <= 0;
				wbuf_vld <= 1;
			end
		end
		//Line buffer -> main memory.
		else if (m_wvalid & m_wready) begin
			if (LINE_BITS_SIZE != AXI_DATA_WIDTH) begin
				wbuf <= wbuf >> AXI_DATA_WIDTH;
			end
			wbuf_cnt <= wbuf_cnt + 1;
			if (wbuf_cnt == LINE_BITS_SIZE / AXI_DATA_WIDTH - 1) begin
				wbuf_cnt <= 0;
				wbuf_vld <= 0;
			end
		end
	end
end

//---------------------------------------
//Read channel
//---------------------------------------
always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		m_arvalid   <= 0;
		m_araddr    <= 0;
		c_arready   <= '{default:'0};
		arsel       <= 0;
		arsel_vld   <= 0;
		ar_rrptr    <= 0;
		arcnt       <= 0;
		araddr_done <= 0;
		ardata_done <= 0;
		arstate     <= IDLE_STATE;
	end
	else if (en) begin
		case (arstate)
			IDLE_STATE: begin
				//Select read address from caches.
				arsel <= round_robin_arbiter(c_arvalid, ar_rrptr);
				for (int i = 0; i < CACHE_NUM; i = i + 1) begin
					if (c_arvalid[i]) begin
						//arsel   <= i;						
						arsel_vld <= 1;
						arstate   <= START_STATE;
					end
				end
			end
			START_STATE: begin
				//If conflict current writeback address, stall it.
				if (awrun == 0 || m_awaddr != c_araddr[arsel]) begin
					//Set address valid and data ready signal to main memory.
					m_arvalid        <= 1;
					m_araddr         <= c_araddr[arsel];
					//Set ready signal to cache.
					c_arready[arsel] <= 1;
					arstate          <= RUN_STATE;
				end
				//Update round-robin pointer
				if (arsel == CACHE_NUM - 1) ar_rrptr <= 0;
				else                        ar_rrptr <= arsel + 1;
			end
			RUN_STATE: begin				
				//Cache AXI4 read address channel.
				if (c_arvalid[arsel] & c_arready[arsel]) begin
					c_arready[arsel] <= 0;
				end
				//Wait both read address and read data channel done.
				if (araddr_done && ardata_done) begin					
					arsel_vld   <= 0;
					araddr_done <= 0;
					ardata_done <= 0;
					arstate     <= IDLE_STATE;
				end
				else begin
					//Main memory AXI4 read address channel.
					if (m_arvalid && m_arready) begin
						m_arvalid   <= 0;
						araddr_done <= 1;
					end
					//Cache AXI4 read data channel.
					if (c_rvalid[arsel] & c_rready[arsel]) begin
						arcnt <= arcnt + 1;
						if (arcnt == c_arlen[arsel][WORD_BITS-1:0]) begin
							arcnt       <= 0;
							ardata_done <= 1;
						end
					end				
				end
			end
		endcase
	end
end
always_comb begin
	//Lenght of main memory AXI4.
	m_arlen = LINE_BITS_SIZE / AXI_DATA_WIDTH - 1;
	
	//Main memory AXI4 ID is selected index
	m_arid = arsel;
	
	//Main memory read channel is ready if:
	//1. Line buffer is ready if line buffer is used.
	//2. Selected cache is ready if line buffer is not used.
	m_rready = (WITH_LINE_BUF)? rbuf_rdy : c_rready[arsel];
	
	//Cache read channel eihter from:
	//1. Line buffer if line buffer is used.
	//2. main memory if line buffer is not used.
	for (int i = 0; i < CACHE_NUM; i = i + 1) begin
		c_rdata [i] = (WITH_LINE_BUF)? rbuf : m_rdata;
		if (i == arsel && arsel_vld == 1) begin
			c_rvalid[i] = (WITH_LINE_BUF)? rbuf_vld : m_rvalid; 
		end
		else begin
			c_rvalid[i] = 0; 
		end
	end
end

	
//---------------------------------------
//Line buffer (read channel)
//---------------------------------------
always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		rbuf     <= 0;
		rbuf_cnt <= 0;
		rbuf_rdy <= 0;
		rbuf_vld <= 0;
	end
	else if (en && WITH_LINE_BUF == 1) begin
		//After aribration, ready to write line buffer
		if (arsel_vld & ~rbuf_rdy & ~rbuf_vld) begin
			rbuf_rdy <= 1;
		end
		//Main memory -> line buffer
		else if (m_rvalid & m_rready) begin
			if (LINE_BITS_SIZE == AXI_DATA_WIDTH) begin
				rbuf <= m_rdata;
			end
			else begin
				rbuf <= ({{(LINE_BITS_SIZE-AXI_DATA_WIDTH){1'b0}},m_rdata} << (LINE_BITS_SIZE - AXI_DATA_WIDTH)) | (rbuf >> AXI_DATA_WIDTH);
			end
			rbuf_cnt <= rbuf_cnt + 1;
			if (rbuf_cnt == LINE_BITS_SIZE / AXI_DATA_WIDTH - 1) begin
				rbuf_cnt <= 0;
				rbuf_rdy <= 0;
				rbuf_vld <= 1;
			end	
		end
		//Line buffer -> cache
		else if (c_rvalid[arsel] & c_rready[arsel]) begin
			rbuf[0 +: (LINE_BITS_SIZE - DATA_WIDTH)] <= rbuf[DATA_WIDTH +: (LINE_BITS_SIZE - DATA_WIDTH)];
			rbuf_cnt <= rbuf_cnt + 1;
			if (rbuf_cnt == LINE_BITS_SIZE / DATA_WIDTH - 1) begin
				rbuf_cnt <= 0;
				rbuf_vld <= 0;
			end
		end
	end
end

//Round robin arbiter
function  [CACHE_NUM_BITS - 1 : 0] round_robin_arbiter
(
	input                          req[CACHE_NUM],
	input [CACHE_NUM_BITS - 1 : 0] cur_ptr
);
	logic [CACHE_NUM_BITS - 1 : 0] ptr;	
	ptr = cur_ptr;
	round_robin_arbiter = 0;
	for (int i = 0; i < CACHE_NUM; i = i + 1) begin
		if (req[ptr] != 0) begin
			round_robin_arbiter = ptr;
		end
		ptr = ptr + 1;
		if (ptr == CACHE_NUM) begin
			ptr = 0;
		end
	end
endfunction

endmodule
