// generate xmem_rdy signal
always_comb begin
    xmem_rdy = ~(${statement});
end

