
module sync_fifo_v2#(
                      parameter usr_ram_style = "distributed",
                      parameter dw            = 32,
                      parameter aw            = 2,
                      parameter rd_lat        = 1
                  )(
                      input                   clk,
                      input                   rstn,

                      input                   rd_en,
                      output logic [dw-1 : 0] dout,
                      input                   wr_en,
                      input        [dw-1 : 0] din,
                      output logic            full,
                      output logic            almost_full,
                      output logic            empty
                  );
    localparam max_size = 1<<aw;
//--------------internal register declaration
    logic [aw-1:0]    wr_pointer;
    logic [aw-1:0]    rd_pointer;
    logic [aw :0]     status_count;

//--------------wr_pointer pointing to write address
    always_ff @(posedge clk or negedge rstn) begin
        if(~rstn)
            wr_pointer <= 0;
        else if (wr_en)
            wr_pointer <= wr_pointer + 1;
    end
//-------------rd_pointer points to read address
    always_ff @(posedge clk or negedge rstn) begin
        if(~rstn)
            rd_pointer <= 0;
        else if (rd_en)
            rd_pointer <= rd_pointer + 1;
     end

//-------------read from FIFO
//--------------Status pointer for full and empty checking
    always_ff @(posedge clk or negedge rstn) begin
        if(~rstn)
            status_count <= 0;
        else if(wr_en && !rd_en && ~full)
            status_count <= status_count + 1;
        else if(rd_en && !wr_en && ~empty)
            status_count <= status_count - 1;
    end

   assign full = (status_count == (max_size));
   assign almost_full = (status_count == (max_size-1));
   assign empty = (status_count == 0);

   dpram  #(
                .usr_ram_style  (usr_ram_style),
                .aw             (aw           ),
                .dw             (dw           ),
                .max_size       (max_size     ),
                .rd_lat         (rd_lat       )
   )dpram_u0(
           .rd_clk ( clk                 ),
           .raddr  ( rd_pointer[aw-1:0]  ),
           .dout   ( dout                ),
           .wr_clk ( clk                 ),
           .we     ( wr_en && !full      ),
           .din    ( din                 ),
           .waddr  ( wr_pointer[aw-1:0]  )
       );

endmodule // sync_fifo