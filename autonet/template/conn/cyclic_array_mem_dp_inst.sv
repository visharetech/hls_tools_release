// cyclic_array_mem_dp_inst
// name = ${name}
// bank = ${bank}
// addr_width = ${addr_width}
// data_width = ${data_width}
// depth      = ${depth}
logic ${name}_ce0[${bank}];
logic ${name}_ce1[${bank}];
logic [${data_width}/8-1:0] ${name}_we0[${bank}];
logic [${data_width}/8-1:0] ${name}_we1[${bank}];
logic [${addr_width}-1:0] ${name}_address0[${bank}];
logic [${addr_width}-1:0] ${name}_address1[${bank}];
logic [${data_width}-1:0] ${name}_d0[${bank}];
logic [${data_width}-1:0] ${name}_d1[${bank}];
logic [${data_width}-1:0] ${name}_q0[${bank}];
logic [${data_width}-1:0] ${name}_q1[${bank}];

generate
    for (genvar i = 0; i < ${bank}; i = i + 1) begin
        hls_long_tail_multi_we_mem_dp #(
            .BANK(${data_width}/8),
            .DEPTH(${depth}),
            .DBITS(${data_width})
        )
        inst_${name}
        (
            .clk      ( clk                   ),
            .ce0      ( ${name}_ce0[i]        ),
            .ce1      ( ${name}_ce1[i]        ),
            .we0      ( ${name}_we0[i]        ),
            .we1      ( ${name}_we1[i]        ),
            .address0 ( ${name}_address0[i]   ),
            .address1 ( ${name}_address1[i]   ),
            .d0       ( ${name}_d0[i]         ),
            .d1       ( ${name}_d1[i]         ),
            .q0       ( ${name}_q0[i]         ),
            .q1       ( ${name}_q1[i]         )
        );
    end
endgenerate
