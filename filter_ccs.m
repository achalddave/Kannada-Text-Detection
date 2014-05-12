function [coarse_filt, gnt_filtered, gt, mt, g_comp_idxs, m_comp_idxs] = filter_ccs(ccs, stroke_widths, im_0, light_on_dark)
% Filters the connected components returned by SWT.
%
% Five criteria are considered:
%
% [1] The number of pixels in a connected component: If this number is less
% than SIZE_THRESH, then the connected component is reassigned to a value
% of (-1) and considered GUARANTEED NOT TEXT. This constitutes coarse
% filtering and the result of this operation alone is returned in
% coarse_filt.
%
% [2] The height and aspect ratio of a connected component: If the height
% is less than 10 pixels or larger than 300 pixels, or if the aspect ratio
% is larger than 10 or less than 0.1, then the connected component is
% reassigned to a value of (-2) and considered GUARANTEED NOT TEXT.
%
% [3] The variance of stroke widths: If this number is greater than
% GNT_VAR_THRESH, then the componenet is reassigned to a value of (-3)
% and considered GUARANTEED NOT TEXT.

%
% [4] <<<<<ACHAL EXPLAIN WHAT MORPH DOES>>>>>>>
%
% [5] Error between BW component and ...

    SIZE_THRESH = 10;

    GNT_VAR_THRESH = 20;
    GT_VAR_THRESH = 10;
    VAR_MORPH_SIZE = 2;

    GNT_MORPH_THRESH = 5;
    GT_MORPH_THRESH = 3;
    GT_MORPH_SIZE = 3;
    MORPH_SIZE = 1;

    GNT_ERR_THRESH = 1;
    GT_ERR_THRESH = 0.5;

    h = size(ccs, 1);
    w = size(ccs, 2);
    ccs_mod = ccs(:);
    gnt_filtered = ccs_mod;
    unique_ccs = unique(gnt_filtered);
    sprintf('Original num components: %d', size(unique_ccs, 1))

    % Remove components with less than 10 elements
    %
    % Note: We can do this because later on, we remove any component that is
    % less than 10 pixels in height, so this is a good conservative measure.
    tabulated = tabulate(gnt_filtered);
    indices = find(tabulated(:, 2) <= SIZE_THRESH);
    gnt_filtered(ismember(gnt_filtered, indices)) = -1;

    unique_ccs = unique(gnt_filtered);
    num_ccs = size(unique_ccs, 1);
    coarse_filt = reshape(gnt_filtered, h, w);
    sprintf('Num components after coarse filtering: %d', size(unique_ccs, 1))

    % Can index into row_vals, col_vals using a raw index to get the row,
    % column value.
    row_vals = repmat([1:h]', w, 1);
    col_vals = repmat([1:w], h, 1);

    mt = (gnt_filtered > 0);
    gt = (gnt_filtered > 0);

    m_comp_idxs = [];
    g_comp_idxs = [];

    % Walk through each component, and filter it using a number of tests.
    %   XXX: This code is currently a mess and needs to be cleaned up.
    %
    % The flow is so:
    %   Each test classifies a component as "maybe text", "guaranteed text",
    %   or "guaranteed not text."
    %
    %   If any test raises "guaranteed not text," we immediately stop and give
    %   up on this component.
    %
    %   If a test raises "guaranteed text" or "maybe text," we continue to run
    %   other tests. Iff all tests say we are "guaranteed text," this component
    %   is counted as text; otherwise, it is counted as "may be text."

    'Filtering components: This can take a couple minutes...'
    for i = 1:num_ccs
        % Surprisingly, doing multiple finds is faster than looping over the
        % elements once manually...
        scc_idx = unique_ccs(i);
        if (scc_idx == -1) ; continue ; end
        curr_cc_indices = find(gnt_filtered == scc_idx);

        rows = row_vals(curr_cc_indices);
        cols = col_vals(curr_cc_indices);

        curr_h = max(rows) - min(rows);
        curr_w = max(cols) - min(cols);

        window_cc = ccs(min(rows):max(rows),min(cols):max(cols));
        window_0 = im_0(min(rows):max(rows),min(cols):max(cols));

        % Check height/aspect ratio
        if (curr_h < 10 || curr_h > h/2) || ...
            ((curr_h / curr_w) < 0.1 || (curr_h / curr_w) > 10)
            % Definitely not text, moving along...
            gnt_filtered(curr_cc_indices) = -2;
            gt(curr_cc_indices) = 0;
            mt(curr_cc_indices) = 0;
            continue;
        end

        % -----------------------------------------------------------------
        % Get window of current cc and convert it to a black and white
        % image. Get the corresponding window of the original image and
        % convert it to a black and white image. Compute the error between
        % these two images. If the image was text, we expect both images
        % to be approximately binary, and thus, the error should be low.
        lv = graythresh(window_cc);
        window_cc = im2bw(window_cc,lv);

        lv = graythresh(window_0);
        window_0 = im2bw(window_0,lv);
        if(light_on_dark == 0)
            window_0 = 1-window_0;
        end

        err = sqrt(mean((window_cc - window_0).^2) / (curr_h*curr_w));

        if (err > GNT_ERR_THRESH)
            gnt_filtered(curr_cc_indices) = -5;
            gt(curr_cc_indices) = 0;
            mt(curr_cc_indices) = 0;
            continue;
        elseif (err < GT_ERR_THRESH)
            % Definitely text according to this test, but check other tests.
            mt(curr_cc_indices) = 0;
            gt(curr_cc_indices) = 1;
        else
            % May be text according to this test, but check other tests.
            mt(curr_cc_indices) = 1;
            gt(curr_cc_indices) = 0;
        end
        % -----------------------------------------------------------------


        % Erode the component and check how many pixels remain
        comp = zeros(h, w);
        comp(curr_cc_indices) = 1;
        comp_var = imerode(comp, strel('disk', VAR_MORPH_SIZE));
        comp_gt  = imerode(comp, strel('disk', GT_MORPH_SIZE));
        comp = imerode(comp, strel('disk', MORPH_SIZE));
        curr_stroke_widths = stroke_widths(comp_var == 1);

        if (var(curr_stroke_widths) > GNT_VAR_THRESH)
            gnt_filtered(curr_cc_indices) = -3;
            % Definitely not text, moving along...
            gt(curr_cc_indices) = 0;
            mt(curr_cc_indices) = 0;
            continue;
        elseif (var(curr_stroke_widths) < GT_VAR_THRESH)
            % Definitely text according to this test, but check other tests.
            if (gt(curr_cc_indices) == 1)
                gt(curr_cc_indices) = 1;
                mt(curr_cc_indices) = 0;
            end
        else
            % May be text according to this test, but check other tests.
            gt(curr_cc_indices) = 0;
            mt(curr_cc_indices) = 1;
        end

        sum_comp = sum(sum(comp));
        if (sum(sum(comp)) < GNT_MORPH_THRESH)
            % Definitely not text, moving along...
            gnt_filtered(curr_cc_indices) = -4;
            gt(curr_cc_indices) = 0;
            mt(curr_cc_indices) = 0;
            continue;
        elseif (sum(sum(comp_gt)) < GT_MORPH_THRESH)
            gt(curr_cc_indices) = 0;
            mt(curr_cc_indices) = 1;
        end

        if (gt(curr_cc_indices) == 1)
            g_comp_idxs = [g_comp_idxs scc_idx];
        elseif (mt(curr_cc_indices) == 1)
            m_comp_idxs = [m_comp_idxs scc_idx];
        end

    end
    gnt_filtered = reshape(gnt_filtered, h, w);
    gt = reshape(gt,h,w);
    mt = reshape(mt,h,w);
end
