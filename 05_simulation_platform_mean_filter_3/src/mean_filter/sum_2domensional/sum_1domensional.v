/*
一维求和：
求一个正方形核的一行数据的和
*/
module sum_1donmensional(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 一维求和前的信号
	din_vsync			,	// 输入数据场同步信号
	din_hsync			,	// 输入数据行同步信号
	din					,	// 输入数据（与 输入数据行同步信号 同步）
	
	// 一维求和后的信号
	dout_right_vsync	,	// （核右对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	dout_right_hsync	,	// （核右对齐首数据）输出数据行同步信号
	dout_right			, 	// （核右对齐首数据）输出数据（与 输出数据行同步信号 同步）
	dout_left_vsync		,	// （核左对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	dout_left_hsync		,	// （核左对齐首数据）输出数据行同步信号
	dout_left				// （核左对齐首数据）输出数据（与 输出数据行同步信号 同步）
	);
	
	
	// *******************************************参数声明***************************************
	parameter	KSZ		=	'd3	;	// 核尺寸（正方形核的边长）（kernel size）
	parameter	DW		=	'd8	;	// 数据位宽
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input						clk					;	// 时钟（clock）
	input						rst_n				;	// 复位（reset）
	
	// 一维求和前的信号
	input						din_vsync			;	// 输入数据场同步信号
	input						din_hsync			;	// 输入数据行同步信号
	input		[DW-1:0]		din					;	// 输入数据（与 输入数据行同步信号 同步）
	
	// 一维求和后的信号
	output						dout_right_vsync	;	// （核右对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	output						dout_right_hsync	;	// （核右对齐首数据）输出数据行同步信号
	output		[2*DW-1:0]		dout_right			; 	// （核右对齐首数据）输出数据（与 输出数据行同步信号 同步）
	output						dout_left_vsync		;	// （核左对齐首数据）输出数据场同步信号（左右对齐，即场后肩、场前肩不变）
	output						dout_left_hsync		;	// （核左对齐首数据）输出数据行同步信号
	output		[2*DW-1:0]		dout_left			; 	// （核左对齐首数据）输出数据（与 输出数据行同步信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 输入数据场同步信号、行同步信号、输入数据 打KSZ+1拍
	reg			[KSZ:0]			din_vsync_r_arr		;	// 输入数据行同步信号 打拍
	reg			[KSZ:0]			din_hsync_r_arr		;	// 输入数据行同步信号 打拍
	reg			[DW-1:0]		din_r_arr[0:KSZ]	;	// 输入数据 打拍
	
	// for循环计数
	integer						i					;	// for循环计数
	
	// 相邻两次一维求和的差值
	wire		[2*DW-1:0]		sub_b				;	// 减数
	// 使用的均为无符号数，可能就会有疑问，差 不是可能会有负值吗。
	// 但是，别忘了数据会溢出。
	// 比如：16位的无符号1 - 16位的无符号4 = （若是有符号应该是等于-3，但是无符号的话会溢出，所以结果是）2^16-3 = 65536-3 = 65533
	// 那么，若 上一次的和 = 5，
	// 则 当前次的和 = 5+65533（若是有符号应该是5-3） = （若是有符号应该是等于2，但是无符号的话会溢出，所以结果是）(5+65533)-2^16- = 2
	// 也就是说，用无符号数，虽然差可能会出现负数溢出，但是因为我们确定和是正数，所以由负数溢出的差所得到的和将反而是正确的。
	wire		[2*DW-1:0]		sub_result			;	// 差
	
	// 一维求和
	reg			[2*DW-1:0]		sum					;	// 和
	// *******************************************************************************************
	
	
	// 缓存 KSZ+1 个 输入数据场同步信号、行同步信号、输入数据
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			din_vsync_r_arr <= 1'b0;
			din_hsync_r_arr <= 1'b0;
			for(i=0; i<=KSZ; i=i+1)
				din_r_arr[i] <= 1'b0;
		end
		else
		begin
			din_vsync_r_arr <= {din_vsync_r_arr[KSZ-1:0], din_vsync};
			din_hsync_r_arr <= {din_hsync_r_arr[KSZ-1:0], din_hsync};
			din_r_arr[0] <= din;
			for(i=1; i<=KSZ; i=i+1)
				din_r_arr[i] <= din_r_arr[i-1];
		end
	end
	
	
	// 做减法求相邻两次一维求和的差值
	// 把 din_hsync_r_arr[0] 作为当前次，则 din_hsync_r_arr[KSZ] 为当前次打KSZ拍。
	// 当两者同时有效时，此时的 din_r_arr[0] 是当前次的一维求和的核中的最后一个待加数，
	// din_r_arr[KSZ] 是上一次的一维求和的核中的首个待加数。
	// 那么两次一维求和的差值就是 当前次的一维求和的核中的最后一个待加数 - 上一次的一维求和的核中的首个待加数
	// 例如：上一次一维求和是           1+2+3；
	//       当前次一维求和是           2+3+4；
	//       则相邻两次一维求和的差值是 4-1。
	assign	sub_b		=	(din_hsync_r_arr[0]&din_hsync_r_arr[KSZ]) ? din_r_arr[KSZ] : 1'b0; // 减数
	// 没有使用 (din_hsync_r_arr[0]&din_hsync_r_arr[KSZ]) ? (din_r_arr[0] - sub_b) : 1'b0 是因为还需要把 未满一行的数据也算进去
	assign	sub_result	=	din_r_arr[0] - sub_b; // 差 = 被减数-减数
	
	
	// 当前次的求和结果
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			sum <= 1'b0;
		else if(din_hsync & ~din_hsync_r_arr[0]) // 和清0（一次一维求和开始前（一次一维求和的上升沿））
			sum <= 1'b0;
		else if(din_hsync_r_arr[0]) // 当前次的和 = 上一次的和+两次求和之差
			sum <= sum + sub_result;
	end
	
	
	// （核右对齐首数据）输出数据行同步信号、输出数据
	// 因为要按序等待累加，所以 一行图像数据流的 第0、1、...、KSZ-2个 输出时，并未满核的一行，只是核的一行中前几个数据的和；
	// 也可以看作，核的最右边对齐数据流的首个数据，然后开始往右移，直到核的最右边对齐数据流的最后一个数据，
	// 其中，最开始的核，不足的数据流默认为0。
	assign	dout_right_vsync	=	din_vsync_r_arr[1]				;
	assign	dout_right_hsync	=	din_hsync_r_arr[1]				;
	assign	dout_right			=	din_hsync_r_arr[1] ? sum : 1'b0	;
	// 图示如下（核尺寸KSZ = 3）：
	// din_hsync	:		_|- - - -|_
	// din			:	  0 0 1 2 3 4
	// 核（*表示）	:	  * * *
	//					    * * *
	//					      * * *
	//					        * * *
	// dout_right_hsync	:	_ _|- - - -|_
	// dout_right		:	0 0 1 3 6 9
	
	
	// （核左对齐首数据）输出数据行同步信号、输出数据
	// 可以看作，核的最左边对齐数据流的首个数据，然后开始往右移，直到核的最右边对齐数据流的最后一个数据
	assign	dout_left_vsync	=	din_vsync_r_arr[1] & din_vsync_r_arr[KSZ]				;
	assign	dout_left_hsync	=	din_hsync_r_arr[1] & din_hsync_r_arr[KSZ]				;	
	assign	dout_left		=	(din_hsync_r_arr[1]&din_hsync_r_arr[KSZ]) ? sum :1'b0	;
	// 图示如下（核尺寸KSZ = 3）：
	// din_hsync	:		_|- - - -|_
	// din			:	      1 2 3 4
	// 核（*表示）	:		  * * *
	//					        * * *
	// dout_left_hsync	:	    _ _|- -|_
	// dout_left		:		    6 9
	
	
endmodule
