

//integer fp;
//logic [7:0] bin_buf[$];
//logic [7:0] fsize;
//logic [31:0] binCnt;
//string decBin_file;
//logic [31:0] dlyCnt;
logic 	decBin_get_r[CORE_NUM] = '{default:'0};
logic 	decBin_stop[CORE_NUM] = '{default:'0};


always @ (posedge clk) begin 
	for (int i = 0; i < CORE_NUM; i = i + 1) begin
		decBin_get_r[i] <= decBin_get[i];
	end
end  



task automatic decodeBin_model(string decBin_file, int core_id);
	begin 
		//logic [7:0] dummy_ctx;
		integer fp;
		logic [7:0] bin_buf[$];
		logic [7:0] fsize;
		logic [31:0] binCnt;
		logic [31:0] dlyCnt;
		fp = $fopen (decBin_file, "rb");
		fsize = $fread(bin_buf, fp);
		$fclose(fp);
		$display ("%s fsize: %d", decBin_file, fsize);
	
		decBin_stop[core_id] = 0;
		decBin_rdy[core_id] = 1;
		binCnt = 0;
		dlyCnt = 0;
		
		fork 
			READY:
			while (decBin_stop[core_id] == 0) begin
				@ (posedge clk);
				#0.1;
				if (decBin_get_r[core_id]) begin 
					decBin_rdy[core_id] = 0;
				end 
				if (decBin_vld[core_id]) begin 
					decBin_rdy[core_id] = 1;
				end 
			end 
			DELAY:
			while (decBin_stop[core_id] == 0) begin
				@ (posedge clk);
				#0.1;
				if (decBin_get[core_id]) begin 
					dlyCnt = $urandom_range(2, 50);
				end 
			end
			VALID: 
			while (decBin_stop[core_id] == 0) begin
				@ (posedge clk)
				#0.2;
				decBin_vld[core_id] = 0;
				if (dlyCnt !=0) begin 
					dlyCnt--;
					if (dlyCnt ==0) begin 
						binCnt++;
						dlyCnt = 0;
						decBin_vld[core_id] = 1;
						//dummy_ctx = bin_buf.pop_front();
						//dummy_ctx = bin_buf.pop_front();
						decBin_bin[core_id] = bin_buf.pop_front();
					end
				end 
			end 
			
			
		join 
		
	end 
endtask

task automatic decodeBin_model_stop(int core_id);
	decBin_stop[core_id] = 1;
	@ (posedge clk);
	@ (posedge clk);
endtask
