function [filtered] = filter_ccs(ccs, stroke_widths, im_0)
    VAR_THRESH = 2;
    GRAD_VAR_THRESH = 4;

    h = size(ccs, 1)
    w = size(ccs, 2)
    ccs = ccs(:);
    filtered = ccs;

    sprintf('Original num components %d', size(unique(filtered), 1))
    % Remove components with less than 5 elements
    tabulated = tabulate(filtered);
    indices = find(tabulated(:, 2) <= 1);
    filtered(ismember(filtered, indices)) = -1;
    sprintf('Num components now: %d', size(unique(filtered), 1))

    unique_ccs = unique(filtered);
    num_ccs = size(unique_ccs, 1);

    % --get gradient directions--------
    [~,Gdir] = imgradient(im_0);

    % Can index into row_vals, col_vals using a raw index to get the row,
    % column value.
    row_vals = repmat([1:h]', w, 1);
    col_vals = repmat([1:w], h, 1);

    'Filtering components: This can take a couple minutes...'
    for i = 1:num_ccs
        % Surprisingly, doing multiple finds is faster than looping over the
        % elements once manually...
        scc_idx = unique_ccs(i);
        if (scc_idx == -1) ; continue ; end
        curr_cc_indices = find(filtered == scc_idx);

        curr_cc_indices(1:min(50, end), 1)';
        rows = row_vals(curr_cc_indices);
        cols = col_vals(curr_cc_indices);

        % --initialize array of scc gradients------
        grads = Gdir(curr_cc_indices);

        curr_stroke_widths = stroke_widths(curr_cc_indices);

        curr_h = max(rows) - min(rows);
        curr_w = max(cols) - min(cols);

        % --Create histogram and get bincount----
        [nelements,~] = hist(grads);

        if (curr_h < 10 || curr_h > 300) || ...
            ((curr_h / curr_w) < 0.1 || (curr_h / curr_w) > 10) || ...
            (var(curr_stroke_widths) > VAR_THRESH) || ...
            (var(nelements) > GRAD_VAR_THRESH)
            filtered(curr_cc_indices) = -1;
        end
    end
    filtered = reshape(filtered, h, w);
end
