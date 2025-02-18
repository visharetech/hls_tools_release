`timescale 1ns / 1ps
`define capture(a) 				begin $write(`"a=%d,\t`", a); end 
`define capture1(a) 			begin `capture(a) $display(""); end
`define capture2(a,b) 			begin `capture(a) `capture(b) $display(""); end
`define capture3(a,b,c) 		begin  `capture(a) `capture(b) `capture(c) $display(""); end
`define capture4(a,b,c,d) 		begin `capture(a) `capture(b) `capture(c) `capture(d) $display(""); end
`define capture5(a,b,c,d,e) 	begin `capture(a) `capture(b) `capture(c) `capture(d) `capture(e) $display(""); end
`define capture6(a,b,c,d,e,f) 	begin `capture(a) `capture(b) `capture(c) `capture(d) `capture(e) `capture(f) $display(""); end

`define combStr(a)				begin if(~clk) $display(`"a`"); end
`define combWrite(a)			begin if(~clk) $write(`"a: `"); end
`define combCap(a) 				$write(`"a=%d, `", a); 
`define combCap1(a) 			if(clk==0) begin `combCap(a) $display(""); 		end
`define combCap2(a,b) 			if(clk==0) begin `combCap(a) `combCap(b) $display(""); 			end
`define combCap3(a,b,c) 		if(clk==0) begin `combCap(a) `combCap(b) `combCap(c) $display(""); end
`define combCap4(a,b,c,d) 		if(clk==0) begin `combCap(a) `combCap(b) `combCap(c) `combCap(d) $display(""); end
`define combCap5(a,b,c,d,e) 	if(clk==0) begin `combCap(a) `combCap(b) `combCap(c) `combCap(d) `combCap(e) $display(""); end
`define combCap6(a,b,c,d,e,f) 	if(clk==0) begin `combCap(a) `combCap(b) `combCap(c) `combCap(d) `combCap(e) `combCap(f) $display(""); end
