custom_connection inst_custom_connection (
    .clk                ( clk               ),
    .rstn               ( rstn              ),
    //connected to hls function
    .ap_arb_start       ( ap_arb_start      ),
    .ap_arb_ret         ( ap_arb_ret        ),
    .ap_start           ( ap_start          ),
    .ap_ready           ( ap_ready          ),
    .ap_idle            ( ap_idle           ),
    .ap_done            ( ap_done           ),
    .ap_part            ( ap_part           ),
    //dual port bank in scalar range
    .scalar_argVld      ( scalar_argVld     ),
    .scalar_argAck      ( scalar_argAck     ),
    .scalar_adr         ( scalar_adr        ),
    .scalar_wdat        ( scalar_wdat       ),
    .scalar_rdat        ( scalar_rdat       ),
    .scalar_rdat_vld    ( scalar_rdat_vld   ),
    //single port bank in array range
    .array_argRdy       ( array_argRdy      ),
    .array_ap_ce        ( array_ap_ce       ),
    .array_argVld       ( array_argVld      ),
    .array_argAck       ( array_argAck      ),
    .array_adr          ( array_adr         ),
    .array_wdat         ( array_wdat        ),
    .array_rdat         ( array_rdat        ),
    .array_rdat_vld     ( array_rdat_vld    ),
    //wide port bank in cyclic range
	.cyclic_argRdy		( cyclic_argRdy		),
	.cyclic_ap_ce 		( cyclic_ap_ce		),
    .cyclic_argVld      ( cyclic_argVld     ),
    .cyclic_argAck      ( cyclic_argAck     ),
    .cyclic_adr         ( cyclic_adr        ),
    .cyclic_wdat        ( cyclic_wdat       ),
    .cyclic_rdat        ( cyclic_rdat       ),
    .cyclic_rdat_vld    ( cyclic_rdat_vld   ),

    //hls function connection
${module_link}
);