/*
二维求和：
求一个正方形核的所有数据的和
*/
module sum_2domensional(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 二维求和前的信号
	din_vsync			,	// 输入数据场有效信号
	din_hsync			,	// 输入数据行有效信号
	din					,	// 输入数据（与 输入数据行有效信号 同步）
	
	// 二维求和后的信号
	dout_vsync			,	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	dout_hsync			,	// 输出数据行有效信号
	dout				 	// 输出数据（与 输出数据行有效信号 同步）
	);
	
	
	// *******************************************参数声明***************************************
	// 核参数
	parameter	KSZ				=	'd3				;	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
	
	// 视频数据流参数
	parameter	DW				=	'd8				;	// 输入数据位宽
	parameter	IW				=	'd640			;	// 输入图像宽（image width）
	
	// 行参数（多少个时钟周期）
	parameter	H_TOTAL			=	'd1440			;	// 行总时间
	
	// 要删除的时钟周期数
	// 因为起码要等流过 KSZ-1 行，即 第 KSZ 行时才能进行二维求和，所以场有效信号输出会比场有效信号输入少 KSZ-1 行 高电平
	parameter	DELETE_CLK		=	H_TOTAL*(KSZ-1)	;	// 场有效信号要删除的时钟周期计数
	
	// 单时钟FIFO（用于行缓存）参数
	parameter	FIFO_DW			=	2*DW			;	// SCFIFO 数据位宽
	parameter	FIFO_DEPTH		=	'd1024			;	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
	parameter	FIFO_DEPTH_DW	=	'd10			;	// SCFIFO 深度位宽
	parameter	DEVICE_FAMILY	=	"Stratix III"	;	// SCFIFO 支持的设备系列
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input						clk						;	// 时钟（clock）
	input						rst_n					;	// 复位（reset）
	
	// 二维求和前的信号
	input						din_vsync				;	// 输入数据场有效信号
	input						din_hsync				;	// 输入数据行有效信号
	input		[DW-1:0]		din						;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 二维求和后的信号
	output						dout_vsync				;	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	output						dout_hsync				;	// 输出数据行有效信号
	output		[2*DW-1:0]		dout					; 	// 输出数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 行（一维）求和 信号
	wire						frame_valid				;	// （核左对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	wire						row_valid				;	// （核左对齐首数据）输出数据行同步信号
	wire	[2*DW-1:0]			sum_row					;	// （核左对齐首数据）行求和输出数据（与 输出数据行同步信号 同步）
	
	// for循环计数
	integer						j						;
	
	// 行（一维）求和 信号 打拍
	reg		[ 3:0]				frame_valid_r_arr		;	// （核左对齐首数据）行求和输出数据场有效标志 打1~4拍
	reg		[ 3:0]				row_valid_r_arr			;	// （核左对齐首数据）行求和输出数据行有效标志 打1~4拍
	reg		[2*DW-1:0]			sum_row_r_arr[0:3]		;	// （核左对齐首数据）行求和输出数据 打1~4拍
	
	
	// 行（一维）求和 信号 边沿检测
	wire						frame_valid_pos			;	// （核左对齐首数据）行求和输出数据场有效标志 上升沿
	wire						row_valid_pos			;	// （核左对齐首数据）行求和输出数据行有效标志 上升沿
	
	// 行求和缓存（SCFIFO） 信号
	wire	[KSZ-2:0]			line_wr_en				;	// FIFO写使能（KSZ-1个）
	wire	[FIFO_DW-1:0]		line_wr_data[0:KSZ-2]	;	// FIFO写数据（与 写使能 同步）（KSZ-1个）
	wire	[KSZ-2:0]			line_rd_en				;	// FIFO读使能（KSZ-1个）
	wire	[FIFO_DW-1:0]		line_rd_data[0:KSZ-2]	;	// FIFO读数据（比 读使能 滞后1拍）（KSZ-1个）
	wire	[FIFO_DEPTH_DW-1:0]	line_usedw[0:KSZ-2]		;	// FIFO中现有的数据个数
	
	// 行求和缓存（SCFIFO） 信号 打拍
	reg		[KSZ-2:0]			line_rd_en_r0			;	// FIFO读使能（KSZ-1个） 打1拍
	
	// SCFIFO 辅助信号
	reg		[KSZ-2:0]			line_wr_done			;	// 一行图像核行之和写进FIFO完成标志（KSZ-1个）（写完后就一直为1）
	
	// 列求和 流水线 信号
	reg		[2*DW-1:0]			temp_sum0				;
	reg		[2*DW-1:0]			temp_sum1				;
	reg		[2*DW-1:0]			temp_sum2				;
	reg		[2*DW-1:0]			temp_sum3				;
	reg		[2*DW-1:0]			temp_sum4				;
	reg		[2*DW-1:0]			all_sum					;	//	最终列求和结果
	
	// 输出初步处理信号
	wire						dout_vsync_nd			;	// 未删除 KSZ-1 行的场有效信号输出
	
	// 计数
	reg		[KSZ-1:0]			cnt_row					;	// 一帧中当前正在流过的图像行数计数
	reg		[31:0]				cnt_v_ht_clk			;	// 场扫描时的行总时间的像素时钟计数
	// *******************************************************************************************
	
	
	// 实例化 行求和（一维求和）模块
	// 求一个正方形核的一行数据的和
	sum_1donmensional #(
		.DW					(DW			),	// 数据位宽
		.KSZ				(KSZ		)	// 核尺寸（正方形核的边长）（kernel size）
		)
	sum_1donmensional_u0(
		// 系统信号
		.clk				(clk		),	// 时钟（clock）
		.rst_n				(rst_n		),	// 复位（reset）
		
		// 一维求和前的信号
		.din_vsync			(din_vsync	),	// 输入数据场同步信号
		.din_hsync			(din_hsync	),	// 输入数据行同步信号
		.din				(din		),	// 输入数据（与 输入数据行同步信号 同步）
		
		// 一维求和后的信号
		.dout_right_vsync	(			),	// （核右对齐首数据）输出数据场同步信号
		.dout_right_hsync	(			),	// （核右对齐首数据）输出数据行同步信号
		.dout_right			(			), 	// （核右对齐首数据）输出数据（与 输出数据行同步信号 同步）
		.dout_left_vsync	(frame_valid),	// （核左对齐首数据）输出数据场同步信号（左对齐）
		.dout_left_hsync	(row_valid	),	// （核左对齐首数据）输出数据行同步信号
		.dout_left			(sum_row	)	// （核左对齐首数据）输出数据（与 输出数据行同步信号 同步）
		);
	
	
	// 一维求和后的信号 打拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			frame_valid_r_arr <= 1'b0;
			row_valid_r_arr <= 1'b0;
			for(j=0; j<=3; j=j+1)
				sum_row_r_arr[j] <= 1'b0;
		end
		else
		begin
			frame_valid_r_arr <= {frame_valid_r_arr[2:0], frame_valid};
			row_valid_r_arr <= {row_valid_r_arr[2:0], row_valid};
			sum_row_r_arr[0] <= sum_row;
			for(j=1; j<=3; j=j+1)
				sum_row_r_arr[j] <= sum_row_r_arr[j-1];
		end
	end
	
	
	// 一维求和后的场有效信号 上升沿
	assign	frame_valid_pos	=	~frame_valid_r_arr[0] & frame_valid	;	// 01
	
	
	// 一维求和后的行有效信号 上升沿
	assign	row_valid_pos	=	~row_valid_r_arr[0] & row_valid		;	// 01
	
	
	// 实例化 KSZ-1个 行求和缓存（SCFIFO）模块
	// 二维求和 其实就是将核中的各行之和 累加起来，需要累加KSZ行，所以加上当前行，还需要缓存KSZ-1行
	// （因为要对同一个模块实例化多次，故使用“generate”）
	generate
	begin: line_buffer_inst
		
		genvar	i; // generate中的for循环计数
		
		for(i=0; i<KSZ-1; i=i+1) // 实例化 KSZ-1个 行求和缓存
		begin: line_buf
			
			// 实例化 KSZ-1个 行求和缓存（单时钟FIFO）
			// 每个FIFO中存放一行 核在一行图像上依次移动的核行之和，共有 KSZ-1个 FIFO
			 my_scfifo #(
				// 自定义参数
				.FIFO_DW			(FIFO_DW		),	// 数据位宽
				.FIFO_DEPTH			(FIFO_DEPTH		),	// 深度（最多可存放的数据个数）
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW	),	// 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY	)	// 支持的设备系列
				)
			my_scfifo_linebuffer(
				// 系统信号
				.clock				(clk			),	// 时钟
				.aclr				(~rst_n	| frame_valid_pos),	// 复位
				
				// 写信号
				.wrreq				(line_wr_en[i]	),	// FIFO写使能
				.data				(line_wr_data[i]),	// FIFO写数据（与 写使能 同步）
				
				// 读信号
				.rdreq				(line_rd_en[i]	),	// FIFO读使能
				.q					(line_rd_data[i]),	// FIFO读数据（比 读使能 滞后1拍）
				
				// 状态信号
				.empty				(				),	// FIFO已空
				.full				(				),	// FIFO已满
				.usedw				(line_usedw[i]	)	// FIFO中现有的数据个数
				);
			
			// 核在一行图像上依次移动的核行之和 写入 FIFO
			if(i == 0) // 图像第0行的核行之和 写入
			begin
				assign	line_wr_en[i]	=	row_valid_r_arr[0]	;	// 第0行的写使能 其实就是 当前行求和的输出有效标志打1拍
				assign	line_wr_data[i]	=	sum_row_r_arr[0]	;	// 第0行的写数据 其实就是 当前行求和的输出结果打1拍
			end
			else // 图像第 1 ~ KSZ-2 行的核行之和 写入
			begin
				assign	line_wr_en[i]	=	line_rd_en_r0[i-1]	;	// 第i行的写使能 其实就是 第i-1行的读使能打1拍
				assign	line_wr_data[i]	=	line_rd_data[i-1]	;	// 第i行的写数据 其实就是 第i-1行的读数据
			end
			
			// 第0~KSZ-2行的读使能 打拍
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					line_rd_en_r0[i] <= 1'b0;
				else
					line_rd_en_r0[i] <= line_rd_en[i];
			end
			
			// 核在一行图像上依次移动的核行之和 写完 图像的第0~KSZ-2行
			// 需要写满图像的一行核行之和，因为采用的是 核左对齐首数据，
			// 图示如下（核尺寸KSZ = 3）：
			// din_valid	:		_|- - - -|_
			// din			:	      1 2 3 4
			// 核（*表示）	:		  * * *
			//					        * * *
			// dout_left_valid	:	    _ _|- -|_
			// dout_left		:		    6 9
			// 所以，写满一行所需个数是 IW-(KSZ-1)
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					line_wr_done[i] <= 1'b0;
				else if(frame_valid_pos) // 新的一帧到来前，都要重新归位
					line_wr_done <= 1'b0;
				else if(line_usedw[i] == IW-KSZ) // IW-(KSZ-1'b1)-1'b1
					line_wr_done[i] <= 1'b1;
			end
			
			// 核在一行图像上依次移动的核行之和 从FIFO中 读出
			assign	line_rd_en[i]	=	line_wr_done[i]	& row_valid	;	// 第i行的读使能 其实就是 第i行写完后的行有效期间
			
		end // for循环结束
		
	end	
	endgenerate
	
	
	// 列方向求和
	generate
	begin
		if(KSZ == 3) // 核边长为3时
		begin: sum_ksz_3
			// 第一级流水线：核的相邻两行的行和相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					temp_sum0 <= 1'b0;
				else if(row_valid_r_arr[0])
					temp_sum0 <= line_rd_data[0] + line_rd_data[1];
				else
					temp_sum0 <= 1'b0;
			end
			// 第二级流水线：第一级流水线相邻结果相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					all_sum <= 1'b0;
				else if(row_valid_r_arr[1])
					all_sum <= temp_sum0 + sum_row_r_arr[1];
				else
					all_sum <= 1'b0;
			end
		end
		
		else if(KSZ == 5) // 核边长为5时
		begin: sum_ksz_5
			// 第一级流水线：核的相邻两行的行和相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					temp_sum0 <= 1'b0;
					temp_sum1 <= 1'b0;
				end
				else if(row_valid_r_arr[0])
				begin
					temp_sum0 <= line_rd_data[0] + line_rd_data[1];
					temp_sum1 <= line_rd_data[2] + line_rd_data[3];
				end
			end
			// 第二级流水线：第一级流水线相邻结果相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					temp_sum2 <= 1'b0;
				else if(row_valid_r_arr[1])
					temp_sum2 <= temp_sum0 + temp_sum1;
			end
			// 第三级流水线：第二级流水线相邻结果相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					all_sum <= 1'b0;
				else if(row_valid_r_arr[2])
					all_sum <= temp_sum2 + sum_row_r_arr[2];
			end
		end
		
		else if(KSZ == 7) // 核边长为7时
		begin: sum_ksz_7
			// 第一级流水线：核的相邻两行的行和相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					temp_sum0 <= 1'b0;
					temp_sum1 <= 1'b0;
					temp_sum2 <= 1'b0;
				end
				else if(row_valid_r_arr[0])
				begin
					temp_sum0 <= line_rd_data[0] + line_rd_data[1];
					temp_sum1 <= line_rd_data[2] + line_rd_data[3];
					temp_sum2 <= line_rd_data[4] + line_rd_data[5];
				end
			end
			// 第二级流水线：第一级流水线相邻结果相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					temp_sum3 <= 1'b0;
					temp_sum4 <= 1'b0;
				end
				else if(row_valid_r_arr[1])
				begin
					temp_sum3 <= temp_sum0 + temp_sum1;
					temp_sum4 <= temp_sum2 + sum_row_r_arr[1];
				end
			end
			// 第三级流水线：第二级流水线相邻结果相加
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					all_sum <= 1'b0;
				else if(row_valid_r_arr[2])
					all_sum <= temp_sum3 + temp_sum4;
			end
		end
		
	end
	endgenerate
	
	
	// 一帧中当前正在流过的图像行数计数
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_row <= 1'b0;
		else if(frame_valid_pos) // 一帧开始时，重新开始计数一帧中当前正在流过的图像行数
			cnt_row <= 1'b0;
		else if(row_valid_pos) // 每来新的一行，计数+1
			cnt_row <= (cnt_row>=KSZ) ? KSZ : (cnt_row+1'b1);
	end
	
	
	// 二维求和后的行同步信号
	// 只有到列求和流水线的最后一级，且一帧中当前正在流过的图像行计数为核边长行时，此时才能得到二维求和后的行有效信号
	generate
	begin
		
		if(KSZ == 3) // 核边长为3时
		begin: hsync_ksz_3
			assign	dout_hsync	=	row_valid_r_arr[2] & cnt_row==KSZ	;	// 因为all_sum是在row_valid_r1的下一拍即row_valid_r2得到的
		end
		
		else if(KSZ == 5) // 核边长为5时
		begin: hsync_ksz_5
			assign	dout_hsync	=	row_valid_r_arr[3] & cnt_row==KSZ	;	// 因为all_sum是在row_valid_r2的下一拍即row_valid_r3得到的
		end
		
		else if(KSZ == 7) // 核边长为7时
		begin: hsync_ksz_7
			assign	dout_hsync	=	row_valid_r_arr[3] & cnt_row==KSZ	;	// 因为all_sum是在row_valid_r2的下一拍即row_valid_r3得到的
		end
		
	end
	endgenerate
	
	
	// 二维求和后的未删除 KSZ-1 行的场有效信号输出
	// 需与 dout_hsync 打的拍数一致
	generate
	begin
		
		if(KSZ == 3) // 核边长为3时
		begin: hsync_ksz_3
			assign	dout_vsync_nd	=	frame_valid_r_arr[2]	;
		end
		
		else if(KSZ == 5) // 核边长为5时
		begin: hsync_ksz_5
			assign	dout_vsync_nd	=	frame_valid_r_arr[3]	;
		end
		
		else if(KSZ == 7) // 核边长为7时
		begin: hsync_ksz_7
			assign	dout_vsync_nd	=	frame_valid_r_arr[3]	;
		end
		
	end
	endgenerate
	
	
	// 二维求和后的数据输出
	assign	dout	=	dout_hsync ? all_sum : 1'b0	;
	
	
	// 场扫描时的行总时间的像素时钟计数（要删除的时钟周期计数）（要将场有效信号输出拉低 KSZ-1 行 ）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_v_ht_clk <= 1'b0;
		else if(dout_vsync_nd) // 场有效期间，开始计数，计满要删除的时钟周期数为止，保持
			cnt_v_ht_clk <= (cnt_v_ht_clk>=DELETE_CLK) ? DELETE_CLK : cnt_v_ht_clk+1'b1;
		else
			cnt_v_ht_clk <= 1'b0;
	end
	
	
	// 二维求和后的场同步信号（左右对齐）
	assign	dout_vsync	=	(cnt_v_ht_clk==DELETE_CLK) ? dout_vsync_nd : 1'b0	;	// 删除 KSZ-1 行
	
	
endmodule
