function [prob, added, added_indices] = comp_vote(gnt_filtered, gt, g_comp_idxs, m_comp_idxs)

[h,w] = size(gnt_filtered);
prob = zeros(h,w);
added = zeros(h,w);
added_indices = [];

PROB_THRESH = 10 / (h*w);

% Can index into row_vals, col_vals using a raw index to get the row,
% column value.
row_vals = repmat([1:h]', w, 1);
col_vals = repmat([1:w], h, 1);

% Construct sum of Gaussians
cc_mask = double(gt > 0);
prob = imfilter(cc_mask, fspecial('gaussian', round(h / 3), 200));

prob = prob / max(max(prob));

for i = 1:length(m_comp_idxs)
    scc_idx = m_comp_idxs(i);
    curr_cc_indices = find(gnt_filtered == scc_idx);

    rows = row_vals(curr_cc_indices);
    cols = col_vals(curr_cc_indices);

    center_h = round((max(rows) + min(rows))/2);
    center_w = round((max(cols) + min(cols))/2);

    if (prob(center_h, center_w) > PROB_THRESH)
        added(curr_cc_indices) = prob(center_h, center_w);
        added_indices = [added_indices scc_idx];
    end
end
end
