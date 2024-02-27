module GPIO(
    input                  pclk,
    input                  preset_n, //Active Low Reset

    input                  psel_i,
    input                  penable_i,
    input        [3:0]     paddr_i,
    input                  pwrite_i, // 1-> writing to slave 0 -> reading from slave
    input        [7:0]     pwdata_i,
    output reg   [7:0]     prdata_o, //data read from slave
    output                 pready_o, //from slave    
    input        [7:0]     gpio_i,
    output reg   [7:0]     gpio_o,
    output reg   [7:0]     gpio_oe 
);

localparam  DIRECTION = 0,
            OUTPUT    = 1,
            INPUT     = 2;

//Control Registers
logic [7:0] dir_reg, // 0 -> Input , 1-> Output
            out_reg,
            in_reg;

assign pready_o = 1'b1; //always ready

/* APB Writes */
//APB write to Direction register
  always @(posedge pclk,negedge preset_n)
  if(psel_i & penable_i & pwrite_i) begin
    if (paddr_i == DIRECTION) begin
        if(!preset_n)
            dir_reg <= {8{1'b0}};
        else 
            dir_reg <= pwdata_i;
    end    
    if(paddr_i == OUTPUT) begin
        if(!preset_n) 
            out_reg <= {8{1'b0}};
        else 
            out_reg <= pwdata_i; 
    end
  end
/*
    APB Reads
   */
  always @(posedge pclk)
  if(psel_i & penable_i)begin
    case (paddr_i)
      DIRECTION: prdata_o <= dir_reg;
      OUTPUT   : prdata_o <= out_reg;
      INPUT    : prdata_o <= in_reg;
      default  : prdata_o <= {8{1'b0}};
    endcase
  end

 always @(posedge pclk)
    in_reg <= gpio_i;

//drive out_reg value onto transmitter input
  always @(posedge pclk)
  if (gpio_oe) begin
    for (int n=0; n<8; n++)
      gpio_o[n] <= out_reg[n];
  end  

    always @(posedge pclk)
    for (int n=0; n<8; n++)
      gpio_oe[n] <= dir_reg[n];            

endmodule



module apb_GPIO_master(
    input               pclk,
    input               preset_n, //Active Low Reset

    input        [1:0]  ctrl_i, // 2'b00 - NOP, 2'b01 - READ, 2'b11 - WRITE (bit 0 decides there is an operation ,bit 1 decides whether read or write)

    output              psel_o,
    output              penable_o,
    input reg    [3:0]  paddr_tb,
    output       [3:0]  paddr_o,
    output              pwrite_o, // 1-> writing to slave 0 -> reading from slave
    output       [7:0]  pwdata_o,
    input reg    [7:0]  prdata_i, //data read from slave
    input               pready_i //from slave      
);

   
//Standard apb protocol states
localparam IDLE     = 2'b00;
localparam SETUP    = 2'b01;
localparam ACCESS   = 2'b11;

wire apb_state_setup;
wire apb_state_access;

reg next_pwrite;
reg pwrite_q;
reg [7:0] next_rdata;
reg [7:0] rdata_q;

reg [1:0] state_q, next_state;

always @(posedge pclk or negedge preset_n)
    if(~preset_n)
        state_q <= IDLE;
    else
        state_q <= next_state;

always @(*) begin
    /Data stable/
    next_pwrite = pwrite_q; //only change pwrite when we are in IDLE state
    next_rdata = rdata_q; //ensure it remains in its previous value
    case (state_q)
    /IDLE STATE/
    IDLE:
        if(ctrl_i[0]) begin //if the zero bit is set we have an operation
            next_state = SETUP; //go to setup state
            next_pwrite = ctrl_i[1]; // 0-> read , 1 -> write 
        end else begin
            next_state = IDLE; //if no operation remain in IDLE
	end	  
    /SETUP STATE/
    SETUP: next_state = ACCESS; //protocol mandates after one cycle from setup -> ACCESS
    /ACCESS STATE/
    ACCESS:
        if(pready_i) begin //wait for pready signal
            if(~pwrite_q) //if equal zero whatever value is present on read data we should capture this read data
               next_rdata = prdata_i;// next read data you got when you are issuing a read transaction and pready is set (capture read data and store it in next read data)
            next_state = IDLE; // when we get a pready we move to IDLE state
        end else    
            next_state = ACCESS;  // if you get no pready signal continue to remain in access state      
    default: next_state = IDLE;
    endcase
end

assign apb_state_access = (state_q == ACCESS); //is one whenever we are in access state
assign apb_state_setup = (state_q == SETUP);   //is one whenever we are in setup state

assign psel_o = apb_state_setup | apb_state_access;   //psel is asserted as soon as we enter the setup state but setup is only for 1 clock cycle and psel need to continue be high
assign penable_o = apb_state_access;  //Psel one cycle after penable

// APB Address
assign paddr_o =  paddr_tb; //stable address doesnt change when we are in access state else its zero

//APB Pwrite control signal
always@(posedge pclk or negedge preset_n)
    if(~preset_n)
        pwrite_q <= 1'b0;
    else
        pwrite_q <= next_pwrite; 

assign pwrite_o = pwrite_q;


assign pwdata_o = 8'b10101010 ;
 // assign pwdata_o =  rdata_q ;//take flopped value whenever we are on access state and make operations on it 

//We use this read value when we are doing a write transaction
always @(posedge pclk or negedge preset_n) 
    if(~preset_n)
        rdata_q <= 8'h0;
     else
        rdata_q <= next_rdata;
endmodule
