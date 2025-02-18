/*
A bypass fifo has a output register rdat_r and memory fifo with a depth D
    - the fifo can store at most D+1 data, where rdat_r store the next data to be popped
    - if fifo is empty, pushed data is directly forwarded to rdat_r
    - if pop=1 and ram fifo is not empty, read from ready FIFO at this cycle and register it at the next cycle
*/
module fifo_with_bypass #(
    parameter D = 8,
    parameter WIDTH = 8
) (
    input                       clk,
    input                       rstn,
    input                       push,
    input                       pop,
    input           [WIDTH-1:0] din,
    output logic    [WIDTH-1:0] rdat_r,
    output logic                full,
    output logic                empty
);

    localparam int LOG_D = $clog2(D);

    logic               mem_we;
    logic [WIDTH-1:0]   mem_dout;
    logic [LOG_D-1:0]   wr_ptr; // Write pointer
    logic [LOG_D-1:0]   rd_ptr; // Read pointer
    logic [LOG_D:0]     count; // Number of elements in FIFO
    logic               memEmpty, memEmpty_w;
    logic               rdat_vld_r;

    // Initialize pointers and status on reset
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
            rdat_r <= 0;
            rdat_vld_r <= 0;
            memEmpty <= 1;
        end
        else begin
            // Handle push operation
            if (push) begin
                if(~empty) begin
                    wr_ptr <= wr_ptr + 1;
                end
                else begin
                    rdat_r <= din;
                    rdat_vld_r <= 1;
                end
            end

            // Handle pop operation
            if (pop) begin
                if (~memEmpty && ~rdat_vld_r) begin
                    rdat_r <= mem_dout; // Read data from FIFO to output register
                    rd_ptr <= (rd_ptr + 1);
                end
                else begin
                    rdat_vld_r <= 0;
                end
            end
            else if (~memEmpty && ~rdat_vld_r) begin //refill rdat_r from mem if mem not empty
                rdat_r <= mem_dout;
                rd_ptr <= (rd_ptr + 1);
                rdat_vld_r <= 1;
            end

            if (push && ~pop) begin
                count <= count + 1; // Increment count
            end
            else if (~push && pop) begin
                count <= count - 1; // Decrement count
            end

            memEmpty <= memEmpty_w;

        end
    end

    always_comb begin
        // Update full and empty flags based on count
        full = (count==D+1);
        empty = (count==0);
        mem_we = push && ~empty;

        memEmpty_w = memEmpty;
        if (mem_we) begin
            memEmpty_w = 0;
        end
        else if (count<2) begin
            memEmpty_w = 1;
        end
    end

    dpram #(
        .usr_ram_style ("distributed"),
        .aw            (LOG_D),
        .dw            (WIDTH),
        .max_size      (D),
        .rd_lat        (0)
    ) mem (
        .rd_clk     (clk),
        .raddr      (rd_ptr),
        .dout       (mem_dout),
        .wr_clk     (clk),
        .we         (mem_we),
        .din        (din),
        .waddr      (wr_ptr)
    );


endmodule