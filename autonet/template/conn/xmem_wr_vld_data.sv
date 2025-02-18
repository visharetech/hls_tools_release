// xmem_wr_vld_data
// name = ${name}
// signame = ${signame}
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        ${name} <= 0;
    end
    else begin
        if (xmem_we != 0 && xmem_ad == offset_${name})
            ${name} <= xmem_di;
${elif_statement}
    end
end

