//======================================================================
//
// bidding_aribter.v
// ---------
//
//======================================================================

module bidding_aribter (
						input  			clk,
						input  			rst,					
						input  [3:0] 	bid_0,
						input  [3:0] 	bid_1,
						input  [3:0] 	bid_2,
						input  [3:0] 	bid_3,                    
						output [3:0] 	grant
					);

  //----------------------------------------------------------------
  // Register declarations.
  //----------------------------------------------------------------
  wire [9:0] balance 				[3:0];
  reg  [5:0] count_since_last_grant0 ;
  reg  [5:0] count_since_last_grant1 ;
  reg  [5:0] count_since_last_grant2 ;
  reg  [5:0] count_since_last_grant3 ;  
  reg  [3:0] result;
  reg  [3:0] valid_balance;
  reg  [3:0] highest_bid;
  reg  [3:0] highest_bid_1;
  reg  [3:0] last_granted;
  reg  [3:0] equal_bid;

  //----------------------------------------------------------------
  // Output port signal assignments.
  //----------------------------------------------------------------

  assign grant  = result;                // final 

  //---------------------------------------------
  // Internal constant and parameter definitions.
  //---------------------------------------------
  parameter Slave0 = 4'b0001;
  parameter Slave1 = 4'b0010;
  parameter Slave2 = 4'b0100;
  parameter Slave3 = 4'b1000;
  parameter None   = 4'b0000;
  parameter service_threshold_count = 'b100000;
  				
  //---------------------------------------------------------------------------
  // Core_arbitration_logic
  // 
  // core logic is asynchronous as arbitration is required from cycle to cycle
  //---------------------------------------------------------------------------
  always@(*) 
    begin : Core_arbitration_logic
		highest_bid 	= 'b0;				// to avoid latches
		result			= 'b0;				// to avoid latches
		
        if (rst)							// active high asynch
            begin
                highest_bid 	= 'b0;		// 4 bit vector
				highest_bid_1	= 'b0;		// 4 bit vector
                valid_balance   = 'b0;		// 4 bit vector
            end
        else
            begin      
					valid_balance[0] = ( balance[0] >= bid_0 ) ? 'b1 : 'b0;   
					valid_balance[1] = ( balance[1] >= bid_1 ) ? 'b1 : 'b0;   
					valid_balance[2] = ( balance[2] >= bid_2 ) ? 'b1 : 'b0;   
					valid_balance[3] = ( balance[3] >= bid_3 ) ? 'b1 : 'b0;   
							
					highest (bid_0,bid_1,bid_2,bid_3,valid_balance,highest_bid_1);									// determine highest bid with valid balance 

  //  PRIORITY 1 : check if all bids are 0  
					if (bid_0 == 0 && bid_1 == 0 && bid_2 == 0 && bid_3  == 0 ) begin highest_bid = 4'd0; $display("TP1"); end			 
  //  PRIORITY 2 : check if all but one slave bids 0, grant even if balance is 0
					else if (bid_0 !==0 && bid_1  ==0 && bid_2  ==0 && bid_3  ==0 && valid_balance[0] == 0) begin highest_bid = Slave0; $display("TP2"); end	// If all others bid 0 and Slave0 bids with 0 balance, then grant to Slave 0
					else if (bid_0  ==0 && bid_1 !==0 && bid_2  ==0 && bid_3  ==0 && valid_balance[1] == 0) begin highest_bid = Slave1; $display("TP3"); end	// If all others bid 0 and Slave1 bids with 0 balance, then grant to Slave 1
					else if (bid_0  ==0 && bid_1  ==0 && bid_2 !==0 && bid_3  ==0 && valid_balance[2] == 0) begin highest_bid = Slave2; $display("TP4"); end	// If all others bid 0 and Slave2 bids with 0 balance, then grant to Slave 2
					else if (bid_0  ==0 && bid_1  ==0 && bid_2  ==0 && bid_3 !==0 && valid_balance[3] == 0) begin highest_bid = Slave3; $display("TP5"); end	// If all others bid 0 and Slave3 bids with 0 balance, then grant to Slave 3
  //  PRIORITY 3 : check if a particular slave has not been serviced beyond service_threshold_count and grant access if requested
 					else if ((count_since_last_grant0 >= service_threshold_count) || 
							 (count_since_last_grant1 >= service_threshold_count) || 
							 (count_since_last_grant2 >= service_threshold_count) || 
							 (count_since_last_grant3 >= service_threshold_count))
							 begin
								highest (count_since_last_grant0,count_since_last_grant1,count_since_last_grant2,count_since_last_grant3,valid_balance,highest_bid);									
							end 
  //  PRIORITY 4 : check if NO 1 highest bid exists, then check for equal bids and resolve using last_granted AND/OR count_since_last_grant
					else if (highest_bid_1 == 0) 
							begin 
								equal (bid_0,bid_1,bid_2,bid_3,valid_balance,equal_bid);  // calculate which slaves have equal bids
								$display("TP8"); 
										highest_bid  = 	(( (equal_bid[0]==1) && (last_granted ==! Slave0) ? Slave0 : 
														 ( (equal_bid[1]==1) && (last_granted ==! Slave1) ? Slave1 : 
														 ( (equal_bid[2]==1) && (last_granted ==! Slave2) ? Slave2 : 
														 ( (equal_bid[3]==1) && (last_granted ==! Slave3) ? Slave3 : None))))) ;  
							end
  //  PRIORITY 5 : check for highest bid only
					else 
						begin
							highest_bid = highest_bid_1; 
							result 		= highest_bid;
						end
			end			
	end //  Core_arbitration_logic
		
  //---------------------------------------------------------------------------
  // last_granted_counter
  //
  // process to determine clocks since last serviced counter to decide priority
  //---------------------------------------------------------------------------
  always@(negedge clk or posedge rst)
    begin : last_granted_counter
        if (rst)
            begin
				count_since_last_grant0 <= 'b0;    
				count_since_last_grant1 <= 'b0;    
				count_since_last_grant2 <= 'b0;    
				count_since_last_grant3 <= 'b0;   
				last_granted 			<= 'b0; 				
            end
        else
            begin
				count_since_last_grant0 <= ((result[0]) | (bid_0 == 'b0)) ? 'b0 : (count_since_last_grant0 +1);           // start counter to count cycles since last grant , count even if no bid by master 
				count_since_last_grant1 <= ((result[1]) | (bid_1 == 'b0)) ? 'b0 : (count_since_last_grant1 +1);           // start counter to count cycles since last grant , count even if no bid by master 
				count_since_last_grant2 <= ((result[2]) | (bid_2 == 'b0)) ? 'b0 : (count_since_last_grant2 +1);           // start counter to count cycles since last grant , count even if no bid by master 
				count_since_last_grant3 <= ((result[3]) | (bid_3 == 'b0)) ? 'b0 : (count_since_last_grant3 +1);           // start counter to count cycles since last grant , count even if no bid by master 
				last_granted 			<= highest_bid;                                        							 	  // flopping to store which master was last granted                     				
            end
	end // last_granted_counter	

  //--------------------------------------------------
  // comparision_highest
  //
  // task to determine highest bid with valid balance 
  //--------------------------------------------------
  task highest;
	input  [3:0] bid_0;
	input  [3:0] bid_1;
	input  [3:0] bid_2;
	input  [3:0] bid_3;
	input  [3:0] valid_balance;					
	output [3:0] highest_bid;
			begin : comparision_highest				
				reg [3:0] bid_reg_0;
				reg [3:0] bid_reg_1;
				reg [3:0] bid_reg_2;
				reg [3:0] bid_reg_3;	
					
				bid_reg_0 =  bid_0;
				bid_reg_1 =  bid_1;
				bid_reg_2 =  bid_2;
				bid_reg_3 =  bid_3;		
						
				if (valid_balance[0]) if ((bid_reg_0 > bid_reg_1) && (bid_reg_0 > bid_reg_2 ) && (bid_reg_0 > bid_reg_3))  highest_bid[0] = 'b1; else highest_bid[0] = 'b0; else begin bid_reg_0 = 0; highest_bid[0] = 'b0; end
				if (valid_balance[1]) if ((bid_reg_1 > bid_reg_0) && (bid_reg_1 > bid_reg_2 ) && (bid_reg_1 > bid_reg_3))  highest_bid[1] = 'b1; else highest_bid[1] = 'b0; else begin bid_reg_1 = 0; highest_bid[1] = 'b0; end
				if (valid_balance[2]) if ((bid_reg_2 > bid_reg_0) && (bid_reg_2 > bid_reg_1 ) && (bid_reg_2 > bid_reg_3))  highest_bid[2] = 'b1; else highest_bid[2] = 'b0; else begin bid_reg_2 = 0; highest_bid[2] = 'b0; end
				if (valid_balance[3]) if ((bid_reg_3 > bid_reg_0) && (bid_reg_3 > bid_reg_1 ) && (bid_reg_3 > bid_reg_2))  highest_bid[3] = 'b1; else highest_bid[3] = 'b0; else begin bid_reg_3 = 0; highest_bid[3] = 'b0; end
			end 
  endtask // comparision_highest
  
  //--------------------------------------------------
  // comparision_equal
  //
  // task to determine equal bids with valid balance
  //--------------------------------------------------
  task equal;
	input  [3:0] bid_0;
	input  [3:0] bid_1;
	input  [3:0] bid_2;
	input  [3:0] bid_3;  
	input  [3:0] valid_balance;					
	output [3:0] equal_bid;
			begin //: comparision_equal	
						equal_bid[0] = ((valid_balance[0]) && ((bid_0 == bid_1) | (bid_0 == bid_2) | (bid_0 == bid_3) )) ? 'b1 : 'b0;
						equal_bid[1] = ((valid_balance[1]) && ((bid_1 == bid_0) | (bid_1 == bid_2) | (bid_1 == bid_3) )) ? 'b1 : 'b0;
						equal_bid[2] = ((valid_balance[2]) && ((bid_2 == bid_0) | (bid_2 == bid_1) | (bid_2 == bid_3) )) ? 'b1 : 'b0;
						equal_bid[3] = ((valid_balance[3]) && ((bid_3 == bid_0) | (bid_3 == bid_1) | (bid_3 == bid_2) )) ? 'b1 : 'b0;						
			end 
  endtask // comparision_equal
  
  bank Slave_0 ( clk, rst, bid_0, grant[0], balance[0]); 
  bank Slave_1 ( clk, rst, bid_1, grant[1], balance[1]); 
  bank Slave_2 ( clk, rst, bid_2, grant[2], balance[2]); 
  bank Slave_3 ( clk, rst, bid_3, grant[3], balance[3]); 

endmodule // bidding_aribter
  
//======================================================================
// EOF bidding_aribter.v
//======================================================================
