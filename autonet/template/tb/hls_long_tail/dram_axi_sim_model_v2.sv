`timescale 1ns / 1ps

`define ENABLE_RANDOM_DELAY

module dram_axi_sim_model_v2 #(
    parameter DRAM_DATA_WIDTH = 512,
    parameter ADDR_WIDTH      = 32,
    parameter BURST_LEN_WIDTH = 8,
    parameter ID_WIDTH        = 8,
    parameter STRB_WIDTH      = DRAM_DATA_WIDTH / 8,
    parameter OVERWRITE_CHECK = 1'b0
)
(
    input                                      clk,
    input                                      rstn,
    output logic                               dram_init_done,
    //Write address channel
    input                                      ddr_awvalid,
    input        [ADDR_WIDTH       -1:0]       ddr_awaddr,
    input        [BURST_LEN_WIDTH  -1:0]       ddr_awlen,
    input        [2                  :0]       ddr_awsize,
    input        [ID_WIDTH         -1:0]       ddr_awid,
    output logic                               ddr_awready,
    //Write data channel
    input        [DRAM_DATA_WIDTH  -1:0]       ddr_wdata,
    input        [STRB_WIDTH       -1:0]       ddr_wstrb,
    input                                      ddr_wvalid,
    output logic                               ddr_wready,
    //Write response channel
    input                                      ddr_bready,
    output logic [ID_WIDTH         -1:0]       ddr_bid,
    output logic [1                  :0]       ddr_bresp,
    output logic                               ddr_bvalid,
    //Read address channel
    input                                      ddr_arvalid,
    input        [ADDR_WIDTH       -1:0]       ddr_araddr,
    input        [BURST_LEN_WIDTH  -1:0]       ddr_arlen,
    input        [2                  :0]       ddr_arsize,
    input        [ID_WIDTH         -1:0]       ddr_arid,
    output logic                               ddr_arready,

    input                                      ddr_rready,
    output logic [DRAM_DATA_WIDTH  -1:0]       ddr_rdata,
    output logic                               ddr_rvalid,
    output logic                               ddr_rlast,
    output logic [ID_WIDTH         -1:0]       ddr_rid,
    output logic [1                  :0]       ddr_resp
);

logic [DRAM_DATA_WIDTH -1:0] q_dram_data[int] = '{default:0};
logic [ADDR_WIDTH      -1:0] q_ddr_awaddr[$];
logic [BURST_LEN_WIDTH -1:0] q_ddr_awlen[$];
logic [2                 :0] q_ddr_awsize[$];
logic [ID_WIDTH        -1:0] q_ddr_awid[$];
logic [DRAM_DATA_WIDTH -1:0] q_ddr_wdata[$];
logic [STRB_WIDTH      -1:0] q_ddr_wstrb[$];
logic [ID_WIDTH        -1:0] q_ddr_bid[$];
logic [ADDR_WIDTH      -1:0] q_ddr_araddr[$];
logic [BURST_LEN_WIDTH -1:0] q_ddr_arlen[$];
logic [2                 :0] q_ddr_arsize[$];
logic [ID_WIDTH        -1:0] q_ddr_arid[$];
logic [BURST_LEN_WIDTH -1:0] i_ddr_awlen = 0;
logic [ID_WIDTH        -1:0] i_ddr_awid;
logic [ADDR_WIDTH      -1:0] i_ddr_awaddr;
logic [2                 :0] i_ddr_awsize;
logic [DRAM_DATA_WIDTH -1:0] i_ddr_wdata;
logic [STRB_WIDTH      -1:0] i_ddr_wstrb;
logic [BURST_LEN_WIDTH -1:0] i_ddr_arlen;
logic [ID_WIDTH        -1:0] i_ddr_arid;
logic [ADDR_WIDTH      -1:0] i_ddr_araddr;
logic [2                 :0] i_ddr_arsize;
int                          i_ddr_wr_cnt = 0;
int                          i_ddr_rd_cnt = 0;
int                          i_ddr_wdelay = 0;
int                          i_ddr_awdelay = 0;
int                          i_ddr_ardelay = 0;
int                          i_ddr_rdelay = 0;
event                        wr_done;

