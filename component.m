classdef component
    properties
        rows
        cols

        left
        right
        bottom
        top

        scc_idx

        height_im
        width_im

        % These are used in feature vectors
        height
        width
        prop_height % proportional to image
        prop_width
        swt_mean
        swt_var
        gray_err
        morphed_num_pxl
    end
end
