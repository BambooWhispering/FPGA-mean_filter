% ��ֵ�˲�

close;
clear;
clc;

% ��ȡԭʼ�Ҷ�ͼƬ����������
img = imread('./img_src/img_gray.jpeg'); 

% 3*3�ĺ˽��о�ֵ�˲��󣬴��������
ksz = fspecial('average', [3,3]); % ����3*3�ľ�ֵ�˲��ĺ�
txt_mean_filter = imfilter(img, ksz); % ��ԭʼ�ҶȾ������3*3�˵ľ�ֵ�˲���������������

% ����תΪͼƬ
imwrite(txt_mean_filter, './img_dst_gray/img_gray_mean_filter.jpeg');