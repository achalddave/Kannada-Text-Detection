function [ PROB ] = comp_vote(gnt_filtered, g_comp_idxs, m_comp_idxs)

SIGMA = 30;
[h,w] = size(gnt_filtered);
PROB = zeros(h,w);

% Can index into row_vals, col_vals using a raw index to get the row,
% column value.
row_vals = repmat([1:h]', w, 1);
col_vals = repmat([1:w], h, 1);

% Construct sum of Gaussians
for i = 1: length(g_comp_idxs)
    scc_idx = g_comp_idxs(i);
    curr_cc_indices = find(gnt_filtered == scc_idx);
    
    rows = row_vals(curr_cc_indices);
    cols = col_vals(curr_cc_indices);
    
    center_h = round((max(rows) + min(rows))/2);
    center_w = round((max(cols) + min(cols))/2);
    
    PROB = PROB + gauss2d(h, w, center_w, center_h, SIGMA);
end
    