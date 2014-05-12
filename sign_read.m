IM = im2double(rgb2gray(imread('sign10.JPG')));

LIGHT_ON_DARK = 0;
[swt_im, ccomps] = swt(IM,LIGHT_ON_DARK);
[coarse_filt, gnt_filtered, gt, mt, g_comp_idxs, m_comp_idxs] = ...
    filter_ccs(ccomps, swt_im, IM, 1);
[PROB, added, added_indices] = ...
    comp_vote(gnt_filtered, gt, g_comp_idxs, m_comp_idxs);
gt_final = gt;
gt_final(added > 0) = 1;


figure

subplot(2,2,1), imagesc(IM);
title('Original Image');

subplot(2,2,2), imagesc(swt_im);
title('SWT Result');

subplot(2,2,3), imagesc(coarse_filt);
title('Coarse Component Filtering Result');

subplot(2,2,4), imagesc(gt_final);
title('Final Result');