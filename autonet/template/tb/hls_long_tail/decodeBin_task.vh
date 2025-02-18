typedef struct
{
    logic [8:0] ctx;
    logic       bin;
} decodeBin_t;

//DecodeBin Model
task automatic decodeBin_model(string decBin_file, int core_id);
    decodeBin_t    decodeBin_queue[$];
    logic [7 : 0]  byte_buf[$];
    int            fd;
    int            fsize;
    int            latency;
    decodeBin_t    tmp;

    fd = $fopen(decBin_file, "rb");
    fsize = 0;
    if (fd != 0) begin

        //Read file
        fsize = $fread(byte_buf, fd);

        //DecodeBin data queue
        for (int i = 0; i < fsize; i += 2) begin
            tmp.ctx = byte_buf.pop_front() + (byte_buf.pop_front() << 8);
            tmp.bin = byte_buf.pop_front();
            decodeBin_queue.push_back(tmp);
        end

        //Model decodeBin
        while(decodeBin_queue.size() > 0) begin
            @(posedge clk);
            #0.1;
            decBin_rdy[core_id] = $random;
            if (decBin_get) begin
                tmp = decodeBin_queue.pop_front();
                if (decBin_ctx == tmp.ctx) begin
                    latency = ($random & 32'h7fffffff) % 3;
                    for (int i = 0; i <= latency; i++)
                        @(posedge clk);
                    decBin_vld[core_id] = 1;
                    decBin_bin[core_id] = tmp.bin;
                    @(posedge clk);
                    decBin_vld[core_id] = 0;
                    decBin_bin[core_id] = 0;
                end
                else begin
                    $display("ERROR: decBin ctx is not matched, ctx=%0d expected=%0d\n", decBin_ctx, tmp.ctx);
                    #10 $stop;
                end
            end
        end
    end
endtask
