// xmem_array_rd_data (array partition)
// name = ${name}
// module_list = ${module_list}
wire range_${name} = (xmem_ad >= offset_${name} && xmem_ad < (offset_${name} + depth_${name} * (width_${name} / 8)));
always_comb begin
    for (integer i=0; i<${bank}; i+=1) begin
        ${name}_ce0[i]      = 0;
        ${name}_we0[i]      = 0;
        ${name}_address0[i] = 0;
        ${name}_d0[i]       = 0;

        ${name}_ce1[i]      = 0;
        ${name}_we1[i]      = 0;
        ${name}_address1[i] = 0;
        ${name}_d1[i]       = 0;
    end
    if ((xmem_we != 0 || xmem_re) && range_${name}) begin
        ${name}_ce0[0]      = 1;
        ${name}_we0[0]      = `riscv_xmem_we0(offset_${name}, width_${name});
        ${name}_address0[0] = `riscv_xmem_address0(offset_${name}, width_${name})/${bank};
        ${name}_d0[0]       = `riscv_xmem_d0(offset_${name}, width_${name});
    end
    
    for(integer i=0; i<${bank}; i++) begin
    ${elif_statement}
    ${port1_statement}
    ${q0_statement}
    ${q1_statement}
    end
end
