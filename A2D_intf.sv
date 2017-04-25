module A2D_intf(clk,rst_n,strt_cnv,cnv_cmplt,chnnl,res,a2d_SS_n,SCLK,MOSI,MISO);

  input clk,rst_n;			// 50MHz clock and active low asynch reset
  input strt_cnv;			// initiates an A2D conversion
  input [2:0] chnnl;		// channel to perform conversion on
  input MISO;				// Serial input from A2D (Master In Slave Out)
  output [11:0] res;		// result of A2D conversion
  output cnv_cmplt;			// indicates full round robin conversions is complete
  output a2d_SS_n;			// active low SPI slave select to A2D
  output SCLK,MOSI;			// SPI master signals
  
  wire [15:0] rd_data;		// data read from SPI interface.  Lower 12-bits form res (result of A2D conv)
  wire [15:0] cmd;

  assign cmd = {2'b00,chnnl,11'h000};		// command to A2D is simply address of channel to convert

  ///////////////////////////////////////////////
  // Instantiate SPI master for A2D interface //
  /////////////////////////////////////////////
  SPI_mstr iSPI(.clk(clk),.rst_n(rst_n),.SS_n(a2d_SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.wrt(strt_cnv),
                  .done(cnv_cmplt),.rd_data(rd_data),.cmd(cmd));
  
  assign res = ~rd_data[11:0];		// Give 1's complement as reading (invert for light line on dark background)
  
endmodule
  