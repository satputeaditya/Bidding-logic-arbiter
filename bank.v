//======================================================================
//
// bank.v
// ---------
//
//======================================================================

module bank (   
			// General signals
				input 				clk,
				input 				rst,
			// Slave banking signals				
                input 		[3:0] 	bid,
                input 				granted,
                output reg 	[9:0] 	balance
            );

  //--------------------------
  // Register declarations.
  //--------------------------
  reg [9:0] banker; 

  //--------------------------
  // banking_logic
  //
  // logic for banking system
  //--------------------------
  always@(negedge clk, posedge rst)
    begin : banking_logic    
        if (rst)
            begin
                balance = 750;  
                banker <= 'b0;                
            end
        else
            begin
                banker <= (banker == 400) ? 'b0 : (banker +1);           	// free running banker resets automatically  every 400 banks  
                if (banker == 400) 
					balance = (balance > 150) ? 900 : (balance + 750);       // saturating counter adds leftover balance 
                else
                    if (granted)    if (balance <= 0) balance = 1; 
									else balance = (balance == 1)? 1: (((balance - bid) == 0) ?  1 : (balance - bid));      // reduces bid amount to maintain bank balance 
                    else balance = balance;          
            end
	end // banking_logic

endmodule // bank
 
//======================================================================
// EOF bank.v
//======================================================================
