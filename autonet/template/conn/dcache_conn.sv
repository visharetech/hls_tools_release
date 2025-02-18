// dcache_conn
// name = ${name}
// module_list = ${module_list}
always_comb begin
    hls_user_idx     = 0;
    hls_user_ap_ce   = '{default:'0};
    hls_user_re      = '{default:'0};
    hls_user_we      = '{default:'0};
    hls_user_we_mask = '{default:'0};
    hls_user_adr     = '{default:'0};
    hls_user_wdat    = '{default:'0};
    dc_ready         = '{default:1'b1};
    dc_enable        = '{default:'0};
    dc_lock_set      = '{default:'0};
    dc_lock_clr      = '{default:'0};
${statement}
end

