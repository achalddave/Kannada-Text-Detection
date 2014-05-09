function [filtered] = filter_ccs(ccs, stroke_widths, im_0)
    filtered = ccs;
    VAR_THRESH = 2;
    h = size(ccs, 1);
    w = size(ccs, 2);
    num_ccs = max(max(ccs));

    % --get gradient directions--------
    [~,Gdir] = imgradient(im_0);
    % ---------------------------------

    % Can index into row_vals, col_vals using a raw index to get the row,
    % column value.
    row_vals = repmat([1:h]', w, 1);
    col_vals = repmat([1:w], h, 1);

    for scc_idx = 1:num_ccs
        % Surprisingly, doing multiple finds is faster than looping over the
        % elements once manually...
        curr_cc_indices = find(ccs == scc_idx);

        rows = [];
        cols = [];

        % --initialize array of scc gradients------
        grads = [];
        % -----------------------------------------

        curr_stroke_widths = [];
        for i = 1:size(curr_cc_indices, 1)
            im_idx = curr_cc_indices(i);
            r = row_vals(im_idx);
            c = col_vals(im_idx);
            rows = [rows r];
            cols = [cols c];

            % --populate scc gradient array----
            grads = [grads Gdir(r,c)];
            % ---------------------------------

            curr_stroke_widths = stroke_widths(r, c);
        end

        h = max(rows) - min(rows);
        w = max(cols) - min(cols);

        % --Create histogram and get bincount----
        [nelements,~] = hist(grads);
        GRAD_VAR_THRESH = 4;
        % ---------------------------------------

        if (h < 1 || h > 300) || ...
            ((h / w) < 0.1 || (h / w) > 10) || ...
            (var(curr_stroke_widths) > VAR_THRESH || ...
            (var(nelements) > GRAD_VAR_THRESH))
            filtered(curr_cc_indices) = 0;
        end
    end
end
