% 均值滤波

close;
clear;
clc;

% 读取原始灰度图片，到矩阵中
img = imread('./img_src/img_gray.jpeg'); 

% 3*3的核进行均值滤波后，存入矩阵中
ksz = fspecial('average', [3,3]); % 生成3*3的均值滤波的核
txt_mean_filter = imfilter(img, ksz); % 对原始灰度矩阵进行3*3核的均值滤波，结果存入矩阵中

% 矩阵转为图片
imwrite(txt_mean_filter, './img_dst_gray/img_gray_mean_filter.jpeg');