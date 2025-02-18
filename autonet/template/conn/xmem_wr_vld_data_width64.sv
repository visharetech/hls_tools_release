// xmem_wr_vld_data_width64
// name = ${name}
// signame = ${signame}
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        ${name} <= 0;
    end
    else begin
        if (xmem_we != 0 && (xmem_ad >= offset_${name} && xmem_ad < (offset_${name} + 8))) begin
            if (xmem_ad[2])
                ${name}[63:32] <= xmem_di;
            else
                ${name}[31:0] <= xmem_di;
        end
${elif_statement}
    end
end

