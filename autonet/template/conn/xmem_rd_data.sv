// xmem_rd_data
// name = ${name}${is_multi_we}
// module_list = ${module_list}
always_comb begin
    //Port 0
    ${name}_ce0      = 0;
    ${name}_we0      = 0;
    ${name}_address0 = 0;
    ${name}_d0       = 0;
    ${name}_ce1      = 0;
    ${name}_we1      = 0;
    ${name}_address1 = 0;
    ${name}_d1       = 0;
    if ((xmem_we != 0 || xmem_re) && (xmem_ad >= offset_${name} && xmem_ad < (offset_${name} + depth_${name} * (width_${name} / 8)))) begin
        ${name}_ce0      = 1;
        ${name}_we0      = `riscv_xmem_we0(offset_${name}, ${width});
        ${name}_address0 = `riscv_xmem_address0(offset_${name}, ${width});
        ${name}_d0       = `riscv_xmem_d0(offset_${name}, ${width});
    end
${elif_statement}
    //Port 1
${port1_statement}
${q0_statement}
${q1_statement}
end

