/*
均值滤波顶层模块：
使用正方形核，以核中数据的均值作为新值，进行均值滤波。
eg（核边长为3）：
原图：		  1 2 1 2
			  3 3 5 7
			  4 3 2 8
			  3 5 6 9
边界补充后：1 1 2 1 2 2
			1 1 2 1 2 2
			3 3 3 5 7 7
			4 4 3 2 8 8
			3 3 5 6 9 9
			3 3 5 6 9 9
滤波后：	  1 2 2 3
			  2 2 3 4
			  3 3 5 6
			  3 4 5 7
不进行边界补充滤波后：
				2 3
				3 5
*/
module mean_filter_top(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 均值滤波前的信号
	mf_din_vsync		,	// 输入数据场有效信号
	mf_din_hsync		,	// 输入数据行有效信号
	mf_din				,	// 输入数据（与 输入数据行有效信号 同步）
	
	// 均值滤波后的信号
	mf_dout_vsync		,	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	mf_dout_hsync		,	// 输出数据行有效信号
	mf_dout				 	// 输出数据（与 输出数据行有效信号 同步）
	);
	
	
	// *******************************************参数声明***************************************
	// 核参数
	parameter	KSZ				=	'd3				;	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
	
	// 视频数据流参数
	parameter	DW				=	'd8				;	// 输入数据位宽
	parameter	IW				=	'd640			;	// 输入图像宽（image width）
	parameter	IH				=	'd480			;	// 输入图像高（image height）
	
	// 行参数（多少个时钟周期）
	parameter	H_TOTAL			=	'd1440			;	// 行总时间
	// 场参数（多少个时钟周期，注意这里不是多少行！！！）
	parameter	V_FRONT_CLK		=	'd28800			;	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
	
	// 单时钟FIFO（用于行缓存）参数
	parameter	FIFO_DEPTH		=	'd1024			;	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
	parameter	FIFO_DEPTH_DW	=	'd10			;	// SCFIFO 深度位宽
	parameter	DEVICE_FAMILY	=	"Stratix III"	;	// SCFIFO 支持的设备系列
	
	// 参数选择
	parameter	IS_BOUND_ADD	=	1'b1			;	// 是否要进行边界补充（1——补充边界；0——忽略边界）
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input						clk					;	// 时钟（clock）
	input						rst_n				;	// 复位（reset）
	
	// 均值滤波前的信号
	input						mf_din_vsync		;	// 输入数据场有效信号
	input						mf_din_hsync		;	// 输入数据行有效信号
	input		[DW-1:0]		mf_din				;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 均值滤波后的信号
	output						mf_dout_vsync		;	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	output						mf_dout_hsync		;	// 输出数据行有效信号
	output		[DW-1:0]		mf_dout				; 	// 输出数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 二维求和前的信号
	wire						sum_2_din_vsync		;	// 二维求和前 输入数据场有效标志（左右对齐，即场后肩、场前肩不变）
	wire						sum_2_din_hsync		;	// 二维求和前 输入数据行有效标志
	wire		[DW-1:0]		sum_2_din			; 	// 二维求和前 输入数据（与 输出数据有效标志 同步）
	
	// 二维求和后的信号
	wire						sum_2_dout_vsync	;	// 二维求和后 输出数据场有效标志（左右对齐，即场后肩、场前肩不变）
	wire						sum_2_dout_hsync	;	// 二维求和后 输出数据行有效标志
	wire		[2*DW-1:0]		sum_2_dout			; 	// 二维求和后 输出数据（与 输出数据有效标志 同步）
	// *******************************************************************************************
	
	
	// 根据参数决定是否需要补充边界
	generate
	begin
		
		if(IS_BOUND_ADD) // 补充边界
		begin: bound_add
			
			// 实例化 上下左右边界补充模块
			// 通过复制边界的像素点，
			// 在图像的上下边界各添加 (正方形核边长-1)/2 行像素点，
			// 在图像的左右边界各添加 (正方形核边长-1)/2 个像素点
			bound_add_top #(
				// 核参数
				.KSZ				(KSZ					),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
				
				// 视频数据流参数
				.DW					(DW						),	// 输入数据位宽
				.IW					(IW						),	// 输入图像宽（image width）
				.IH					(IH						),	// 输入图像高（image height）
				
				// 行参数（多少个时钟周期）
				.H_TOTAL			(H_TOTAL				),	// 行总时间
				// 场参数（多少个时钟周期，注意这里不是多少行！！！）
				.V_FRONT_CLK		(V_FRONT_CLK			),	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
				
				// 单时钟FIFO（用于行缓存）参数
				.FIFO_DEPTH			(FIFO_DEPTH				),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW			),	// SCFIFO 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY			)	// SCFIFO 支持的设备系列
				)
			bound_add_top_u0(
				// 系统信号
				.clk				(clk					),	// 时钟（clock）
				.rst_n				(rst_n					),	// 复位（reset）
				
				// 输入信号
				.din_vsync			(mf_din_vsync			),	// 输入数据场有效信号
				.din_hsync			(mf_din_hsync			),	// 输入数据行有效信号
				.din				(mf_din					),	// 输入数据（与 输入数据行有效信号 同步）
				
				// 输出信号
				.dout_vsync			(sum_2_din_vsync		),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
				.dout_hsync			(sum_2_din_hsync		),	// 输出数据行有效信号（左对齐，即在行有效期右边扩充列）
				.dout				(sum_2_din				) 	// 输出数据（与 输出数据行有效信号 同步）
				);
			
			// 实例化 二维求和模块
			// 求一个正方形核的所有数据的和
			sum_2domensional #(
				// 核参数
				.KSZ				(KSZ				),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
				
				// 视频数据流参数
				.DW					(DW					),	// 输入数据位宽
				.IW					(IW+KSZ-1'b1		),	// 输入图像宽（image width）（多了KSZ-1行）
				
				// 行参数（多少个时钟周期）
				.H_TOTAL			(H_TOTAL			),	// 行总时间
				
				// 单时钟FIFO（用于行缓存）参数
				.FIFO_DEPTH			(FIFO_DEPTH			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW		),	// SCFIFO 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY		)	// SCFIFO 支持的设备系列
				)
			sum_2domensional_u0(
				// 系统信号
				.clk				(clk				),	// 时钟（clock）
				.rst_n				(rst_n				),	// 复位（reset）
				
				// 二维求和前的信号
				.din_vsync			(sum_2_din_vsync	),	// 输入数据场有效信号
				.din_hsync			(sum_2_din_hsync	),	// 输入数据行有效信号
				.din				(sum_2_din			),	// 输入数据（与 输入数据行有效信号 同步）
				
				// 二维求和后的信号
				.dout_vsync			(sum_2_dout_vsync	),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
				.dout_hsync			(sum_2_dout_hsync	),	// 输出数据行有效信号
				.dout				(sum_2_dout			) 	// 输出数据（与 输出数据行有效信号 同步）
				);
			
		end
		else // 忽略边界
		begin: bound_ignore
			
			// 不实例化边界补充模块，输入直接连接到二维求和模块
			assign		sum_2_din_vsync		=	 mf_din_vsync	;
			assign		sum_2_din_hsync		=	 mf_din_hsync	;
			assign		sum_2_din			=	 mf_din			;
			
			// 实例化 二维求和模块
			// 求一个正方形核的所有数据的和
			sum_2domensional #(
				// 核参数
				.KSZ				(KSZ				),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
				
				// 视频数据流参数
				.DW					(DW					),	// 输入数据位宽
				.IW					(IW					),	// 输入图像宽（image width）（与输入一致）
				
				// 行参数（多少个时钟周期）
				.H_TOTAL			(H_TOTAL			),	// 行总时间
				
				// 单时钟FIFO（用于行缓存）参数
				.FIFO_DEPTH			(FIFO_DEPTH			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW		),	// SCFIFO 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY		)	// SCFIFO 支持的设备系列
				)
			sum_2domensional_u0(
				// 系统信号
				.clk				(clk				),	// 时钟（clock）
				.rst_n				(rst_n				),	// 复位（reset）
				
				// 二维求和前的信号
				.din_vsync			(sum_2_din_vsync	),	// 输入数据场有效信号
				.din_hsync			(sum_2_din_hsync	),	// 输入数据行有效信号
				.din				(sum_2_din			),	// 输入数据（与 输入数据行有效信号 同步）
				
				// 二维求和后的信号
				.dout_vsync			(sum_2_dout_vsync	),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
				.dout_hsync			(sum_2_dout_hsync	),	// 输出数据行有效信号
				.dout				(sum_2_dout			) 	// 输出数据（与 输出数据行有效信号 同步）
				);
				
		end
	end
	endgenerate
	
	
	// 实例化 除法求平均值模块
	// 输入一个正方形核的所有数据的和，除以正方形核的面积，得到一个正方形核的所有数据的平均值
	div_avg #(
		// 核参数
		.KSZ				(KSZ				),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
		
		// 视频数据流参数
		.DW					(DW					)	// 输出数据位宽
		)
	div_avg_u0(
		// 系统信号
		.clk				(clk				),	// 时钟（clock）
		.rst_n				(rst_n				),	// 复位（reset）
		
		// 二维求和后的信号
		.din_vsync			(sum_2_dout_vsync	),	// 输入数据场有效信号
		.din_hsync			(sum_2_dout_hsync	),	// 输入数据行有效信号
		.din				(sum_2_dout			),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 求平均值后的信号
		.dout_vsync			(mf_dout_vsync		),	// 输出数据场有效信号
		.dout_hsync			(mf_dout_hsync		),	// 输出数据行有效信号
		.dout				(mf_dout			) 	// 输出数据（与 输出数据行有效信号 同步）
		);
	
	
endmodule
