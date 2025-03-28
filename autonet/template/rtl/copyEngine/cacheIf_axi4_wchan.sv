

module cacheIf_axi4_wchan #(
    parameter int DW = 32,
    parameter int AW = 32,
    parameter int LEN = 16,
    parameter int FIFO_DEPTH = 16,
    parameter int IS_AXIS = 0
) (
    input                               clk,
    input                               rstn,

    input            [8:0]              burst_len_i,
    input            [LEN-1:0]          len_i,
    input            [7:0]              id_i,
    input                               start_i,
    input                               stop_i,
    input   [AW-1:0]                    start_addr_i,
    input                               clr_fifo_i,
    output logic                        done_o,


    //Memory write
    input         [DW/8-1:0]            mem_bwe,
    input         [AW-1:0]              mem_wad,
    input         [DW-1:0]              mem_wdat,
    output logic                        mem_wreq_rdy,

    //axi4 write address channel signals
    output logic                        axi4_awvalid,
    input                               axi4_awready,
    output logic  [AW-1 : 0]            axi4_awaddr,
    output logic  [7 : 0]               axi4_awlen,
    output logic  [2 : 0]               axi4_awsize,
    output logic  [1 : 0]               axi4_awburst,
    output logic  [7 : 0]               axi4_awid,

    //axi4 write data channel signals
    output logic                        axi4_wvalid,
    input                               axi4_wready,
    output logic  [DW-1 : 0]            axi4_wdata,
    output logic  [DW/8-1 : 0]          axi4_wstrb,
    output logic                        axi4_wlast,
    output logic  [7 : 0]               axi4_wid,

    //axi4 write response channel signals
    input                               axi4_bvalid,
    output logic                        axi4_bready,
    input                               axi4_bresp
);
    import cacheIf_axi4_pkg::*;

    localparam int FIFO_DW = DW + DW/8;
    localparam int FIFO_AW = $clog2(FIFO_DEPTH);
    localparam int ADDR_SHIFT = $clog2(DW/8);
    localparam int ADDR_INCR = DW/8;
    localparam int ADDR_MASK = ADDR_INCR - 1;

    logic [LEN-1:0]                len_bytes_r;
    logic                          infinite_len_r;
    logic [7:0]                    id_r;
    logic [AW-1:0]                 tr_size, tr_size_r;
    logic [AW-1:0]                 start_addr_r;
    logic [8:0]                    burst_len_r;
    logic [8:0]                    cur_burst_len_r;
    logic [8:0]                    beat_cnt2, beat_cnt2_r;
    logic [3:0]                    log2_burst_len_r;
    logic [AW-1:0]                 cur_addr, cur_addr_r;
    logic [AW-1:0]                 finish_addr_r;
    logic                          tr_run, tr_run_r;
    logic                          addr_fetched, addr_fetched_r;
    logic                          send_req, send_req_r;
    logic                          done, done_r;
    logic                          stop_proc, stop_proc_r;
    logic                          clr_fifo;

    logic                          data_fifo_pop, data_fifo_pop_r;
    logic [FIFO_DW-1:0]            data_fifo_dout;
    logic                          data_fifo_push;
    logic [FIFO_DW-1:0]            data_fifo_din;
    logic                          data_fifo_full;
    logic                          data_fifo_empty;

    logic                          axi4_awvalid_w;
    logic  [AW-1 : 0]              axi4_awaddr_w;
    logic  [7 : 0]                 axi4_awlen_w;
    logic  [7 : 0]                 axi4_awid_w;

    logic                          next;
    logic                          data_running, data_running_r;
    logic                          axi4_rdy;
    logic                          axi4_wvalid_w, axi4_wvalid_r;
    logic  [DW-1 : 0]              axi4_wdata_w, axi4_wdata_r;
    logic  [DW/8-1 : 0]            axi4_wstrb_w, axi4_wstrb_r;
    logic                          axi4_wlast_w, axi4_wlast_r;
    logic                          axi4_wready_r;
    logic  [7 : 0]                 axi4_wid_w;

    logic                          addr_compl, addr_compl_r;
    logic                          data_compl, data_compl_r;
    logic                          bvalid_fetched_r;

    logic [FIFO_AW:0]              data_fifo_cnt;
    logic                          stop_req;


    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            start_addr_r <= 0;
            len_bytes_r <= 0;
            id_r <= 0;
            burst_len_r <= 0;
            cur_burst_len_r <= 0;
            beat_cnt2_r <= 0;
            log2_burst_len_r <= 0;
            data_fifo_pop_r <= 0;
            cur_addr_r <= 0;
            finish_addr_r <= 0;
            tr_run_r <= 0;
            send_req_r <= 0;
            addr_fetched_r <= 0;
            axi4_awvalid <= 0;
            axi4_awaddr <= 0;
            axi4_awlen <= 0;
            axi4_awid <= 0;
            axi4_wvalid_r <= 0;
            axi4_wdata_r <= 0;
            axi4_wstrb_r <= 0;
            axi4_wlast_r <= 0;
            axi4_wready_r <= 0;
            axi4_wid <= 0;
            tr_size_r <= 0;
            done_r <= 1;
            addr_compl_r <= 0;
            data_compl_r <= 0;
            bvalid_fetched_r <= 0;
            stop_proc_r <= 0;
            infinite_len_r <= 0;
            data_running_r <= 0;
        end
        else begin
            if (start_i) begin
                //store input parameters to regs
                start_addr_r <= start_addr_i;
                len_bytes_r <= len_i;
                infinite_len_r <= &len_i[LEN-1:0];
                id_r <= id_i;
                finish_addr_r <= start_addr_i + len_i;
                burst_len_r <= burst_len_i;
                log2_burst_len_r <= get_log2_burst_len(burst_len_i);
            end
            else if (send_req) begin
                //update regs at new axi4 transaction inside dma transfer
                if (~infinite_len_r) begin
                    //set len_bytes to 0 if last transaction in dma transfer (tr_size>len_bytes_r)
                    len_bytes_r <= (tr_size>len_bytes_r) ? 0 : (len_bytes_r - tr_size);
                end
                cur_burst_len_r <= axi4_awlen_w;
            end
            beat_cnt2_r <= beat_cnt2;
            data_fifo_pop_r <= data_fifo_pop;
            tr_size_r <= tr_size;

            cur_addr_r <= cur_addr;
            tr_run_r <= tr_run;
            send_req_r <= send_req;
            addr_fetched_r <= addr_fetched;
            axi4_awvalid <= axi4_awvalid_w;
            axi4_awaddr <= axi4_awaddr_w;
            axi4_awlen <= axi4_awlen_w;
            axi4_awid <= axi4_awid_w;
            axi4_wvalid_r <= axi4_wvalid_w;
            axi4_wdata_r <= axi4_wdata_w;
            axi4_wstrb_r <= axi4_wstrb_w;
            axi4_wlast_r <= axi4_wlast_w;
            axi4_wready_r <= axi4_wready;
            axi4_wid <= axi4_wid_w;
            done_r <= done;
            addr_compl_r <= addr_compl;
            data_compl_r <= data_compl;
            stop_proc_r <= stop_proc;
            data_running_r <= data_running;

            //bvalid_fetched_r set 1 if received valid bvalid
            if (send_req) begin
                bvalid_fetched_r <= 0;
            end
            else if (axi4_bvalid && axi4_bready) begin
                bvalid_fetched_r <= 1;
            end
        end
    end

    // return done signal
    assign done_o = done_r & ~start_i;

    //data_fifo push logic
    always_comb begin
        mem_wreq_rdy = ~data_fifo_full;
        data_fifo_push = (mem_bwe!=0) & ~data_fifo_full;
        data_fifo_din = {mem_bwe, mem_wdat};
    end

    always_comb begin
        stop_req = infinite_len_r && ((stop_i || stop_proc_r) && ~data_fifo_empty);
        cur_addr = send_req_r ? (cur_addr_r + tr_size_r) : cur_addr_r;//update current address at axi transaction inside dma transfer

        tr_run = (~tr_run_r && start_i)                             ? 1 : //set tr_run flag at start dma transfer
                  (stop_i && ((IS_AXIS==1) || data_fifo_empty))     ? 0 : //clear tr_run flag at receiving stop command if this module used as AXIS or data fifo is empty
                                                                      tr_run_r;
        addr_fetched = (stop_i && ((IS_AXIS==1) || data_fifo_empty)) ? 0 : addr_fetched_r;
        send_req = 0;
        done = start_i                                                    ? 0 : //clear done flag at start new dma transfer
                ((stop_i && (IS_AXIS==1)) || (~tr_run_r && ~stop_proc_r)) ? 1 : //set done flag at receiving stop command if this module used as AXIS or finished last AXI4 transaction
                                                                            done_r;
        if (tr_run && ~addr_fetched_r && (((data_fifo_full || (stop_i && ~data_fifo_empty)) && infinite_len_r && (IS_AXIS==0)) || (((IS_AXIS==1) || ~infinite_len_r) && (mem_bwe!=0)))) begin
            //start new transaction if
            //1. this is interface used as AXI4 and dmalen==-1 and data fifo is full or received stop command and data fifo is not empty
            //or
            //2. this is interface used as AXIS or dmalen!=-1 and there is a write operation (mem_bwe!=0)
            cur_addr = start_addr_r;
            addr_fetched = 1;
            send_req = 1;
        end
        else if (tr_run && addr_fetched_r && ((axi4_bready && axi4_bvalid) || bvalid_fetched_r) &&
                (((len_bytes_r>0) && ~infinite_len_r) || (infinite_len_r && (data_fifo_full || ((stop_i || stop_proc_r) && ~data_fifo_empty)))) &&
                addr_compl_r && data_compl_r) begin
            //start new transaction if handeled previous transaction (received bvalid, compelted address and data stages)
            //and
            //1. dmalen!=-1 and current remain len>0
            //or
            //2. dmalen==-1 and fifo full

            send_req = 1;
        end
        else if (tr_run_r && addr_fetched_r && ((len_bytes_r==0) || stop_proc_r) && ((axi4_bready && axi4_bvalid) || bvalid_fetched_r) && addr_compl_r && data_compl_r) begin
            //clear tr_run flag if
            //1. handeled previous transaction (received bvalid, compelted address and data stages)
            //and
            //2. remain len become 0 or asserted the stop_proc flag
            tr_run = 0;
            addr_fetched = 0;
            done = 1;
        end
    end

    //axi4 write address channel
    always_comb begin
        axi4_awburst = AxBURST_INCR;
        axi4_awsize = ADDR_SHIFT;

        //clear axi interface signals if received stop command and module used as AXIS interface
        axi4_awvalid_w = (stop_i && (IS_AXIS==1)) ? 0 : axi4_awvalid;
        axi4_awaddr_w = (stop_i && (IS_AXIS==1)) ? 0 : axi4_awaddr;
        axi4_awlen_w = (stop_i && (IS_AXIS==1)) ? 0 : axi4_awlen;
        axi4_awid_w = (stop_i && (IS_AXIS==1)) ? 0 : id_r;

        addr_compl = addr_compl_r;

        tr_size = 0;
        if (send_req) begin
            //define axi transaction parameters at starting new transaction
            axi4_awvalid_w = 1;
            axi4_awaddr_w = cur_addr;
            {axi4_awlen_w, tr_size} = get_cur_burst_len(cur_addr,
                                                        finish_addr_r,
                                                        len_bytes_r,
                                                        burst_len_r,
                                                        log2_burst_len_r,
                                                        infinite_len_r,
                                                        stop_req,
                                                        data_fifo_cnt
                                                    );
            addr_compl = 0;
        end
        else if (axi4_awvalid && axi4_awready) begin
            //clear axi parameters at receiving awready
            axi4_awvalid_w = 0;
            axi4_awaddr_w = 0;
            axi4_awlen_w = 0;
            addr_compl = 1;
         end
    end

    //s0
    always_comb begin
        data_fifo_pop = 0;
        data_running = start_i ? 0 : data_running_r;
        if (send_req && (~infinite_len_r || data_fifo_full || (IS_AXIS==1) || (stop_i && (IS_AXIS==0)))) begin
            //pop data from fifo if:
            //1. started new axi transaction
            //and
            //2. fifo not empty
            //and
            //3. dmalen!=-1 or fifo is full or this is AXIS interface or received stop command and this is AXI4 interface
            data_fifo_pop = ~data_fifo_empty;
            data_running = 1;
        end
        else if (axi4_rdy && (~infinite_len_r || data_fifo_full || (IS_AXIS==1) || addr_compl_r || data_running_r) && ~data_fifo_empty && (~(axi4_wvalid && ~axi4_wready)) && ~axi4_wlast_w) begin
            //pop data from fifo if:
            //1. axi interface is ready and fifo not empty and data phase of axi transaction is already started
            data_fifo_pop = 1;
            data_running = 1;
        end
        clr_fifo = (clr_fifo_i | (stop_proc_r & axi4_wlast_w) | (stop_i && ((IS_AXIS==1))) | start_i) & ~data_fifo_empty;
    end

    //axi4 write data channel
    assign axi4_wvalid = axi4_wvalid_w;
    assign axi4_wdata = axi4_wdata_w;
    assign axi4_wstrb = axi4_wstrb_w;
    assign axi4_wlast = axi4_wlast_w;

    always_comb begin
        beat_cnt2 = send_req ? 0 : beat_cnt2_r; //clear sended data counter at start new transaction

        axi4_bready = 1;
        //clear axi interface signals if received stop command and module used as AXIS interface
        axi4_wvalid_w = (stop_i && (IS_AXIS==1)) ? 0 : axi4_wvalid_r;
        axi4_wdata_w = (stop_i && (IS_AXIS==1)) ? 0 : axi4_wdata_r;
        axi4_wstrb_w = (stop_i && (IS_AXIS==1)) ? 0 : axi4_wstrb_r;
        axi4_wlast_w = (stop_i && (IS_AXIS==1)) ? 0 : axi4_wlast_r;
        axi4_wid_w = (stop_i && (IS_AXIS==1)) ? 0 : id_r;

        //axi interface is ready for new transaction if wvalid==0 or wready==1 and wlast==0
        axi4_rdy = (~axi4_wvalid_r || axi4_wready_r) && ~axi4_wlast_r && (beat_cnt2_r<=cur_burst_len_r);

        //finish current transfer when arrived the stop request
        stop_proc = (tr_run_r && stop_i && (IS_AXIS==0))                                                  ? 1 : //start processing the stop command if this is AXI4 interface and dma transfer is running and received the stop command
                    (data_fifo_empty && data_compl_r && addr_compl_r && ((axi4_bready && axi4_bvalid) || bvalid_fetched_r))  ? 0 : //finish processing of the stop command at completing axi4 transaction
                                                           stop_proc_r;

        next = axi4_rdy && (data_fifo_pop_r || (stop_proc_r && data_fifo_empty));
        data_compl = send_req ? 0 : data_compl_r;
        if (next) begin
            axi4_wvalid_w = 1;
            //issue data from fifo or 0 if there is a handling of stop request
            axi4_wdata_w = data_fifo_pop_r ? data_fifo_dout[DW-1 : 0] : 0;
            axi4_wstrb_w = data_fifo_pop_r ? data_fifo_dout[FIFO_DW-1 : FIFO_DW-(DW/8)] : {(DW/8){1'b0}};
            axi4_wlast_w = (beat_cnt2_r==cur_burst_len_r);
            beat_cnt2 = beat_cnt2_r + 1;
            data_compl = 0;
        end
        else if (axi4_wvalid_r & axi4_wready_r) begin
            axi4_wvalid_w = 0;
            axi4_wdata_w = 0;
            axi4_wstrb_w = 0;
            axi4_wlast_w = 0;
            data_compl = axi4_wlast_r;
        end
    end

    sync_fifo1 #(
        .usr_ram_style ("auto"),
        .dw            (FIFO_DW),
        .aw            (FIFO_AW)
    ) dfifo (
        .clk    (clk),
        .rstn   (rstn),
        .clr    (clr_fifo),
        .rd_en  (data_fifo_pop),
        .dout   (data_fifo_dout),
        .wr_en  (data_fifo_push),
        .din    (data_fifo_din),
        .full   (data_fifo_full),
        .empty  (data_fifo_empty),
        .status_count (data_fifo_cnt)
    );

    function logic[AW+9:0] get_cur_burst_len(
            input [AW-1:0] addr,
            input [AW-1:0] finish_addr,
            input [AW-1:0] len_bytes,
            input [8:0] bl,
            input [3:0] log2_bl,
            input       infinite_len,
            input       stop,
            input [FIFO_AW:0] fifo_cnt
        );
        int word_idx;
        logic [8:0] res_bl;
        logic [AW-1:0] aligned_addr;
        logic [AW-1:0] act_len;
        logic [AW-1:0] tr_sz;
        logic [AW-1:0] addr_shift;
        logic [AW-1:0] tail_len;
        aligned_addr = (addr & ~ADDR_MASK);
        act_len = finish_addr - aligned_addr;
        addr_shift = (addr & ADDR_MASK);
        tail_len = (act_len & ADDR_MASK);
        word_idx = get_word_idx(addr, log2_bl);
        res_bl = bl - word_idx;
        tr_sz = (res_bl << ADDR_SHIFT) - addr_shift;
        if ((tr_sz > act_len) && ~infinite_len) begin
            res_bl = ((act_len) >> ADDR_SHIFT) + ((tail_len!=0) ? 1 : 0);
            tr_sz = len_bytes;
        end
        else if (stop) begin
            res_bl = fifo_cnt;
        end
        res_bl -= 1;
        return {res_bl, tr_sz};
    endfunction

    function logic[8:0] get_word_idx(input [AW-1:0] addr, input [3:0] log2_bl);
        get_word_idx = (addr >> ADDR_SHIFT) & ((1 << log2_bl) - 1);
    endfunction

    function logic [3:0] get_log2_burst_len(input [8:0] bl);
        case (bl)
            1:   get_log2_burst_len = 0;
            2:   get_log2_burst_len = 1;
            4:   get_log2_burst_len = 2;
            8:   get_log2_burst_len = 3;
            16:  get_log2_burst_len = 4;
            32:  get_log2_burst_len = 5;
            64:  get_log2_burst_len = 6;
            128: get_log2_burst_len = 7;
            256: get_log2_burst_len = 8;
        endcase
    endfunction

endmodule