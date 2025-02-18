`ifndef XNET_DRV_VH
`define XNET_DRV_VH

`define MAX_TEST_NUM 30000
//`define MAX_TEST_NUM 1000
//`define MAX_TEST_NUM 500

//`define BASIC_TEST
`define RANDOM_TEST


`define INIT_PARTITION_0_ONLY

`define MAX_TIMEOUT_CYCLE  10000



`define wait_sig(signal, cycle) \
	do \
		begin \
			nop(cycle); \
		end \
	while (~signal); \



`define wait_pos(wait_sig, str_sig) \
	begin \
		int t; \
		for (t=0; t<`MAX_TIMEOUT_CYCLE; t++) begin \
			@ (posedge clk); \
			#0.01; \
			if (wait_sig) begin \
				break; \
			end \
		end \
		if (t == `MAX_TIMEOUT_CYCLE) begin \
			$display ("TimeOut: %s", str_sig); \
			#100; \
			$stop; \
		end \
	end \

`define wait_neg(wait_sig, str_sig) \
	begin \
		int t; \
		for (t=0; t<`MAX_TIMEOUT_CYCLE; t++) begin \
			@ (negedge clk); \
			#0.01; \
			if (wait_sig) begin \
				break; \
			end \
		end \
		if (t == `MAX_TIMEOUT_CYCLE) begin \
			$display ("TimeOut: %s", str_sig); \
			#100; \
			$stop; \
		end \
	end \


`define read_latency3_checker(func, sig, rdat_vld) \
	logic [31:0]	``func``_``sig``_src_seq; \
	logic [31:0]	``func``_``sig``_src_seq_r; \
	logic [31:0]	``func``_``sig``_src_seq_2r; \
	logic [31:0]	``func``_``sig``_dst_seq; \
	logic 			``func``_``sig``_read_latency3_err; \
	always @ (posedge clk or negedge rstn) begin \
		if (~rstn) begin \
			``func``_``sig``_src_seq 			<= 1; \
			``func``_``sig``_src_seq_r 	 		<= 1; \
			``func``_``sig``_src_seq_2r	 		<= 1; \
			``func``_``sig``_dst_seq 	 	 	<= 1; \
			``func``_``sig``_read_latency3_err	<= 0; \
		end \
		else begin \
			if (``func``_``sig``_ce0 &~ ``func``_``sig``_we0) begin \
				``func``_``sig``_src_seq <= ``func``_``sig``_src_seq + 1; \
			end \
			if (``func``_ready) begin \
				``func``_``sig``_src_seq_r  <= ``func``_``sig``_src_seq; \
				``func``_``sig``_src_seq_2r <= ``func``_``sig``_src_seq_r; \
				if (rdat_vld) begin \
					``func``_``sig``_dst_seq <= ``func``_``sig``_dst_seq + 1; \
					if ((``func``_``sig``_dst_seq+1)!=``func``_``sig``_src_seq_2r) begin \
						``func``_``sig``_read_latency3_err <= 1; \
					end \
				end \
			end \
		end \
	end

enum {
	WRITE,
	READ
} access_type_e;




//logic [31:0] 					mirror_mem	  [PARTITION][65536];	//for debug
logic [31:0] 					mirror_mem	  [PARTITION][$];



logic [31:0] 					rdat;
logic [7:0]	 					width;
logic [31:0] 					adr;
logic [31:0] 					depth;
logic [31:0] 					inc;
logic 		 					isRead;
logic [LOG2_MAX_PARTITION-1:0]	pidx;

logic [LOG2_MAX_PARTITION-1:0]	q_pidx	[$];
logic [31:0]					q_adr	[$];
logic [31:0]					q_width	[$];
string 							q_func	[$];
string 							q_sig	[$];



logic [31:0]					rq_adr		[$];


logic [31:0]					rd_adr;
logic [31:0]					rd_cnt=0;

logic [63:0] 					wr_push_cnt = 0;	//for debug
logic [63:0] 					wr_pop_cnt = 0;		//for debug



logic [31:0]	debug0=0;
logic [31:0]	debug1=0;
logic [31:0]	debug2=0;
logic [31:0]	debug3=0;
logic [31:0]	debug4=0;
logic [31:0]	debug5=0;
logic [31:0]	debug6=0;
logic [31:0]	debug7=0;
logic [31:0]	debug8=0;
logic [31:0]	debug9=0;
logic [31:0]	debug10=0;
logic [31:0]	debug11=0;
logic [31:0]	debug12=0;
logic [31:0]	debug13=0;
logic [31:0]	debug14=0;
logic [31:0]	debug15=0;







integer f=0;
integer p=0;
integer t=0;
logic looping;


initial begin

	`ifdef INIT_PARTITION_0_ONLY
		$display ("");
		$display ("[WARNING] init partition 0 only for saving time");
		$display ("*** pls disable the marco of INIT_PARTITION_0 for running FULL TEST");
		$display ("");
	`endif

	xnet_sig_init();

	wait(xmem_init_param_done);
	nop(10);

	xmem_mem_init(); //by risc interface
	nop(5);

`ifdef BASIC_TEST
	$display ("BASIC TEST\n");

	pidx = 0; //where p = 0, 1, ... (MAX_PARTITION-1)
    
    xnet_drv_test(innerloop_ff_hevc_extract_rbsp_1_hls,         pidx);	//(func, pidx)
    xnet_drv_test(innerloop_ff_hevc_extract_rbsp_2_hls,         pidx);	//(func, pidx)
    xnet_drv_test(hevc_find_frame_end_hls,                      pidx);	//(func, pidx)
    xnet_drv_test(intra_prediction_unit_ex_hls,                 pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_unit_ex_hls,                    pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_unit_ex_hls_dup1,               pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_unit_ex_hls_dup2,               pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_unit_ex_hls_dup3,               pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_tree_hls,                       pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_tree_hls_dup1,                  pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_tree_hls_dup2,                  pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_tree_hls_dup3,                  pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_quadtree_hls,                      pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_quadtree_hls_dup1,                 pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_quadtree_hls_dup2,                 pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_quadtree_hls_dup3,                 pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_unit_hls,                          pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_unit_hls_dup1,                     pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_unit_hls_dup2,                     pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_unit_hls_dup3,                     pidx);	//(func, pidx)
    xnet_drv_test(copy_top_left_pixel_hls,                      pidx);	//(func, pidx)
    xnet_drv_test(genPredCol_hls,                               pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_get_sub_cu_zscan_id_hls,              pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_skip_flag_decode_hls,                 pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_tree_hls1,                      pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_tree_hls3,                      pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_tree_hls4,                      pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_set_qPy_hls,                          pidx);	//(func, pidx)
    xnet_drv_test(coding_quadtree_1_hls,                        pidx);	//(func, pidx)
    xnet_drv_test(coding_quadtree_3_hls,                        pidx);	//(func, pidx)
    xnet_drv_test(coding_quadtree_4_hls,                        pidx);	//(func, pidx)
    xnet_drv_test(coding_quadtree_4_hls_dup1,                   pidx);	//(func, pidx)
    xnet_drv_test(coding_quadtree_4_hls_dup2,                   pidx);	//(func, pidx)
    xnet_drv_test(coding_quadtree_4_hls_dup3,                   pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_unit_hls,                       pidx);	//(func, pidx)
    xnet_drv_test(hls_transform_unit_2_hls,                     pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_unit_sub_hls,                      pidx);	//(func, pidx)
    xnet_drv_test(hls_coding_unit_sub_hls2,                     pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_deblocking_boundary_strengths_hls1,   pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_deblocking_boundary_strengths_hls2,   pidx);	//(func, pidx)
    xnet_drv_test(hls_decode_neighbour_hls,                     pidx);	//(func, pidx)
    xnet_drv_test(intra_prediction_unit_2_hls,                  pidx);	//(func, pidx)
    xnet_drv_test(intra_prediction_unit_3_hls,                  pidx);	//(func, pidx)
    xnet_drv_test(set_tab_mvf_pred_flag_hls,                    pidx);	//(func, pidx)
    xnet_drv_test(init_intra_neighbors_hls,                     pidx);	//(func, pidx)
    xnet_drv_test(init_intra_neighbors_chroma_hls,              pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_set_neighbour_available_hls,          pidx);	//(func, pidx)
    xnet_drv_test(intra_prediction_unit_default_value_hls,      pidx);	//(func, pidx)
    xnet_drv_test(luma_mc_uni_libx265_hls,                      pidx);	//(func, pidx)
    xnet_drv_test(chroma_mc_uni_libx265_hls,                    pidx);	//(func, pidx)
    xnet_drv_test(sao_param_hls,                                pidx);	//(func, pidx)
    xnet_drv_test(intra_pred_libx265_hls,                       pidx);	//(func, pidx)
    xnet_drv_test(add_weight_uni_hls,                           pidx);	//(func, pidx)
    xnet_drv_test(z_scan_block_avail_hls,                       pidx);	//(func, pidx)
    xnet_drv_test(mv_mp_mode_mx_hls,                            pidx);	//(func, pidx)
    xnet_drv_test(mv_mp_mode_mx_lt_hls,                         pidx);	//(func, pidx)
    xnet_drv_test(temporal_luma_motion_vector_hls,              pidx);	//(func, pidx)
    xnet_drv_test(is_diff_mer_hls,                              pidx);	//(func, pidx)
    xnet_drv_test(append_zero_motion_vector_candidates_hls,     pidx);	//(func, pidx)
    xnet_drv_test(merge_mode_exit_hls,                          pidx);	//(func, pidx)
    xnet_drv_test(set_to_mergecand_list_hls,                    pidx);	//(func, pidx)
    xnet_drv_test(compare_mv_ref_idx_hls,                       pidx);	//(func, pidx)
    xnet_drv_test(combined_bi_predictive_merge_candidates_hls,  pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_luma_mv_merge_mode_hls,               pidx);	//(func, pidx)
    xnet_drv_test(ff_hevc_luma_mv_mvp_mode_hls,                 pidx);	//(func, pidx)
    xnet_drv_test(interp_vert_generic_ex_hls,                   pidx);	//(func, pidx)
    xnet_drv_test(interp_horiz_generic_ex_hls,                  pidx);	//(func, pidx)
    xnet_drv_test(interp_copy_generic_ex_hls,                   pidx);	//(func, pidx)
    xnet_drv_test(libx265videodsp_emulated_edge_mc_ex_hls,      pidx);	//(func, pidx)
    xnet_drv_test(hls_prediction_unit_hls,                      pidx);	//(func, pidx)
`endif

`ifdef RANDOM_TEST
	$display ("RANDOM TEST\n");

    for (t=0; t<`MAX_TEST_NUM;  t++) begin
        fork 
		
			$display ("test: %0d / %0d", t, `MAX_TEST_NUM - 1);
			//p = $urandom_range(0, MAX_PARTITION-1);
			//f =	$urandom_range(0, HLS_NUM-1);
			
			begin 
				logic 	  	 isRead;
				logic [1:0]  range;
				logic [31:0] riscAdr;
				logic [31:0] riscRdat;
				logic [31:0] riscWdat;
				logic [31:0] loopNum;
				
					
				nop($urandom_range(0, 200));

				
				loopNum = $urandom_range(10, 5000);
				
				for (int i=0; i<loopNum; i++) begin 
					nop($urandom_range(1, 5));
					
					isRead = $urandom_range(0, 1);
					{range, riscAdr} = gen_range_and_riscAdr("risc_cmd", isRead);
					riscWdat = $random;
					pidx = 0;
			
					if (isRead == WRITE) begin 
						//---------------------------------------------------------------------------------------------------
						//riscv write 
						//---------------------------------------------------------------------------------------------------
						risc_write({pidx, riscAdr}, riscWdat);
						wr_queue_push(pidx, riscAdr, 32, riscWdat, "risc_cmd", "write");					
					end 
					else begin 
						//---------------------------------------------------------------------------------------------------
						//riscv read 
						//---------------------------------------------------------------------------------------------------					
						risc_read({pidx, riscAdr}, riscRdat);
						`wait_neg(risc_do_vld, "risc_read");
						rd_verify(pidx, riscAdr, 32, riscRdat, "risc_cmd", "read");					
					end 
				end 
			end 
			begin 
				f =	$urandom_range(0, HLS_NUM-1);			
				//xnet_drv_test(cyclic_func0, 0);	//(func, pidx)
				xnet_drv_test(f, 0);	//(func, pidx)
			end 

			//begin 
			//	f =	$urandom_range(0, HLS_NUM-1);			
			//	//xnet_drv_test(cyclic_func0, 0);	//(func, pidx)
			//	xnet_drv_test(f, 0);	//(func, pidx)
			//end 
			
        join 	
        nop(100);
        $display("wr_verify...");
        wr_verify();
	end  




	

`endif

	nop(5);

	$display ("\n");
	$display ("Success !");
	$stop;
end


//--------------------------------------------------------------------------------------
//include xnet_drv_test
//--------------------------------------------------------------------------------------
//`include "xnet_drv_test.vh"
`include "xmem_tb.vh"




//--------------------------------------------------------------------------------------
//Task
//--------------------------------------------------------------------------------------

task automatic xmem_mem_init;
	logic [LOG2_MAX_PARTITION-1:0]	pidx;
	logic [XMEM_PART_AW-1:0] 	  	ad;
	logic [31:0]					wdat;
	logic [31:0]					rdat;
	integer  						max_part;
	begin

	`ifdef INIT_PARTITION_0_ONLY
		max_part = 1;
	`else
		max_part = PARTITION;
	`endif


		for (int p=0; p<max_part; p++) begin 	//testing

			$display ("init partition: %0d", p);

			for (int i=0; i<( rangeStart[p+1] - rangeStart[p] ); i+=4) begin
				pidx = p;
				ad  = i;
				wdat  = rangeStart[p] + i;
				mirror_mem[pidx][ad/4] = wdat;

				risc_write({pidx, ad}, wdat);
				risc_read ({pidx, ad}, rdat);

				assert(rdat !== 'x) else $fatal("xmem_mem_init.rdat is undefined at time %0t", $time);

				if (wdat != rdat) begin
					$display ("[xmem_mem_init] ERR");

					$display ("ad:   %0d", ad);
					$display ("pidx: %0d", pidx);
					$display ("wdat: %0x", wdat);
					$display ("rdat: %0x", rdat);
					$stop;
				end


			end
		end

	end
endtask


task automatic update_mirror_mem;
	input [LOG2_MAX_PARTITION-1:0] 	pidx;
	input [31:0] 					adr;
	input [7:0]  					width;
	input [127:0]					wdat;

	logic [31:0] 					num;
	logic [31:0] 					rdat;
	logic [XMEM_PART_AW-1:0] 		ad;
	begin

		assert(pidx  !== 'x) else $fatal("update_mirror_mem.pidx  is undefined at time %0t", $time);
		assert(adr   !== 'x) else $fatal("update_mirror_mem.adr   is undefined at time %0t", $time);
		assert(width !== 'x) else $fatal("update_mirror_mem.width is undefined at time %0t", $time);
		assert(wdat  !== 'x) else $fatal("update_mirror_mem.wdat  is undefined at time %0t", $time);


		width = (width <8) ? 8 : width;
		num = (width < 32) ? 1 : width/32;

		for (int n=0; n<num; n++) begin
			ad = adr+n*4;
            //if (ad == 9842 * 4) $display("------------- %t: %h ------------------", $time, wdat);
			if (n == 0) begin
				case (width)
//				8: begin
				1, 2, 3, 4, 5, 6, 7, 8: begin
					case (adr[1:0])
					2'b00: begin
						mirror_mem[pidx][(adr+n*4)/4] = {mirror_mem[pidx][(adr+n*4)/4][31:8], wdat[7:0]};
					end
					2'b01: begin
						mirror_mem[pidx][(adr+n*4)/4] = {mirror_mem[pidx][(adr+n*4)/4][31:16], wdat[7:0], mirror_mem[pidx][(adr+n*4)/4][7:0]};
					end
					2'b10: begin
						mirror_mem[pidx][(adr+n*4)/4] = {mirror_mem[pidx][(adr+n*4)/4][31:24], wdat[7:0], mirror_mem[pidx][(adr+n*4)/4][15:0]};
					end
					2'b11: begin
						mirror_mem[pidx][(adr+n*4)/4] = {wdat[7:0], mirror_mem[pidx][(adr+n*4)/4][23:0]};
					end
					endcase
				end
				16: begin
					case (adr[1])
					1'b0: begin
						mirror_mem[pidx][(adr+n*4)/4] = {mirror_mem[pidx][(adr+n*4)/4][31:16], wdat[15:0]};
					end
					1'b1: begin
						mirror_mem[pidx][(adr+n*4)/4] = {wdat[15:0], mirror_mem[pidx][(adr+n*4)/4][15:0]};
					end
					endcase
				end
				default: begin //32, 64, 96, 128
					mirror_mem[pidx][(adr+n*4)/4] = wdat[31:0];
				end
				endcase
			end
			else if (n==1) //for width = 64
				mirror_mem[pidx][(adr+n*4)/4] = wdat[63 : 32];
			else if (n==2) //for width = 96
				mirror_mem[pidx][(adr+n*4)/4] = wdat[95 : 64];
			else if (n==3) //for width = 128
				mirror_mem[pidx][(adr+n*4)/4] = wdat[127 : 96];

		end

	end
endtask



task automatic wr_queue_push;
	input [LOG2_MAX_PARTITION-1:0] 	pidx;
	input [31:0]					adr;
	input [31:0]					width;
	input [127:0]					wdat;
	input string 					func;
	input string 					sig;
	begin

		assert(pidx  !== 'x) else $fatal("wr_queue_push.pidx  is undefined at time %0t", $time);
		assert(adr   !== 'x) else $fatal("wr_queue_push.adr   is undefined at time %0t", $time);
		assert(width !== 'x) else $fatal("wr_queue_push.width is undefined at time %0t", $time);
		assert(wdat  !== 'x) else $fatal("wr_queue_push.wdat  is undefined at time %0t", $time);

		q_pidx.push_back  	( pidx	);
		q_adr.push_back  	( adr	);
		q_width.push_back 	( width	);
		q_func.push_back  	( func	);
		q_sig.push_back	 	( sig	);


/*
		$display ("----------------------- size %d", q_pidx.size());
		$display ("-- pidx:  %d", pidx);
		$display ("-- adr:   %d", adr);
		$display ("-- width: %d", width);
		$display ("-- wdat:  0x%0x", wdat);
*/


		//read xmem and write to mirror_mem
		update_mirror_mem(pidx, adr, width, wdat);

	end
endtask


task automatic wr_verify;
	logic [LOG2_MAX_PARTITION-1:0] 	pidx;
	logic [31:0]					adr;
	logic [31:0]					width;
	logic [127:0]					wdat;
	string 							func;
	string 							sig;

	logic [31:0] 					num;
	logic [XMEM_PART_AW-1:0] 		ad;
	logic [31:0]					rdat;
	logic [31:0]					size;

	logic [31:0]					cnt1 =0 ;
	begin




		//mainly use adr for accessing mirror_mem and xmem_mem
		while (q_pidx.size() > 0) begin


			pidx	= q_pidx.pop_front 	();
			adr		= q_adr.pop_front 	();
			width	= q_width.pop_front	();
			func 	= q_func.pop_front 	();
			sig		= q_sig.pop_front 	();
			num = (width < 32) ? 1 : width/32;



			for (int n=0; n<num; n++) begin
				ad = adr+n*4;
				risc_read({pidx, ad}, rdat);


				if (n == 0) begin
					if (bitmask(mirror_mem[pidx][(adr+n*4)/4] >> (adr[1:0]*8), width) != bitmask(rdat, width)) begin
						$display ("[%0t][WR ERR]: %s, %s", $time, func, sig);
						$display ("mirror_mem[%0d][%0d]: 0x%0x", pidx, (adr+n*4)/4,  mirror_mem[pidx][(adr+n*4)/4]);
						$display ("rdat: 0x%0x", bitmask(rdat, width));
						#10;
						$stop;
					end
				end
				else begin
					if (mirror_mem[pidx][(adr+n*4)/4] != rdat[n*32+:32]) begin
						$display ("[%0t][WR ERR]: %s, %s", $time, func, sig);
						$display ("mirror_mem[%0d][%0d]: 0x%0x", pidx, (adr+n*4)/4,  mirror_mem[pidx][(adr+n*4)/4]);
						$display ("rdat: 0x%0x", rdat[n*32+:32]);
						#10;
						$stop;
					end
				end
			end

		end


	end
endtask





task automatic rd_verify;
	input [7:0]  	pidx;
	input [31:0] 	adr;
	input [7:0]  	width;
	input [127:0] 	datIn;
	input string 	func;
	input string 	sig;
	//---
	logic [31:0] num;
	begin

		assert(pidx  !== 'x) else $fatal("rd_verify.pidx  is undefined at time %0t", $time);
		assert(adr   !== 'x) else $fatal("rd_verify.adr   is undefined at time %0t", $time);
		assert(width !== 'x) else $fatal("rd_verify.width is undefined at time %0t", $time);
		assert(datIn !== 'x) else $fatal("rd_verify.datIn is undefined at time %0t", $time);


		num = (width < 32) ? 1 : width/32;
		for (int n=0; n<num; n++) begin
			if (n == 0) begin

				debug10 = bitmask(mirror_mem[pidx][(adr+n*4)/4] >> (adr[1:0]*8), width);
				debug11 = bitmask(datIn, width);

				

				if (bitmask(mirror_mem[pidx][(adr+n*4)/4] >> (adr[1:0]*8), width) != bitmask(datIn, width)) begin
				
					logic [31:0] chk_data0 = bitmask(mirror_mem[pidx][(adr+n*4)/4] >> (adr[1:0]*8), width);	
					logic [31:0] chk_data1 = bitmask(datIn, width);
					
					$display ("chk_data0: %x", chk_data0);
					$display ("chk_data1: %x", chk_data1);
					$display ("width: %d", width);
					$display ("adr: %d", adr);
					
				
					debug15 = 1;
					$display ("[RD ERR at %0t]: %s, %s", $time, func, sig);
					$display ("mirror_mem[%0d][%0d]: 0x%0x", pidx, (adr+n*4)/4,  mirror_mem[pidx][(adr+n*4)/4]);
					$display ("datIn: 0x%0x", bitmask(datIn, width));
					#100;
					$stop;
				end
			end
			else begin
				if (mirror_mem[pidx][(adr+n*4)/4] != datIn[n*32+:32]) begin
				
					logic [31:0] chk_data0 = bitmask(mirror_mem[pidx][(adr+n*4)/4] >> (adr[1:0]*8), width);	
					logic [31:0] chk_data1 = bitmask(datIn, width);
					
					$display ("chk_data0: %x", chk_data0);
					$display ("chk_data1: %x", chk_data1);
					$display ("width: %d", width);
				
				
					debug15 = 2;
					$display ("[RD ERR at %0t]: %s, %s", $time, func, sig);
					$display ("mirror_mem[%0d][%0d]: 0x%0x", pidx, (adr+n*4)/4,  mirror_mem[pidx][(adr+n*4)/4]);
					$display ("datIn: 0x%0x", datIn[n*32+:32]);
					#100;
					$stop;
				end
			end
		end

	end
endtask


task automatic risc_write;
	input [31:0] adr;
	input [31:0] din;
	begin
		do
			begin
				risc_we = {4{1'b1}};
				risc_ad = adr;
				risc_di = din;
				nop(1);
			end
		while(risc_rdy == 0);

		risc_we = 0;
		risc_ad = 0;
		risc_di = 0;
	end
endtask

task automatic risc_read;
	input [31:0] 		adr;
	output logic [31:0] dout;
	begin

		do
			begin
				risc_re = 1;
				risc_ad = adr;
				nop(1);
			end
		while (risc_rdy == 0);

		risc_re = 0;
		risc_ad = 0;
        nop(2);

		while (1) begin
			#0.2;
			if (risc_do_vld) begin
				dout = risc_do;
				break;
			end
			nop(1);
		end

	end
endtask




task automatic nop;
	input int n;
	begin
		repeat (n) begin
			@ (posedge clk);
			#0.1;
		end
	end
endtask




//-----------------------------------------------------------------------------
//Function
//-----------------------------------------------------------------------------

function logic [31:0] bitmask;
	input  [127:0] datIn;
	input  [7:0]   width;
	begin

		case(width)
		1: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_00000001;
		end
		2: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_00000003;
		end
		3: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_00000007;
		end
		4: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_0000000f;
		end
		5: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_0000001f;
		end
		6: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_0000003f;
		end
		7: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_0000007f;
		end
		8: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_000000ff;
		end
		16: begin
			bitmask = datIn & 128'h00000000_00000000_00000000_0000ffff;
		end
		default: begin //32, 64, 96, 128
			bitmask = datIn & 128'h00000000_00000000_00000000_ffffffff;
		end
		endcase

	end
endfunction



function logic [31:0] align;
	input logic [31:0] val;
	input logic [31:0] n;
	integer int_val;
	begin
		n = (n<4) ? 4 : n;
		int_val = val/n;
		align = int_val*n;
	end
endfunction

function logic [31:0] align4;
	input [31:0] val;
	begin
		align4 = val & ~32'h3;
	end
endfunction

//-----------------------------------------
function logic [33:0] gen_range_and_riscAdr;
	input string func;
	input  		 isRead;
	logic [31:0] riscAdr;
	logic [1:0]  range;
	string 		 str1;
	string 		 str2;	
	begin 
		range = 0;
		riscAdr = $urandom_range(0, subRangeStart[0][CYCLIC]-4);
		if (riscAdr < subRangeStart[0][ARRAY-1]) begin //scalar range
			riscAdr = $urandom_range(subRangeStart[0][ARRAY-1] - 128, subRangeStart[0][ARRAY-1]-4);
			range = 0;
		end 
		else if (riscAdr < subRangeStart[0][CYCLIC-1])  begin //array range
			riscAdr = $urandom_range(subRangeStart[0][CYCLIC-1] - 128, subRangeStart[0][CYCLIC-1]-4);
			range = 1;
		end 
		else if (riscAdr < subRangeStart[0][CYCLIC])  begin //cyclic range 
			riscAdr = $urandom_range(subRangeStart[0][CYCLIC] - 128, subRangeStart[0][CYCLIC]-4);
			range = 2;
		end 
		riscAdr = align(riscAdr, 4);
		
		gen_range_and_riscAdr = {range, riscAdr};
		
		str1 = (range == 0) ? "Scalar" : ((range == 1) ? "Array" : "Cyclic");
		str2 = (isRead== WRITE) ? "write" : "read";
		//$display ("[%s] %s risc_%s:", func, str1, str2);		
		
		
	end 
endfunction  









`endif
