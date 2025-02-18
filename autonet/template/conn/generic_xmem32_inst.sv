// generic_xmem32 (Use hls_long_tail_multi_we_mem_dp module which supports 8/16/32bit access)
logic generic_xmem32_ce0;
logic generic_xmem32_ce1;
logic [32/8-1:0] generic_xmem32_we0;
logic [32/8-1:0] generic_xmem32_we1;
logic [$$clog2(depth_generic_xmem32)-1:0] generic_xmem32_address0;
logic [$$clog2(depth_generic_xmem32)-1:0] generic_xmem32_address1;
logic [32-1:0] generic_xmem32_d0;
logic [32-1:0] generic_xmem32_d1;
logic [32-1:0] generic_xmem32_q0;
logic [32-1:0] generic_xmem32_q1;

hls_long_tail_multi_we_mem_dp #(
    .BANK(32/8),
    .DEPTH(depth_generic_xmem32),
    .DBITS(32)
)
inst_generic_xmem32
(
    .clk      ( clk                ),
    .ce0      ( generic_xmem32_ce0        ),
    .ce1      ( generic_xmem32_ce1        ),
    .we0      ( generic_xmem32_we0        ),
    .we1      ( generic_xmem32_we1        ),
    .address0 ( generic_xmem32_address0   ),
    .address1 ( generic_xmem32_address1   ),
    .d0       ( generic_xmem32_d0         ),
    .d1       ( generic_xmem32_d1         ),
    .q0       ( generic_xmem32_q0         ),
    .q1       ( generic_xmem32_q1         )
);

always_comb begin
    //Port 0
    generic_xmem32_ce0      = 0;
    generic_xmem32_we0      = 0;
    generic_xmem32_address0 = 0;
    generic_xmem32_d0       = 0;
    generic_xmem32_ce1      = 0;
    generic_xmem32_we1      = 0;
    generic_xmem32_address1 = 0;
    generic_xmem32_d1       = 0;
    if ((xmem_we != 0 || xmem_re) && ( xmem_ad < (depth_generic_xmem32 * 4))) begin
        generic_xmem32_ce0      = 1;
        generic_xmem32_we0      = `riscv_xmem_we0(0, 32);
        generic_xmem32_address0 = `riscv_xmem_address0(0, 32);
        generic_xmem32_d0       = `riscv_xmem_d0(0, 32);
    end
    //Port 1
end

