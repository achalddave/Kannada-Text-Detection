function [coarse_filt, components] = filter_ccs(ccs, stroke_widths, im_0, light_on_dark)
    COARSE_SIZE_THRESH = 10;
    COARSE_LARGE_SIZE_THRESH = size(im_0, 1) * size(im_0, 2) / 4;

    VAR_MORPH_SIZE = 2;
    GT_MORPH_SIZE = 3;
    MORPH_SIZE = 1;

    h = size(ccs, 1);
    w = size(ccs, 2);
    ccs_mod = ccs(:);
    unique_ccs = unique(ccs_mod);
    sprintf('Original num components: %d', size(unique_ccs, 1));

    % Remove components with less than 10 elements
    %
    % Note: We can do this because later on, we remove any component that is
    % less than 10 pixels in height, so this is a good conservative measure.
    tabulated = tabulate(ccs_mod);
    indices = find(tabulated(:, 2) <= COARSE_SIZE_THRESH);
    ccs_mod(ismember(ccs_mod, indices)) = -1;
    indices = find(tabulated(:, 2) >= COARSE_LARGE_SIZE_THRESH);
    ccs_mod(ismember(ccs_mod, indices)) = -1;

    unique_ccs = unique(ccs_mod);
    num_ccs = size(unique_ccs, 1);
    coarse_filt = reshape(ccs_mod, h, w);
    sprintf('Num components after coarse filtering: %d', size(unique_ccs, 1));

    % Can index into row_vals, col_vals using a raw index to get the row,
    % column value.
    row_vals = repmat([1:h]', w, 1);
    col_vals = repmat([1:w], h, 1);

    % Array of objects of @component
    components = repmat(component(), 1, num_ccs-1);

    'Getting features for components, this may take a few minutes...';
    idx = 1;
    for i = 1:num_ccs
        % Surprisingly, doing multiple finds is faster than looping over the
        % elements once manually...
        scc_idx = unique_ccs(i);
        if (scc_idx == -1) ; continue ; end
        curr_cc_indices = find(ccs_mod == scc_idx);

        rows = row_vals(curr_cc_indices);
        cols = col_vals(curr_cc_indices);

        curr_h = max(rows) - min(rows);
        curr_w = max(cols) - min(cols);

        top = min(rows);
        bottom = max(rows);
        right = max(cols);
        left = min(cols);

        window_cc = ccs(top:bottom, left:right);
        window_0 = im_0(top:bottom, left:right);


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

        err = sqrt(mean(mean((window_cc - window_0).^2)) / (curr_h*curr_w));
        % -----------------------------------------------------------------


        % Erode the component and check how many pixels remain
        comp = zeros(h, w);
        comp(curr_cc_indices) = 1;
        comp = imerode(comp, strel('disk', MORPH_SIZE));

        curr_stroke_widths = stroke_widths(curr_cc_indices);

        sum_comp = sum(sum(comp));

        comp_obj = component;

        comp_obj.scc_idx = scc_idx;
        comp_obj.rows = rows;
        comp_obj.cols = cols;

        comp_obj.left = left;
        comp_obj.right = right;
        comp_obj.top = top;
        comp_obj.bottom = bottom;

        % Features
        comp_obj.height = curr_h;
        comp_obj.width = curr_w;
        comp_obj.height_im = h;
        comp_obj.width_im  = w;
        comp_obj.prop_height = curr_h / h;
        comp_obj.prop_width = curr_w / w;
        comp_obj.gray_err = err;
        comp_obj.swt_mean = mean(curr_stroke_widths);
        comp_obj.swt_var = var(curr_stroke_widths);
        comp_obj.morphed_num_pxl = sum_comp;

        components(idx) = comp_obj;
        idx = idx + 1;
    end
end
