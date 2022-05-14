/*
一维求和 测试模块
*/
module sum_1donmensional_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 一维求和前的信号
	reg							din_vsync			;	// 输入数据场同步信号
	reg							din_hsync			;	// 输入数据行同步信号
	reg			[ 7:0]			din					;	// 输入数据（与 输入数据行同步信号 同步）
	
	// 一维求和后的信号
	wire						dout_right_vsync	;	// （核右对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	wire						dout_right_hsync	;	// （核右对齐首数据）输出数据行同步信号
	wire		[15:0]			dout_right			; 	// （核右对齐首数据）输出数据（与 输出数据行同步信号 同步）
	wire						dout_left_vsync		;	// （核左对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	wire						dout_left_hsync		;	// （核左对齐首数据）输出数据行同步信号
	wire		[15:0]			dout_left			; 	// （核左对齐首数据）输出数据（与 输出数据行同步信号 同步）
	// ------
	
	
	// ---实例化测试模块---
	sum_1donmensional #(
		.KSZ				('d3				),	// 核尺寸（正方形核的边长）（kernel size）
		.DW					('d8				)	// 数据位宽
		)
	sum_1donmensional_u0(
		// 系统信号
		.clk				(clk				),	// 时钟（clock）
		.rst_n				(rst_n				),	// 复位（reset）
		
		// 一维求和前的信号
		.din_vsync			(din_vsync			),	// 输入数据场同步信号
		.din_hsync			(din_hsync			),	// 输入数据行同步信号
		.din				(din				),	// 输入数据（与 输入数据行同步信号 同步）
		
		// 一维求和后的信号
		.dout_right_vsync	(dout_right_vsync	),	// （核右对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
		.dout_right_hsync	(dout_right_hsync	),	// （核右对齐首数据）输出数据行同步信号
		.dout_right			(dout_right			), 	// （核右对齐首数据）输出数据（与 输出数据行同步信号 同步）
		.dout_left_vsync	(dout_left_vsync	),	// （核左对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
		.dout_left_hsync	(dout_left_hsync	),	// （核左对齐首数据）输出数据行同步信号
		.dout_left			(dout_left			)	// （核左对齐首数据）输出数据（与 输出数据行同步信号 同步）
		);
	// ------
	
	
	// ---系统时钟信号 产生---
	localparam T_CLK = 20; // 系统时钟（100MHz）周期：20ns
	initial
		clk = 1'b1;
	always #(T_CLK/2)
		clk = ~clk;
	// ------
	
	
	// ---复位任务---
	task task_reset;
	begin
		rst_n = 1'b0;
		repeat(10) @(negedge clk)
			rst_n = 1'b1;
	end
	endtask
	// ------
	
	
	// ---系统初始化 任务---
	task task_sysinit;
	begin
		din_vsync	= 1'b0;
		din_hsync	= 1'b0;
		din			= 1'b0;
	end
	endtask
	// ------
	
	
	// ---激励信号 产生---
	initial
	begin
		task_sysinit;
		task_reset;
		
		#(T_CLK*1);
		din_vsync	= 1'b1;
		
		#(T_CLK*8);
		din_hsync	= 1'b1;
		din			= 'd20;
		#T_CLK;
		din			= 'd18;
		#T_CLK;
		din			= 'd32;
		#T_CLK;
		din			= 'd11;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		#(T_CLK*5);
		din_hsync	= 1'b1;
		din			= 'd51;
		#T_CLK;
		din			= 'd33;
		#T_CLK;
		din			= 'd67;
		#T_CLK;
		din			= 'd2;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		#(T_CLK*3);
		din_vsync	= 1'b0;
		
		
		#(T_CLK*30);
		din_vsync	= 1'b1;
		
		#(T_CLK*8);
		din_hsync	= 1'b1;
		din			= 'd20;
		#T_CLK;
		din			= 'd18;
		#T_CLK;
		din			= 'd32;
		#T_CLK;
		din			= 'd11;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*5);
		din_hsync	= 1'b1;
		din			= 'd51;
		#T_CLK;
		din			= 'd33;
		#T_CLK;
		din			= 'd67;
		#T_CLK;
		din			= 'd2;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		$stop;
	end
	// ------
	
	
endmodule
