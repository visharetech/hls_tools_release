// xmem_cyclic_array_rd_data
// name = ${name}
// module_list = ${module_list}
// bank = ${bank}
// shift_op = ${shift_op}
wire [$$clog2(${bank})-1:0] mem_sel_${name} = (xmem_ad - offset_${name})${shift_op};
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

        if ((xmem_we != 0 || xmem_re) && (mem_sel_${name} == i) && range_${name}) begin
            ${name}_ce0[i]      = 1;
            ${name}_we0[i]      = `riscv_xmem_we0(offset_${name}, width_${name});
            ${name}_address0[i] = `riscv_xmem_address0(offset_${name}, width_${name})/${bank};
            ${name}_d0[i]       = `riscv_xmem_d0(offset_${name}, width_${name});
        end
${elif_statement}
${port1_statement}
${q0_statement}
${q1_statement}
    end
end


