`timescale 1ns / 1ps
//not relation solution
/*
    first:
        Cache-->(valid & op)
    then:
        when:
            rready
            valid
*/

//define 
    //state machine
    //parameter           AXI_IDLE      = 2'b00  ;
    //parameter           AXI_RREADY    = 2'b01  ;
    //parameter           AXI_RVALID    = 2'b11  ;

    //parameter           AXI_AWREADY   = 2'b01  ;
    //parameter           AXI_WREADY    = 2'b11  ;
    //parameter           AXI_WVALID    = 2'b10  ;

    //parameter           32'b00000000_00000000_00000000_00000000      = 32'b00000000_00000000_00000000_00000000;
  
module simple_axi(
    input               clk          ,   
    input               resetn       ,  //low active
    input               flush        ,  //todo
    input  [ 5:0]       stall        ,  //todo
    //cache to axi
    input                    rd_req_i     ,
    input       [ 2:0]       rd_type_i    ,
    input       [31:0]       rd_addr_i    ,
    output                   rd_rdy_o     ,//
    output                   ret_valid_o  ,
    output                   ret_last_o   ,//
    output      [31:0]       ret_data_o   ,
    
    input                    wr_req_i     ,
    input       [ 2:0]       wr_type_i    ,
    input       [31:0]       wr_addr_i    ,
    input       [ 3:0]       wr_wstrb_i   ,
    input       [127:0]      wr_data_i    ,
    output                   wr_rdy_o     ,
    output                   wr_resp_o    ,
    
    //output      [127:0]      oops_data_o  ,
    //output                   oops_valid   ,

    //read request channel
    output      [ 3:0]       arid         ,  //todo
    output      [31:0]       araddr       ,
    output      [ 7:0]       arlen        ,  
    output      [ 2:0]       arsize       ,  //connect rd_type
    output      [ 1:0]       arburst      ,  
    output      [ 1:0]       arlock       ,  //todo

    output      [ 3:0]       arcache      ,  //todo
    output      [ 2:0]       arprot       ,  //todo
        //read request signal
    output                   arvalid      ,
    input                    arready      ,

    //read response channel
    input       [ 3:0]       rid          , //todo
    input       [ 1:0]       rresp        , //todo
    input                    rlast        , //HIGH ENABLE
    input       [31:0]       rdata        ,
        //read response signal
    input                    rvalid       ,
    output                   rready       ,

    //write request channel
    output      [ 3:0]       awid         ,
    output      [31:0]       awaddr       ,
    output      [ 7:0]       awlen        ,  
    output      [ 2:0]       awsize       ,  //connect wr_type
    output      [ 1:0]       awburst      ,  
    output      [ 1:0]       awlock       ,  //todo
    output      [ 3:0]       awcache      ,  //todo:Cache type:bufferable? cacheable? write-through/back?etc
    output      [ 2:0]       awprot       ,  //todo
        //write request signal
    output                   awvalid      ,
    output                   awready      ,  //default high

    //write data channel
    output      [ 3:0]       wid          ,  //todo
    output      [31:0]       wdata        ,  
    output      [ 3:0]       wstrb        ,  
    output                   wlast        ,  
        //write data signal
    output                   wvalid       ,  
    input                    wready       ,

    //write response channel
    input       [ 3:0]       bid          ,  //todo
    input       [ 1:0]       bresp        ,  //todo
        //write response signal
    input                    bvalid       ,  //can default high
    output                   bready      
);
    
    
    //parameter DLY = 0.1;
    //cache write buffer
    reg    [ 2:0]       cache_write_cnt        ;
    reg    [127:0]      cache_write_buffer     ;
    //wire                oops                   ;

    //state machine
    reg    [ 1:0]       read_state             ;
    reg    [ 1:0]       write_state            ; 

    wire   [ 1:0]       next_read_state        ;
    wire   [ 1:0]       next_write_state       ;

    /*************state switch*************/

    always @ (posedge clk) begin
        if (~resetn | flush) begin
            read_state  <= 2'b00;
            write_state <= 2'b00;
        end else begin
            read_state  <= next_read_state  ;
            write_state <= next_write_state ; 
        end    
    end  
    
    /*************read part*************/
    assign  arburst         = 2'b01                                                                                             ;//defuat
    assign  next_read_state = (resetn & ~flush) ? ((read_state == 2'b00) ? (( arvalid & arready ) ? 2'b01 : 2'b00) //!!!7.12
                                       : ((read_state == 2'b01) ? (( rlast  ) ? 2'b00 : 2'b01) : 2'b00)) 
                                       : 2'b00                                                                                  ;  

    assign  araddr          = resetn & ~flush && rd_req_i && read_state == 2'b00 ? rd_addr_i : 32'b00000000_00000000_00000000_00000000   ;
    assign  arsize          = resetn & ~flush && rd_req_i && read_state == 2'b00 && rd_type_i == 3'b100 ? 3'b010 : 3'b000                ;
    assign  arlen           = resetn & ~flush && rd_req_i && read_state == 2'b00 && rd_type_i == 3'b100 ? 8'b00000011 : 8'b00000000      ;
    assign  arvalid         = resetn & ~flush && rd_req_i && read_state == 2'b00                                                         ;//!can be better//!7.12
    assign  rready          = resetn & ~flush && read_state == 2'b01                                                                     ; 
 
    assign  ret_data_o      = ((resetn & ~flush) && (read_state == 2'b01)) ? rdata  : 32'b00000000_00000000_00000000_00000000; 
    assign  ret_valid_o     = ((resetn & ~flush) && (read_state == 2'b01)) ? rvalid : 1'b0                                   ;
    assign  ret_last_o      = ((resetn & ~flush) && (read_state == 2'b01)) ? rlast  : 1'b0                                   ;
    
    assign  rd_rdy_o        = ((resetn & ~flush) && (read_state == 2'b00))                                                   ;

    /*************write part*************/

    assign  wr_rdy_o            = resetn & ~flush && write_state == 2'b00                        ;//busy

    //assign  cache_write_buffer  = resetn & ~flush ? (awvalid && awready && wr_req_i ? wr_data_i : cache_write_buffer ) 
    //                                     : 128'h00000000_00000000_00000000_00000000     ;
    
    always @(posedge clk) begin
        if (~resetn )begin
            cache_write_buffer  <= 128'h00000000_00000000_00000000_00000000     ;
        end
        else
        if (awvalid && awready && wr_req_i) begin
            cache_write_buffer  <= wr_data_i                                    ;
        end
        else                                begin
            
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (~resetn | flush) begin
            cache_write_cnt <= 3'b000                       ;
        end
        else
        if ( wr_req_i && write_state == 2'b00) begin
            if (wr_type_i == 3'b100) begin
                cache_write_cnt <= 3'b100                   ;
            end
            else begin
                cache_write_cnt <= 3'b001                   ;                
            end
        end
        else
        if (~wr_req_i && write_state == 2'b01) begin
            if (cache_write_cnt == 3'b000) begin
                cache_write_cnt <= 3'b000                   ;
            end
            else begin
                cache_write_cnt <= cache_write_cnt - 3'b001 ; 
            end
        end
        else
            cache_write_cnt <= cache_write_cnt              ;
    end

    assign  next_write_state = (resetn & ~flush) ? ((write_state == 2'b00 ) ? ((awvalid & awready  ) ? 2'b01 : 2'b00  )            //one clk//!!!7.12
                                        : ((write_state == 2'b01 ) ? ((wlast    ) ? 2'b11 : 2'b01  )
                                        : ((write_state == 2'b11 ) ? ((bvalid   ) ? 2'b00 : 2'b11  ) : 2'b00)))
                                        : 2'b00 ;

    assign  awburst          = 2'b01                                                                                                        ;//defuat
    assign  awaddr           = resetn & ~flush ? (wr_req_i && write_state == 2'b00                        ? wr_addr_i  : 32'h00000000)
                                      : 32'h00000000                                                                                        ;                                                                                                           
    
    assign  awsize           = resetn & ~flush && wr_req_i && write_state == 2'b00 && wr_type_i == 3'b100 ? 3'b010      : 3'b000                     ;
    assign  awlen            = resetn & ~flush && wr_req_i && write_state == 2'b00 && wr_type_i == 3'b100 ? 8'b00000011 : 8'b00000000                ;
    //assign  awlen            = 8'b00000000                                                                                                  ;
    assign  awvalid          = resetn & ~flush && wr_req_i && write_state == 2'b00                                                                   ;
   
    assign  wvalid           = resetn & ~flush &&             write_state == 2'b01                                                                   ;
    assign  wlast            = resetn & ~flush &&             write_state == 2'b01 && cache_write_cnt == 3'b001                                      ;
    assign  wstrb            = resetn & ~flush && wr_req_i && write_state == 2'b00                        ? wr_wstrb_i  : 4'b1111                    ;
 
    assign  wdata            = resetn & ~flush && wready   && write_state == 2'b01                        ? ((cache_write_cnt == 3'b100) ? cache_write_buffer[ 31: 0]
                                                                                                 : ((cache_write_cnt == 3'b011) ? cache_write_buffer[ 63:32]
                                                                                                 : ((cache_write_cnt == 3'b010) ? cache_write_buffer[ 95:64]
                                                                                                 : ((cache_write_cnt == 3'b001) ? cache_write_buffer[127:96] 
                                                                                                 : 32'b00000000_00000000_00000000_00000000)))) 
                                                                                                 : 32'b00000000_00000000_00000000_00000000  ; 

    assign  bready           = resetn & ~flush            && write_state == 2'b11                                                                   ;
    assign  wr_resp_o        = resetn & ~flush            && bvalid                                                                                 ;

    /*************solution*************/

    //assign  oops             = rd_req_i && rd_addr_i == awaddr                                                                              ;
    //assign  oops_data_o      = cache_write_buffer                                                                                           ;
    //assign  oops_valid       = oops     && resetn & ~flush                                                                                          ;

    //todo tmp
    assign  arid             = 4'b0000                  ;
    
    assign  arlock           = 2'b00                    ;
    assign  arcache          = 4'b0000                  ;
    assign  arprot           = 3'b000                   ;

    assign  awid             = 4'b0000                  ;
    
    
    assign  awlock           = 2'b00                    ;
    assign  awcache          = 4'b0000                  ;
    assign  awprot           = 3'b000                   ;

    assign  wid              = 4'b0000                  ;
    //assign  wstrb            = 4'b0000                  ;
    
                                                                                    
endmodule