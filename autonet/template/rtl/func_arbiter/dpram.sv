module dpram #(
    parameter usr_ram_style = "distributed",
    parameter aw=16,
    parameter dw=8,
    parameter max_size=256,
    parameter rd_lat = 1
) (
	input rd_clk,
	input [aw-1:0] raddr,
	output reg [dw-1:0] dout,
	input wr_clk,
	input we,
	input [dw-1:0] din,
	input [aw-1:0] waddr
);

// Infer Dual Port Block RAM with Dual clocks
// ram_style: auto | block | distributed

    generate
        if (usr_ram_style=="ultra" && rd_lat==1) begin
            (* ram_style = "ultra" *)	logic [dw-1:0] RAM [max_size-1:0];
            always @(posedge rd_clk) begin
                dout <= RAM[raddr];
            end

            always @(posedge rd_clk) begin
                if (we) RAM[waddr]<=din;
            end
        end
        else if (usr_ram_style=="ultra" && rd_lat==0) begin
            (* ram_style = "ultra" *)	logic [dw-1:0] RAM [max_size-1:0];
            assign dout = RAM[raddr];

            always @(posedge rd_clk) begin
                if (we) RAM[waddr]<=din;
            end
        end
        else if (rd_lat==1) begin
            logic [dw-1:0] RAM [max_size-1:0];
            always @(posedge rd_clk) begin
                dout <= RAM[raddr];
            end

            always @(posedge wr_clk) begin
                if (we) RAM[waddr]<=din;
            end
        end
        else begin
            logic [dw-1:0] RAM [max_size-1:0];
            assign dout = RAM[raddr];

            always @(posedge wr_clk) begin
                if (we) RAM[waddr]<=din;
            end
        end
    endgenerate

endmodule