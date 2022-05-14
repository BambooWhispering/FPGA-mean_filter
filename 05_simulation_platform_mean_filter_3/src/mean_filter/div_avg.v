/*
除法求平均值模块：
输入一个正方形核的所有数据的和，除以正方形核的面积，得到一个正方形核的所有数据的平均值
*/
module div_avg(
	// 系统信号
	clk						,	// 时钟（clock）
	rst_n					,	// 复位（reset）
	
	// 二维求和后的信号
	din_vsync				,	// 输入数据场有效信号
	din_hsync				,	// 输入数据行有效信号
	din						,	// 输入数据（与 输入数据行有效信号 同步）
	
	// 求平均值后的信号
	dout_vsync				,	// 输出数据场有效信号
	dout_hsync				,	// 输出数据行有效信号
	dout					 	// 输出数据（与 输出数据行有效信号 同步）
	);
	
	// *******************************************参数声明***************************************
	// 核参数
	parameter	KSZ				=	'd3				;	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
	
	// 视频数据流参数
	parameter	DW				=	'd8				;	// 输出数据位宽
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input						clk						;	// 时钟（clock）
	input						rst_n					;	// 复位（reset）
	
	// 二维求和后的信号
	input						din_vsync				;	// 输入数据场有效信号
	input						din_hsync				;	// 输入数据行有效信号
	input		[2*DW-1:0]		din						;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 求平均值后的信号
	output						dout_vsync				;	// 输出数据场有效信号
	output						dout_hsync				;	// 输出数据行有效信号
	output		[DW-1:0]		dout					; 	// 输出数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// for循环计数
	integer						i						;	// for循环计数值
	
	// 二维求和后的信号 打拍
	reg			[5:0]			din_vsync_r_arr			;	// 输入数据场有效信号 打拍（共6拍）
	reg			[5:0]			din_hsync_r_arr			;	// 输入数据行有效信号 打拍（共6拍）
	
	// 第一级流水线结果
	// 左移
	reg			[3*DW-1:0]		din_l_shift_6			;	// 输入数据左移6位
	reg			[3*DW-1:0]		din_l_shift_5			;	// 输入数据左移5位
	reg			[3*DW-1:0]		din_l_shift_4			;	// 输入数据左移4位
	reg			[3*DW-1:0]		din_l_shift_3			;	// 输入数据左移3位
	reg			[3*DW-1:0]		din_l_shift_2			;	// 输入数据左移2位
	reg			[3*DW-1:0]		din_l_shift_0			;	// 输入数据左移0位
	// 右移
	reg			[3*DW-1:0]		din_r_shift_1			;	// 输入数据右移1位
	reg			[3*DW-1:0]		din_r_shift_2			;	// 输入数据右移2位
	reg			[3*DW-1:0]		din_r_shift_3			;	// 输入数据右移3位
	reg			[3*DW-1:0]		din_r_shift_4			;	// 输入数据右移4位
	reg			[3*DW-1:0]		din_r_shift_6			;	// 输入数据右移6位
	reg			[3*DW-1:0]		din_r_shift_7			;	// 输入数据右移7位
	reg			[3*DW-1:0]		din_r_shift_8			;	// 输入数据右移8位
	
	// 第二级流水线结果
	reg			[3*DW-1:0]		add_ls6_ls5				;	// 输入数据左移6位 与 输入数据左移5位 的和
	reg			[3*DW-1:0]		add_ls5_ls3				;	// 输入数据左移5位 与 输入数据左移3位 的和
	reg			[3*DW-1:0]		add_ls4_ls2				;	// 输入数据左移4位 与 输入数据左移2位 的和
	reg			[3*DW-1:0]		add_ls4_ls0				;	// 输入数据左移4位 与 输入数据左移0位 的和
	reg			[3*DW-1:0]		add_rs1_rs2				;	// 输入数据右移1位 与 输入数据右移2位 的和
	reg			[3*DW-1:0]		add_rs3_rs4				;	// 输入数据右移3位 与 输入数据右移4位 的和
	reg			[3*DW-1:0]		add_rs3_rs6				;	// 输入数据右移3位 与 输入数据右移6位 的和
	reg			[3*DW-1:0]		add_rs6_rs7				;	// 输入数据右移6位 与 输入数据右移7位 的和
	reg			[3*DW-1:0]		add_rs8_0				;	// 输入数据右移8位 与 0 的和
	
	// 其他中间级流水线结果
	reg			[3*DW-1:0]		add_temp1				;	// 上一级流水线相邻数据相加的和1
	reg			[3*DW-1:0]		add_temp2				;	// 上一级流水线相邻数据相加的和2
	reg			[3*DW-1:0]		add_temp3				;	// 上一级流水线相邻数据相加的和3
	reg			[3*DW-1:0]		add_temp4				;	// 上一级流水线相邻数据相加的和4
	reg			[3*DW-1:0]		add_temp5				;	// 上一级流水线相邻数据相加的和5
	
	// 倒数第二级流水线结果
	reg			[3*DW-1:0]		add_result				;	// 上一级流水线相邻数据相加的和
	
	// 倒数第一级流水线结果
	reg			[3*DW-1:0]		r_shift_result			;	// 上一级流水线右移10位
	// *******************************************************************************************
	
	
	// 二维求和后的信号 打拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			for(i=0; i<=5; i=i+1)
			begin
				din_vsync_r_arr[i] <= 1'b0;
				din_hsync_r_arr[i] <= 1'b0;
			end
		end
		else
		begin
			din_vsync_r_arr[0] <= din_vsync;
			din_hsync_r_arr[0] <= din_hsync;
			for(i=1; i<=5; i=i+1)
			begin
				din_vsync_r_arr[i] <= din_vsync_r_arr[i-1];
				din_hsync_r_arr[i] <= din_hsync_r_arr[i-1];
			end
		end
	end
	
	
	// 流水线计算平均值
	generate
	begin
	
		// ---当核尺寸为3时---
		// 平均值 = sum / (3*3) = sum / 9 = sum/(2^10) * ((2^10) / 9) = sum/(2^10) * 113.777778 = sum*(111_0001.1100_0111B)/(2^10)
		//        = (sum<<6 + sum<<5  + sum<<4  + sum<<0  + sum>>1  + sum>>2  + sum>>6  + sum>>7  + sum>>8) >> 10
		if(KSZ == 3)
		begin: div_ksz_3
			// 第一级流水线：移位
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					din_l_shift_6 <= 1'b0;
					din_l_shift_5 <= 1'b0;
					din_l_shift_4 <= 1'b0;
					din_l_shift_0 <= 1'b0;
					din_r_shift_1 <= 1'b0;
					din_r_shift_2 <= 1'b0;
					din_r_shift_6 <= 1'b0;
					din_r_shift_7 <= 1'b0;
					din_r_shift_8 <= 1'b0;
				end
				else if(din_hsync)
				begin
					din_l_shift_6 <= din<<6;
					din_l_shift_5 <= din<<5;
					din_l_shift_4 <= din<<4;
					din_l_shift_0 <= din;
					din_r_shift_1 <= din>>1;
					din_r_shift_2 <= din>>2;
					din_r_shift_6 <= din>>6;
					din_r_shift_7 <= din>>7;
					din_r_shift_8 <= din>>8;
				end
			end
			// 第二级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					add_ls6_ls5 <= 1'b0;
					add_ls4_ls0 <= 1'b0;
					add_rs1_rs2 <= 1'b0;
					add_rs6_rs7 <= 1'b0;
					add_rs8_0 <= 1'b0;
				end
				else if(din_hsync_r_arr[0])
				begin
					add_ls6_ls5 <= din_l_shift_6 + din_l_shift_5;
					add_ls4_ls0 <= din_l_shift_4 + din_l_shift_0;
					add_rs1_rs2 <= din_r_shift_1 + din_r_shift_2;
					add_rs6_rs7 <= din_r_shift_6 + din_r_shift_7;
					add_rs8_0 <= din_r_shift_8;
				end
			end
			// 第三级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					add_temp1 <= 1'b0;
					add_temp2 <= 1'b0;
					add_temp3 <= 1'b0;
				end
				else if(din_hsync_r_arr[1])
				begin
					add_temp1 <= add_ls6_ls5 + add_ls4_ls0;
					add_temp2 <= add_rs1_rs2 + add_rs6_rs7;
					add_temp3 <= add_rs8_0;
				end
			end
			// 第四级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					add_temp4 <= 1'b0;
					add_temp5 <= 1'b0;
				end
				else if(din_hsync_r_arr[2])
				begin
					add_temp4 <= add_temp1 + add_temp2;
					add_temp5 <= add_temp3;
				end
			end
			// 第五级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					add_result <= 1'b0;
				else if(din_hsync_r_arr[3])
					add_result <= add_temp4 + add_temp5;
			end
			// 第六级流水线：右移10位
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					r_shift_result <= 1'b0;
				else if(din_hsync_r_arr[4])
					r_shift_result <= add_result>>10;
			end
			
			// 最终结果输出
			assign	dout_vsync	=	din_vsync_r_arr[5]					;
			assign	dout_hsync	=	din_hsync_r_arr[5]					;
			assign	dout		=	dout_hsync ? r_shift_result	: 1'b0	;
		end
		// ------
		
		// ---当核尺寸为5时---
		// 平均值 = sum / (5*5) = sum / 25 = sum/(2^10) * ((2^10) / 25) = sum/(2^10) * 40.96 = sum*(10_1000.1111_0110B)/(2^10)
		//        = (sum<<5 + sum<<3  + sum>>1  + sum>>2  + sum>>3  + sum>>4  + sum>>6  + sum>>7) >> 10
		else if(KSZ == 5)
		begin: div_ksz_5
			// 第一级流水线：移位
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					din_l_shift_5 <= 1'b0;
					din_l_shift_3 <= 1'b0;
					din_r_shift_1 <= 1'b0;
					din_r_shift_2 <= 1'b0;
					din_r_shift_3 <= 1'b0;
					din_r_shift_4 <= 1'b0;
					din_r_shift_6 <= 1'b0;
					din_r_shift_7 <= 1'b0;
				end
				else if(din_hsync)
				begin
					din_l_shift_5 <= din<<5;
					din_l_shift_3 <= din<<3;
					din_r_shift_1 <= din>>1;
					din_r_shift_2 <= din>>2;
					din_r_shift_3 <= din>>3;
					din_r_shift_4 <= din>>4;
					din_r_shift_6 <= din>>6;
					din_r_shift_7 <= din>>7;
				end
			end
			// 第二级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					add_ls5_ls3 <= 1'b0;
					add_rs1_rs2 <= 1'b0;
					add_rs3_rs4 <= 1'b0;
					add_rs6_rs7 <= 1'b0;
				end
				else if(din_hsync_r_arr[0])
				begin
					add_ls5_ls3 <= din_l_shift_5 + din_l_shift_3;
					add_rs1_rs2 <= din_r_shift_1 + din_r_shift_2;
					add_rs3_rs4 <= din_r_shift_3 + din_r_shift_4;
					add_rs6_rs7 <= din_r_shift_6 + din_r_shift_7;
				end
			end
			// 第三级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					add_temp1 <= 1'b0;
					add_temp2 <= 1'b0;
				end
				else if(din_hsync_r_arr[1])
				begin
					add_temp1 <= add_ls5_ls3 + add_rs1_rs2;
					add_temp2 <= add_rs3_rs4 + add_rs6_rs7;
				end
			end
			// 第四级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					add_result <= 1'b0;
				else if(din_hsync_r_arr[2])
					add_result <= add_temp1 + add_temp2;
			end
			// 第五级流水线：右移10位
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					r_shift_result <= 1'b0;
				else if(din_hsync_r_arr[3])
					r_shift_result <= add_result>>10;
			end
			
			// 最终结果输出
			assign	dout_vsync	=	din_vsync_r_arr[4]					;
			assign	dout_hsync	=	din_hsync_r_arr[4]					;
			assign	dout		=	dout_hsync ? r_shift_result	: 1'b0	;
		end
		// ------
		
		// ---当核尺寸为7时---
		// 平均值 = sum / (7*7) = sum / 49 = sum/(2^10) * ((2^10) / 49) = sum/(2^10) * 20.897959 = sum*(1_0100.1110_0101B)/(2^10)
		//        = (sum<<4 + sum<<2  + sum>>1  + sum>>2  + sum>>3 + sum>>6  + sum>>8) >> 10
		else if(KSZ == 7)
		begin: div_ksz_7
			// 第一级流水线：移位
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					din_l_shift_4 <= 1'b0;
					din_l_shift_2 <= 1'b0;
					din_r_shift_1 <= 1'b0;
					din_r_shift_2 <= 1'b0;
					din_r_shift_3 <= 1'b0;
					din_r_shift_6 <= 1'b0;
					din_r_shift_8 <= 1'b0;
				end
				else if(din_hsync)
				begin
					din_l_shift_4 <= din<<4;
					din_l_shift_2 <= din<<2;
					din_r_shift_1 <= din>>1;
					din_r_shift_2 <= din>>2;
					din_r_shift_3 <= din>>3;
					din_r_shift_6 <= din>>6;
					din_r_shift_8 <= din>>8;
				end
			end
			// 第二级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					add_ls4_ls2 <= 1'b0;
					add_rs1_rs2 <= 1'b0;
					add_rs3_rs6 <= 1'b0;
					add_rs8_0 <= 1'b0;
				end
				else if(din_hsync_r_arr[0])
				begin
					add_ls4_ls2 <= din_l_shift_4 + din_l_shift_2;
					add_rs1_rs2 <= din_r_shift_1 + din_r_shift_2;
					add_rs3_rs6 <= din_r_shift_3 + din_r_shift_6;
					add_rs8_0 <= din_r_shift_8;
				end
			end
			// 第三级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
				begin
					add_temp1 <= 1'b0;
					add_temp2 <= 1'b0;
				end
				else if(din_hsync_r_arr[1])
				begin
					add_temp1 <= add_ls4_ls2 + add_rs1_rs2;
					add_temp2 <= add_rs3_rs6 + add_rs8_0;
				end
			end
			// 第四级流水线：加法
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					add_result <= 1'b0;
				else if(din_hsync_r_arr[2])
					add_result <= add_temp1 + add_temp2;
			end
			// 第五级流水线：右移10位
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					r_shift_result <= 1'b0;
				else if(din_hsync_r_arr[3])
					r_shift_result <= add_result>>10;
			end
			
			// 最终结果输出
			assign	dout_vsync	=	din_vsync_r_arr[4]					;
			assign	dout_hsync	=	din_hsync_r_arr[4]					;
			assign	dout		=	dout_hsync ? r_shift_result	: 1'b0	;
		end
		// ------
		
	end
	endgenerate
	
	
endmodule
