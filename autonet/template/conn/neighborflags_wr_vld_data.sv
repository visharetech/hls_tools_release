// neighborflags_wr_vld_data
// name = ${name}
// signame = ${signame}
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        ${name} <= 'd0;
    end
    else begin
        if (xmem_we != 0) begin
            if (xmem_ad >= offset_${name} && xmem_ad < (offset_${name} + 4))
                ${name}[31:0] <= xmem_di;
            else if (xmem_ad >= (offset_${name} + 4) && xmem_ad < (offset_${name} + 8))
                ${name}[63:32] <= xmem_di;
            else if (xmem_ad >= (offset_${name} + 8) && xmem_ad < (offset_${name} + 12))
                ${name}[64] <= xmem_di[0];
        end
${elif_statement}
    end
end

