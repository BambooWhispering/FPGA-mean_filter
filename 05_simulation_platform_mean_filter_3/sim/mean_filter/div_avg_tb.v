/*
除法求平均值 测试模块
*/
module div_avg_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 除法求平均值前的信号
	reg							din_vsync			;	// 输入数据场同步信号
	reg							din_hsync			;	// 输入数据行同步信号
	reg			[15:0]			din					;	// 输入数据（与 输入数据行同步信号 同步）
	
	// 除法求平均值后的信号
	wire						dout_vsync			;	// 输出数据场同步信号
	wire						dout_hsync			;	// 输出数据行同步信号
	wire		[ 7:0]			dout				; 	// 输出数据（与 输出数据行同步信号 同步）
	// ------
	
	
	// ---实例化测试模块---
	div_avg #(
		// 核参数
		.KSZ					('d3			),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
		
		// 视频数据流参数
		.DW						('d8			)	// 输出数据位宽
		)
	div_avg_u0(
		// 系统信号
		.clk					(clk			),	// 时钟（clock）
		.rst_n					(rst_n			),	// 复位（reset）
		
		// 二维求和后的信号
		.din_vsync				(din_vsync		),	// 输入数据场有效信号
		.din_hsync				(din_hsync		),	// 输入数据行有效信号
		.din					(din			),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 求平均值后的信号
		.dout_vsync				(dout_vsync		),	// 输出数据场有效信号
		.dout_hsync				(dout_hsync		),	// 输出数据行有效信号
		.dout					(dout			) 	// 输出数据（与 输出数据行有效信号 同步）
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
		
		#(T_CLK*6);
		din_hsync	= 1'b1;
		din			= 'd10;
		#T_CLK;
		din			= 'd28;
		#T_CLK;
		din			= 'd37;
		#T_CLK;
		din			= 'd410;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		#(T_CLK*4);
		din_hsync	= 1'b1;
		din			= 'd46;
		#T_CLK;
		din			= 'd255;
		#T_CLK;
		din			= 'd630;
		#T_CLK;
		din			= 'd323;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		#(T_CLK*2);
		din_vsync	= 1'b0;
		
		
		#(T_CLK*20);
		
		$stop;
	end
	// ------
	
	
endmodule
