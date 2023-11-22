`timescale 1ns / 1ps
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter IDLE = 2'd0,
   	parameter INPUT_DATA = 2'd1,
   	parameter END = 2'd2
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
begin

    // write your code here!
    
    reg [3:0] 				state;
   	reg [3:0]				next_state;
   	reg				 		ap_start;
   	reg						ap_idle;
   	reg						ap_done;
   	reg [(pDATA_WIDTH-1):0] data_length;
   	reg [9:0]				data_counter;
   	reg [4:0]				fir_counter;
   	reg [(pDATA_WIDTH-1):0] data_temp_1;
   	reg [(pDATA_WIDTH-1):0] data_temp_2;
   	reg read;
	reg rvalid_r;
	


    reg [(pDATA_WIDTH-1):0] rdata_r; 
    

    
    reg [(pDATA_WIDTH-1):0] fir_data;
    
    wire arvalid_w;
    wire rready_w;
    
   	
   	assign awready = (state == IDLE) ? 1 : 0;
   	assign wready = (state == IDLE) ? 1 : 0;
   	assign arready = (araddr <= 32'hFF && arvalid) ? 1 : 0;
   	assign rvalid = rvalid_r;
   	assign rdata = rdata_r;
   	
    assign tap_WE = (state == IDLE) ? (	(awvalid && wvalid) ? 4'b1111 : 4'b0000	) : 4'b0000;			  
    assign tap_EN = (state == IDLE || state == INPUT_DATA) ? 1 : 0;
    assign tap_Di = wdata;
    assign tap_A = (state == IDLE) ? (	(awvalid && wvalid) ? (awaddr-12'h20) : (araddr-12'h20)	) :
    								 (	(data_counter <= 10'd10) ? {6'b0,4*(data_counter[3:0]-fir_counter[3:0])} : {6'b0,4*(fir_counter[4:1])}	);
   	

    
    assign data_WE = ((data_counter <= 10'd10 && fir_counter == data_counter[4:0]) || (data_counter > 10'd10 && fir_counter[0] == 1'd1)) ? 4'b1111 : 4'b0000;
    assign data_EN = 1;
    assign data_Di = (data_counter <= 10'd10) ? ss_tdata : data_temp_1;
    assign data_A = (data_counter <= 10'd10) ? {6'b0,4*fir_counter} : {6'b0,4*(4'd10-fir_counter[4:1])};
    
    
    
    assign ss_tready = (state == INPUT_DATA && ((data_counter <= 10'd10 && fir_counter == data_counter[4:0]) || (data_counter > 10'd10 && fir_counter == 5'd0))) ? 1 : 0;
    assign sm_tvalid = (state == INPUT_DATA && (fir_counter == 0)) ? 1 : 0; 
    assign sm_tdata = fir_data;
    assign sm_tlast = (state == INPUT_DATA && data_counter == 10'd600 && fir_counter == 5'd1) ? 1 : 
    				  (state == END															) ? 1 :
    				  																			0 ;
    				  																			
   	assign arvalid_w = arvalid; 
    assign rready_w = rready;
    
    
  	always@(*) begin
		if(araddr==12'h00)
			rdata_r = {{{29'b0,ap_idle},ap_done},ap_start};
		else if(araddr==12'h10)
			rdata_r = data_length;
		else if(araddr>=12'h20)
			rdata_r = tap_Do;
		else
			rdata_r = 0;	
	end
	
    ////////////////////////////////////	FSM	   ///////////////////////////////
   
	
   
   	
	always@(*)begin
		case(state)
			IDLE : begin
				ap_idle = 1;
				ap_start = 0;
				ap_done = 0;
				next_state = (awaddr == 12'h00 && wdata == 32'h0000_0001 && ap_idle) ? INPUT_DATA : IDLE;
			end
			INPUT_DATA : begin
				ap_idle = sm_tlast;
				ap_start = (data_counter == 10'd0 && fir_counter == 5'd0) ? 1 : 0;
				ap_done = (sm_tlast) ? 1 : 0;
				next_state = (sm_tlast) ? END : INPUT_DATA;
			end
			END : begin
				ap_idle = sm_tlast;
				ap_start = 0;
				ap_done = 1;
				next_state = END;
			end
			default : begin
				ap_idle = 0;
				ap_start = 0;
				ap_done = 0;
				next_state = IDLE;
			end
   		endcase
    end
   
    

   
   	always@(posedge axis_clk or negedge axis_rst_n)begin
   		if(!axis_rst_n)begin
   			state <= IDLE;
   			data_length <= 0;
   			data_counter <= 0;
   			fir_counter <= 0;
   			fir_data <= 0; 
   			data_temp_1 <= 0;
   			data_temp_2 <= 0;
   			read <= 0;
			rvalid_r <= 0;
   		end
   		else begin
   			state <= next_state;
   			data_length <= (awaddr==12'h10 && awvalid && awready) ? wdata : data_length;
   			data_counter <= (state==INPUT_DATA && ((fir_counter == 5'd21 && data_counter > 10'd10) || (ss_tready && data_counter <= 10'd10)) ) ? data_counter+1 : data_counter;
   			fir_counter <= (state==INPUT_DATA && (data_counter <= 10'd10 && fir_counter != data_counter) || (data_counter > 10'd10 && fir_counter != 5'd21)) ? fir_counter+1 : 0;
   			data_temp_1 <= (fir_counter == 0 ) ? ss_tdata :
   						   (fir_counter[0] == 1'b1) ? data_Do : 
   						  							  data_temp_1;
   						  							  
   			if(data_counter <= 10'd10) begin
   				if(data_counter <= 10'd1 && fir_counter == 0)begin
   					fir_data <= data_Do*tap_Do;
   				end
   				else if(data_counter > 10'd1 && fir_counter == 1)begin
   					fir_data <= data_Do*tap_Do;
   				end
   				else begin
   					fir_data <= fir_data+data_Do*tap_Do;
   				end
   			end
   			else if(data_counter > 10'd10) begin
   				if(fir_counter == 5'd1) begin
   					fir_data <= data_temp_1*tap_Do;
   				end
   				else if(fir_counter[0] == 1'b0)begin
   					fir_data <= fir_data+data_temp_2;
   				end
   				else begin
   					fir_data <= fir_data;
   				end
   			end
   			else begin
   				fir_data <= fir_data;
   			end
   			
   			data_temp_2 <= (fir_counter[0] == 1'b1) ? data_temp_1*tap_Do : data_temp_2;

   			read <= (state == END && arvalid_w && rready_w && araddr == 12'h00) ? 1 : read;
   			
   			rvalid_r <= (rvalid_r) ? 0 : rready_w;
   		end
   	end
end



endmodule
