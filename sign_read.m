IM = im2double(rgb2gray(imread('sign3.jpg')));
[swt_im, ccomps] = swt(IM,1);
[coarse_filt, gnt_filtered, gt, mt, g_comp_idxs, m_comp_idxs] = ...
    filter_ccs(ccomps, swt_im, IM, 1);
PROB = comp_vote(gnt_filtered, g_comp_idxs, m_comp_idxs);