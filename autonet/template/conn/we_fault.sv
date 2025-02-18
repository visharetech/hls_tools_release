// generate we_fault when the address is out of range
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        we_fault <= 0;
    end
    else begin
        if (xmem_we != 0 && (${statement})) begin
            we_fault <= 1;
        end
    end
end

logic fault;
assign fault = we_fault | rd_fault;

