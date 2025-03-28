

module cacheIf_axi4_rchan #(
    parameter int DW = 32,
    parameter int AW = 32,
    parameter int LEN = 16,
    parameter int FIFO_DEPTH = 16,
    parameter int IS_AXIS = 0
) (
    input                       clk,
    input                       rstn,

    input            [8:0]      burst_len_i,
    input            [LEN-1:0]  len_i,
    input            [7:0]      id_i,
    input                       start_i,
    input                       stop_i,
    input   [AW-1:0]            start_addr_i,
    input                       clr_fifo_i,
    output logic                done_o,

    //Memory read
    input                       mem_re,
    input         [AW-1:0]      mem_rad,
    output logic                mem_rreq_rdy,
    output logic  [DW-1:0]      mem_rdat,
    output logic                mem_rdat_rdy,
    input                       rdfifo_full_n,

    //axi4 read address channel signals
    output logic                axi4_arvalid,
    input                       axi4_arready,
    output logic  [AW-1 : 0]    axi4_araddr,
    output logic  [7 : 0]       axi4_arlen,
    output logic  [2 : 0]       axi4_arsize,
    output logic  [1 : 0]       axi4_arburst,
    output logic  [7 : 0]       axi4_arid,

    //axi4 write data channel signals
    input                       axi4_rvalid,
    output logic                axi4_rready,
    input         [DW-1:0]      axi4_rdata,
    input                       axi4_rlast
);
    import cacheIf_axi4_pkg::*;

    localparam int FIFO_AW = $clog2(FIFO_DEPTH);
    localparam int ADDR_SHIFT = $clog2(DW/8);
    localparam int ADDR_INCR = DW/8;
    localparam int ADDR_MASK = ADDR_INCR - 1;

    logic [AW-1:0]                 mem_rreq_cnt_r;
    logic [LEN-1:0]                len_bytes_r;
    logic                          infinite_len_r;
    logic [7:0]                    id_r;
    logic [AW-1:0]                 tr_size, tr_size_r;
    logic [AW-1:0]                 start_addr_r;
    logic [8:0]                    burst_len_r;
    logic [3:0]                    log2_burst_len_r;
    logic [AW-1:0]                 cur_addr, cur_addr_r;
    logic [AW-1:0]                 finish_addr_r;
    logic                          tr_run, tr_run_r;
    logic                          addr_fetched, addr_fetched_r;
    logic                          send_req, send_req_r;
    logic                          done, done_r;
    logic                          clr_fifo;
    logic                          stopped, stopped_r;
    logic                          axi4_run, axi4_run_r;
    logic [7:0]                    beats_cnt, beats_cnt_r;
    logic [7:0]                    beats_num, beats_num_r;

    logic                          data_fifo_pop, data_fifo_pop_r;
    logic [DW-1:0]                 data_fifo_dout;
    logic                          data_fifo_push;
    logic [DW-1:0]                 data_fifo_din;
    logic                          data_fifo_full;
    logic                          data_fifo_empty;

    logic                          axi4_arvalid_w;
    logic  [AW-1 : 0]              axi4_araddr_w;
    logic  [7 : 0]                 axi4_arlen_w;
    logic  [7 : 0]                 axi4_arid_w;

    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            start_addr_r <= 0;
            len_bytes_r <= 0;
            id_r <= 0;
            burst_len_r <= 0;
            log2_burst_len_r <= 0;
            data_fifo_pop_r <= 0;
            cur_addr_r <= 0;
            finish_addr_r <= 0;
            tr_run_r <= 0;
            send_req_r <= 0;
            mem_rreq_cnt_r <= 0;
            addr_fetched_r <= 0;
            axi4_arvalid <= 0;
            axi4_arid <= 0;
            axi4_araddr <= 0;
            axi4_arlen <= 0;
            tr_size_r <= 0;
            infinite_len_r <= 0;
            stopped_r <= 0;
            done_r <= 0;
            axi4_run_r <= 0;
            beats_cnt_r <= 0;
            beats_num_r <= 0;
        end
        else begin
            if (start_i) begin
                start_addr_r <= start_addr_i;
                len_bytes_r <= len_i;
                infinite_len_r <= &len_i[LEN-1:0];
                finish_addr_r <= start_addr_i + len_i;
                burst_len_r <= burst_len_i;
                log2_burst_len_r <= get_log2_burst_len(burst_len_i);
                id_r <= id_i;
            end
            else if (send_req) begin
                if (~infinite_len_r) begin
                    len_bytes_r <= (tr_size>len_bytes_r) ? 0 : (len_bytes_r - tr_size);
                end
            end
            data_fifo_pop_r <= data_fifo_pop;
            cur_addr_r <= cur_addr;
            tr_run_r <= tr_run;
            send_req_r <= send_req;
            addr_fetched_r <= addr_fetched;
            axi4_arvalid <= axi4_arvalid_w;
            axi4_arid <= axi4_arid_w;
            axi4_araddr <= axi4_araddr_w;
            axi4_arlen <= axi4_arlen_w;
            tr_size_r <= tr_size;
            stopped_r <= stopped;
            done_r <= done;
            axi4_run_r <= axi4_run;
            beats_cnt_r <= beats_cnt;
            beats_num_r <= beats_num;

            if (mem_re && mem_rreq_rdy && ~data_fifo_pop) begin
                mem_rreq_cnt_r <= mem_rreq_cnt_r + 1;
            end
            else if (~(mem_re && mem_rreq_rdy) && data_fifo_pop) begin
                mem_rreq_cnt_r <= mem_rreq_cnt_r - 1;
            end
        end
    end

    // return done signal
    assign done_o = done_r & ~start_i;
    always_comb begin
        done = done_r;
        if (start_i) begin
            done = 0;
        end
        else if ((stop_i && (IS_AXIS==1)) || (~tr_run_r && ~axi4_run_r)) begin
            done = 1;
        end
    end

    always_comb begin
        mem_rreq_rdy = 1;

        data_fifo_pop = ~data_fifo_empty && (mem_rreq_cnt_r!=0) && rdfifo_full_n;
        mem_rdat = data_fifo_dout;
        mem_rdat_rdy = data_fifo_pop_r;
    end

    always_comb begin
        cur_addr = send_req_r ? (cur_addr_r + tr_size_r) : cur_addr_r;
        tr_run = (~tr_run_r && start_i) ? 1 :
                stop_i                  ? 0 :
                tr_run_r;
        addr_fetched = stop_i ? 0 : addr_fetched_r;
        send_req = 0;
        stopped = stop_i ? 1 : stopped_r;

        if (tr_run && ~addr_fetched_r && mem_re && mem_rreq_rdy) begin
            cur_addr = start_addr_r;
            addr_fetched = 1;
            send_req = 1;
            stopped = 0;
        end
        else if (tr_run_r && addr_fetched_r && ((axi4_arvalid && axi4_arready && (len_bytes_r>0) && ~infinite_len_r) || (infinite_len_r && ~axi4_run_r))) begin
            send_req = 1;
        end
        else if (tr_run_r && addr_fetched_r && (len_bytes_r==0) && axi4_rready && axi4_rvalid) begin
            tr_run = 0;
            addr_fetched = 0;
        end
    end

    //axi4 read address channel
    always_comb begin
        axi4_arburst = AxBURST_INCR;
        axi4_arsize = ADDR_SHIFT;

        axi4_arvalid_w = axi4_arvalid;
        axi4_araddr_w = axi4_araddr;
        axi4_arlen_w = axi4_arlen;
        axi4_arid_w = id_r;

        tr_size = 0;

        if (send_req) begin
            axi4_arvalid_w = 1;
            axi4_araddr_w = cur_addr;
            {axi4_arlen_w, tr_size} = get_cur_burst_len(cur_addr, finish_addr_r, len_bytes_r, burst_len_r, log2_burst_len_r, infinite_len_r);
        end
        else if (axi4_arvalid && axi4_arready) begin
            axi4_arvalid_w = 0;
            axi4_araddr_w = 0;
            axi4_arlen_w = 0;
        end

        axi4_run = axi4_run_r;
        beats_cnt = beats_cnt_r;
        beats_num = beats_num_r;
        if (send_req && (infinite_len_r || (start_i && ~tr_run_r && (&len_i[LEN-1:0])))) begin
            axi4_run = 1;
            beats_cnt = 0;
            beats_num = axi4_arlen_w;
        end
        else if (axi4_rvalid && axi4_rready && infinite_len_r && axi4_rlast) begin
            //if (beats_cnt_r==beats_num_r) begin
            //if (axi4_rlast) begin
                axi4_run = 0;
            //end
            //else begin
                //beats_cnt = beats_cnt_r + 1;
            //end
        end
    end

    //axi4 read data channel
    always_comb begin
        axi4_rready = ~data_fifo_full | stopped_r;
        data_fifo_push = ~stopped_r & axi4_rvalid & ~data_fifo_full;
        data_fifo_din = axi4_rdata;
        clr_fifo = clr_fifo_i | stop_i;
    end

    sync_fifo1 #(
        .usr_ram_style ("auto"),
        .dw            (DW),
        .aw            (FIFO_AW)
    ) data_fifo (
        .clk    (clk),
        .rstn   (rstn),
        .clr    (clr_fifo),
        .rd_en  (data_fifo_pop),
        .dout   (data_fifo_dout),
        .wr_en  (data_fifo_push),
        .din    (data_fifo_din),
        .full   (data_fifo_full),
        .empty  (data_fifo_empty)
    );

    function logic[AW+9:0] get_cur_burst_len(
        input [AW-1:0] addr,
        input [AW-1:0] finish_addr,
        input [AW-1:0] len_bytes,
        input [8:0] bl,
        input [3:0] log2_bl,
        input       infinite_len
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