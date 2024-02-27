module apb_slave_tb();
    reg             pclk;
    reg             preset_n; //Active low reset

    reg   [1:0]     ctrl_i; // 2'b00 - NOP, 2'b01 - READ, 2'b11 - WRITE - drive apb output signals

    wire            psel_o;
    wire            penable_o;
    reg  [3:0]      paddr_tb;
    wire            pwrite_o;
    wire  [7:0]     pwdata_o;

    reg   [7:0]     prdata_i;
    wire            pready_i ;//from slave   

    reg   [7:0]     gpio_i;
    reg   [7:0]     gpio_o;
    reg   [7:0]     gpio_oe;  


    // CLock Implementation
    always begin
        pclk = 1'b0;
        #5;
        pclk = 1'b1;
        #5;
    end

    //Instantiate
    apb_GPIO_master APB_MASTER(
        .pclk(pclk),
        .preset_n(preset_n),
        .ctrl_i(ctrl_i),
        .psel_o(psel_o),
        .penable_o(penable_o),
        .paddr_tb(paddr_tb),
        .pwrite_o(pwrite_o),
        .pwdata_o(pwdata_o),
        .prdata_i(prdata_i),
        .pready_i(pready_i)
    );
    GPIO gpio(
    .pclk(pclk),
    .preset_n(preset_n),
    .psel_i(psel_o),
    .penable_i(penable_o),
    .paddr_i(paddr_tb),
    .pwrite_i(pwrite_o),
    .pwdata_i(pwdata_o),
    .prdata_o(prdata_i),
    .pready_o(pready_i),
    .gpio_i(gpio_i),
    .gpio_o(gpio_o),
    .gpio_oe(gpio_oe)
);
    
    initial begin
        gpio_i = 8'b11111110;
        preset_n = 1'b0;
        ctrl_i = 2'b00; //nop
        repeat (2) `CLK;
        preset_n = 1'b1; 
        repeat (2) `CLK;
//===========Test(1)=============================================================================
    //Read transaction
    paddr_tb = 4'b0010;
    ctrl_i = 2'b01; //read
    `CLK;
    ctrl_i = 2'b00;
    repeat (4) `CLK;
//===========Test(2)=============================================================================
    // Write transaction
    paddr_tb = 4'b0000;
    ctrl_i = 2'b11;  
    `CLK;
    ctrl_i = 2'b00;
    repeat (4) `CLK;
      
    // Write transaction
    paddr_tb = 4'b0001;
    ctrl_i = 2'b11;  
    `CLK;
    ctrl_i = 2'b00;
    repeat (4) `CLK;
    
	$finish();
end


    //dump 
    initial begin
        $dumpfile("abp_master.vcd");
        $dumpvars(2,apb_slave_tb);
    end

endmodule
