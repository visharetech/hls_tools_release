// xmem_wr_data
// signal = ${name}${is_array}
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        ${name} <= ${reset_value};
    end
    else begin
        ${we_statement}
    end
end

