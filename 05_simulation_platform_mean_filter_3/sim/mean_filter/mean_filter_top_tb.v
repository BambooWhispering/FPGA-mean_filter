/*
均值滤波顶层 测试模块
*/
module mean_filter_top_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 一维求和前的信号
	reg							mf_din_vsync		;	// 输入数据场同步信号
	reg							mf_din_hsync		;	// 输入数据行同步信号
	reg			[ 7:0]			mf_din				;	// 输入数据（与 输入数据行同步信号 同步）
	
	// 一维求和后的信号
	wire						mf_dout_vsync		;	// 输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	wire						mf_dout_hsync		;	// 输出数据行同步信号
	wire		[ 7:0]			mf_dout				; 	// 输出数据（与 输出数据行同步信号 同步）
	// ------
	
	
	// ---实例化测试模块---
	mean_filter_top #(
		// 核参数
		.KSZ				('d3			),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
		
		// 视频数据流参数
		.DW					('d8			),	// 输入数据位宽
		.IW					('d4			),	// 输入图像宽（image width）
		.IH					('d4			),	// 输入图像高（image height）
		
		// 行参数（多少个时钟周期）
		.H_TOTAL			('d10			),	// 行总时间
		// 场参数（多少个时钟周期，注意这里不是多少行！！！）
		.V_FRONT_CLK		('d2			),	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
		
		// 单时钟FIFO（用于行缓存）参数
		.FIFO_DEPTH			('d1024			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
		.FIFO_DEPTH_DW		('d10			),	// SCFIFO 深度位宽
		.DEVICE_FAMILY		("Stratix III"	),	// SCFIFO 支持的设备系列
		
		// 参数选择
		.IS_BOUND_ADD		(1'b0			)	// 是否要进行边界补充（1——补充边界；0——忽略边界）
		)
	mean_filter_top_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 均值滤波前的信号
		.mf_din_vsync		(mf_din_vsync	),	// 输入数据场有效信号
		.mf_din_hsync		(mf_din_hsync	),	// 输入数据行有效信号
		.mf_din				(mf_din			),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 均值滤波后的信号
		.mf_dout_vsync		(mf_dout_vsync	),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
		.mf_dout_hsync		(mf_dout_hsync	),	// 输出数据行有效信号
		.mf_dout			(mf_dout		)	 	// 输出数据（与 输出数据行有效信号 同步）
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
		mf_din_vsync	= 1'b0;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
	end
	endtask
	// ------
	
	
	// ---激励信号 产生---
	initial
	begin
		task_sysinit;
		task_reset;
		
		#(T_CLK*1);
		mf_din_vsync	= 1'b1;
		
		#(T_CLK*8);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd2;
		#T_CLK;
		mf_din			= 'd8;
		#T_CLK;
		mf_din			= 'd3;
		#T_CLK;
		mf_din			= 'd1;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*6);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd5;
		#T_CLK;
		mf_din			= 'd3;
		#T_CLK;
		mf_din			= 'd6;
		#T_CLK;
		mf_din			= 'd2;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*6);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd7;
		#T_CLK;
		mf_din			= 'd6;
		#T_CLK;
		mf_din			= 'd8;
		#T_CLK;
		mf_din			= 'd4;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*6);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd9;
		#T_CLK;
		mf_din			= 'd4;
		#T_CLK;
		mf_din			= 'd7;
		#T_CLK;
		mf_din			= 'd9;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*2);
		mf_din_vsync	= 1'b0;
		
		
		#(T_CLK*50);
		#(T_CLK*1);
		mf_din_vsync	= 1'b1;
		
		#(T_CLK*8);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd2;
		#T_CLK;
		mf_din			= 'd8;
		#T_CLK;
		mf_din			= 'd3;
		#T_CLK;
		mf_din			= 'd1;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*6);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd5;
		#T_CLK;
		mf_din			= 'd3;
		#T_CLK;
		mf_din			= 'd6;
		#T_CLK;
		mf_din			= 'd2;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*6);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd7;
		#T_CLK;
		mf_din			= 'd6;
		#T_CLK;
		mf_din			= 'd8;
		#T_CLK;
		mf_din			= 'd4;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*6);
		mf_din_hsync	= 1'b1;
		mf_din			= 'd9;
		#T_CLK;
		mf_din			= 'd4;
		#T_CLK;
		mf_din			= 'd7;
		#T_CLK;
		mf_din			= 'd9;
		
		#T_CLK;
		mf_din_hsync	= 1'b0;
		mf_din			= 1'b0;
		
		#(T_CLK*2);
		mf_din_vsync	= 1'b0;
		
		#(T_CLK*50);
		
		$stop;
	end
	// ------
	
	
endmodule