initial begin
    dram_init_done = 0;
    ddr_awready    = 0;
    ddr_bid        = 0;
    ddr_bvalid     = 0;
    ddr_bresp      = 0;
    ddr_arready    = 0;
    ddr_rdata      = 0;
    ddr_rvalid     = 0;
    ddr_rlast      = 0;
    ddr_rid        = 0;
    ddr_resp       = 0;    

    repeat(100) @ (posedge clk);
    wait(rstn);
    @(posedge clk);
    dram_init_done = 1;

    fork
        forever delay_awready;
        forever delay_wready;
        forever delay_arready;
        forever dram_write_addr_reqeust;
        forever dram_write_data_request;        
        forever dram_write_response;        
        forever dram_read_addr_request;        
        forever dram_read_run;
        forever dram_write_run;        
    join
end


`ifdef ENABLE_RANDOM_DELAY
task delay_awready();
    i_ddr_awdelay = $urandom_range(0,10);
    repeat(i_ddr_awdelay) @(posedge clk);
    ddr_awready = 1;
    i_ddr_awdelay = $urandom_range(0,5);
    repeat(i_ddr_awdelay) @(posedge clk);
    ddr_awready = 0;
    @(posedge clk);
    ddr_awready = 1;
endtask

task delay_wready();
    i_ddr_wdelay = $urandom_range(0,10);
    repeat(i_ddr_wdelay) @(posedge clk);
    ddr_wready = 1;
    i_ddr_wdelay = $urandom_range(0,5);
    repeat(i_ddr_wdelay) @(posedge clk);
    ddr_wready = 0;
    @(posedge clk);
    ddr_wready = 1;
endtask

task delay_arready();
    i_ddr_ardelay = $urandom_range(1,3);
    repeat(i_ddr_ardelay) @(posedge clk);
    ddr_arready = 1;
    i_ddr_ardelay = $urandom_range(1,3);
    repeat(i_ddr_ardelay) @(posedge clk);
    ddr_arready = 0;
    @(posedge clk);
    ddr_arready = 1;
endtask

`else 

task delay_awready();
    i_ddr_awdelay = 1;
    repeat(i_ddr_awdelay) @(posedge clk);
    ddr_awready = 1;
    i_ddr_awdelay = 1;
    repeat(i_ddr_awdelay) @(posedge clk);
    ddr_awready = 0;
    @(posedge clk);
    ddr_awready = 1;
endtask

task delay_wready();
    i_ddr_wdelay = 1;
    repeat(i_ddr_wdelay) @(posedge clk);
    ddr_wready = 1;
    i_ddr_wdelay = 1;
    repeat(i_ddr_wdelay) @(posedge clk);
    ddr_wready = 0;
    @(posedge clk);
    ddr_wready = 1;
endtask

task delay_arready();
    i_ddr_ardelay = 1;
    repeat(i_ddr_ardelay) @(posedge clk);
    ddr_arready = 1;
    i_ddr_ardelay = 1;
    repeat(i_ddr_ardelay) @(posedge clk);
    ddr_arready = 0;
    @(posedge clk);
    ddr_arready = 1;
endtask

