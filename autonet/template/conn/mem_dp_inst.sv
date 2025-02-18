// hls_long_tail_mem_dp
// name = ${name}
// addr_width = ${addr_width}
// data_width = ${data_width}
// depth      = ${depth}
logic ${name}_ce0;
logic ${name}_ce1;
logic ${name}_we0;
logic ${name}_we1;
logic [${addr_width}-1:0] ${name}_address0;
logic [${addr_width}-1:0] ${name}_address1;
logic [${data_width}-1:0] ${name}_d0;
logic [${data_width}-1:0] ${name}_d1;
logic [${data_width}-1:0] ${name}_q0;
logic [${data_width}-1:0] ${name}_q1;


hls_long_tail_mem_dp #(
    .DEPTH(${depth}),
    .DBITS(${data_width})
)
inst_${name}
(
    .clk      ( clk                ),
    .ce0      ( ${name}_ce0        ),
    .ce1      ( ${name}_ce1        ),
    .we0      ( ${name}_we0        ),
    .we1      ( ${name}_we1        ),
    .address0 ( ${name}_address0   ),
    .address1 ( ${name}_address1   ),
    .d0       ( ${name}_d0         ),
    .d1       ( ${name}_d1         ),
    .q0       ( ${name}_q0         ),
    .q1       ( ${name}_q1         )
);

