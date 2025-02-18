// xmem_array_wr_vld_data (array_partition)
// name = ${name}
// width = ${width}
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        for (int i = 0; i < depth_${name} ; i = i+1) begin
            ${name}[i] <= ${width}'d0;
        end
    end
    else begin
        if (xmem_we != 0 && (xmem_ad >= offset_${name} && xmem_ad < (offset_${name} + depth_${name} * (width_${name} / 8)))) begin
            ${we_statement}
        end
${if_statement}
    end
end