`endif 

task dram_write_addr_reqeust();
    @(negedge clk);
    if (ddr_awvalid && ddr_awready) begin
        q_ddr_awaddr.push_back(ddr_awaddr);
        q_ddr_awlen.push_back(ddr_awlen);
        q_ddr_awsize.push_back(ddr_awsize);
        q_ddr_awid.push_back(ddr_awid);
    end
endtask

task dram_write_data_request();
    @(negedge clk);
    if (ddr_wvalid && ddr_wready) begin
        q_ddr_wdata.push_back(ddr_wdata);
        q_ddr_wstrb.push_back(ddr_wstrb);
    end
endtask

task dram_write_response();
    @(posedge clk);
    #1;
    wait(wr_done.triggered);
    if (q_ddr_bid.size() != 0) begin
        ddr_bvalid = 1;
        ddr_bid = q_ddr_bid.pop_front();
        ddr_bresp = 0;
        //if (ddr_bid != 0) $display("pop bid %h t=%0t", ddr_bid, $time());
        while(~ddr_bready) @(negedge clk);
        @(posedge clk);
        #1;
        ddr_bvalid = 0;
    end
endtask

task dram_read_addr_request();
    @(negedge clk);
    if (ddr_arvalid & ddr_arready) begin
        q_ddr_araddr.push_back(ddr_araddr);
        q_ddr_arlen.push_back(ddr_arlen);
        q_ddr_arsize.push_back(ddr_arsize);        
        q_ddr_arid.push_back(ddr_arid);
    end
endtask

task dram_write_run();
    logic [DRAM_DATA_WIDTH-1:0] i_q_dram_data;
    @(posedge clk);
    #1;
    if (q_ddr_awaddr.size() != 0 && q_ddr_awlen.size() != 0 && q_ddr_awsize.size() != 0 && q_ddr_awid.size() != 0) begin            
        i_ddr_awaddr = q_ddr_awaddr.pop_front();
        i_ddr_awlen  = q_ddr_awlen.pop_front();
        i_ddr_awsize = q_ddr_awsize.pop_front();
        i_ddr_awid   = q_ddr_awid.pop_front();        
        i_ddr_wr_cnt = 0; 
        while (i_ddr_wr_cnt != i_ddr_awlen + 1) begin
            #1;
            if (q_ddr_wdata.size() != 0 && q_ddr_wstrb.size() != 0) begin
                i_ddr_wdata = q_ddr_wdata.pop_front();
                i_ddr_wstrb = q_ddr_wstrb.pop_front();
                if (OVERWRITE_CHECK && q_dram_data.exists(i_ddr_awaddr)) begin
                    $fatal("AT %0t, OVERWRITING PREVIOUS ENTRY AT %0h ADDRESS", $time(), i_ddr_awaddr);
                end
                else begin                    
                    i_q_dram_data = q_dram_data[i_ddr_awaddr / STRB_WIDTH];
                    for (int i = 0; i < STRB_WIDTH; i = i + 1) begin
                        if (i_ddr_wstrb[i]) begin
                            i_q_dram_data[(i * 8) +: 8] = i_ddr_wdata[(i * 8) +: 8];
                        end
                    end
                    q_dram_data[i_ddr_awaddr / STRB_WIDTH] = i_q_dram_data;
                end
                i_ddr_awaddr = i_ddr_awaddr + (1 << i_ddr_awsize);
                i_ddr_wr_cnt = i_ddr_wr_cnt + 1;
            end
            @(posedge clk);
        end        
        //if (i_ddr_awid != 0) $display("push awid @%h %h t=%0t", i_ddr_awaddr - (1 << i_ddr_awsize), i_ddr_awid, $time());
        q_ddr_bid.push_back(i_ddr_awid);
        -> wr_done;
    end
endtask

task dram_read_run();
    @(posedge clk);
    #1;
    ddr_rlast = 0;
    if (q_ddr_araddr.size() != 0 && q_ddr_arlen.size() != 0 && q_ddr_arsize.size() != 0 && q_ddr_arid.size() != 0) begin
        @(posedge clk);
        i_ddr_araddr = q_ddr_araddr.pop_front();
        i_ddr_arlen  = q_ddr_arlen.pop_front();
        i_ddr_arsize = q_ddr_arsize.pop_front();
        ddr_rid      = q_ddr_arid.pop_front();
        i_ddr_rd_cnt = 0;
        while(i_ddr_rd_cnt != i_ddr_arlen + 1) begin
            @(negedge clk);
            if(ddr_rready) begin                
                @(posedge clk);
                #0.1
                ddr_rvalid   = 1;                
                ddr_rdata    = q_dram_data[i_ddr_araddr / STRB_WIDTH];    
                ddr_rlast    = (i_ddr_rd_cnt == i_ddr_arlen)? 1 : 0;
                i_ddr_araddr = i_ddr_araddr + (1 << i_ddr_arsize);                
                i_ddr_rd_cnt = i_ddr_rd_cnt + 1;
                @(posedge clk);
                #0.1
                ddr_rvalid   = 0;
            end            
        end
    end
    ddr_rlast  = 0;
    ddr_rid    = 0;
    ddr_rdata  = 0;
    ddr_rvalid = 0;    
endtask








endmodule