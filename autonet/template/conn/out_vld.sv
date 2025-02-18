// out_vld_data
// signal = ${name}
// vld_name = ${vld_name}
// module_name = ${module_name}
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        ${module_name}_${name}_r <= 0;
    end
    else begin
        if (${vld_name})
            ${module_name}_${name}_r <= ${module_name}_${name};
    end
end

