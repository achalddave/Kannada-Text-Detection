function [swt_im, ccomps, E] = swt(IM, light_on_dark)
    % TODO:
    %   * Thresholding connected components
    %   * Try both light on dark, dark on light, and pick best

    % Assume light on dark text unless otherwise specified
    if nargin < 2 || isempty(light_on_dark)
        light_on_dark = 1;
    end

    % start workers if necessary
    % if matlabpool('size') == 0
    %     matlabpool open 8
    % end

    %% Configuration
    edge_fn = @(img) edge(img, 'canny');
    IM = imfilter(IM, fspecial('gaussian', 5));

    %% CANNY EDGE DETECTION
    E = edge_fn(IM);
    [h,w] = size(E);
    [R,C] = find(E); % Edge locations

    %% SWT
    [FX,FY] = gradient(IM);
    FX = imfilter(FX, fspecial('gaussian', 3));
    FY = imfilter(FY, fspecial('gaussian', 3));

    if ~light_on_dark
        FX = -FX;
        FY = -FY;
    end

    stroke_widths = Inf*ones(h,w);
    MSW = floor(sqrt(h^2+w^2));
    vectors_seen = cell(1,h*w);

    % TODO: can this be parallelized?
    'Extracting raw stroke widths'
    v = 1;
    jump = 0.05;
    for i=1:length(R)
        % Start at some edge pixel, get its coordinates
        % *_round = round values
        start_r = R(i) + 0.5;
        start_c = C(i) + 0.5;

        curr_r = start_r;
        curr_c = start_c;
        curr_r_round = R(i);
        curr_c_round = C(i);

        % Find the gradient vector components at this point
        grad_x = FX(curr_r_round, curr_c_round);
        grad_y = FY(curr_r_round, curr_c_round);

        % Normalize the gradient vector to length 1
        hyp2 = (grad_x)^2 + (grad_y)^2;
        if (hyp2 == 0) ; continue; end
        c = sqrt(1/hyp2);
        grad_x = c*grad_x;
        grad_y = c*grad_y;

        % Walk in direction of gradient vector
        PV_R = zeros(1,MSW);
        PV_C = zeros(1,MSW);

        point_idx = 0;
        while(1)
            % Get next unit step along gradient
            curr_r = curr_r + jump*grad_y;
            curr_c = curr_c + jump*grad_x;

            % Round next point to integers to access pixel
            next_r_round = round(curr_r);
            next_c_round = round(curr_c);

            if (next_r_round == curr_r_round && ...
                next_c_round == curr_c_round)
                continue
            end

            curr_r_round = next_r_round;
            curr_c_round = next_c_round;

            % Check if next point is valid
            if (curr_r_round <= 0 || curr_r_round > h) || ...
                (curr_c_round <= 0 || curr_c_round > w)
                break;
            end

            % If the point is valid, increment stroke width
            point_idx = point_idx + 1;

            % Add next point to points visited
            PV_R(1,point_idx) = curr_r_round;
            PV_C(1,point_idx) = curr_c_round;

            if (E(curr_r_round, curr_c_round) > 0)
                % Get gradient at new point
                new_grad_x = FX(curr_r_round, curr_c_round);
                new_grad_y = FY(curr_r_round, curr_c_round);

                % Normalize
                hyp2 = (new_grad_x)^2 + (new_grad_y)^2;
                c = sqrt(1/hyp2);
                new_grad_x = new_grad_x * c;
                new_grad_y = new_grad_y * c;

                % End if gradient at new point is in opposite direction
                if(acos(grad_x*-new_grad_x + grad_y*-new_grad_y) < (pi/2))
                    break;
                end
            end
        end

        % Delete trailing zeros from preallocated arrays
        i1 = find(PV_R, 1, 'first');
        i2 = find(PV_R, 1, 'last');
        PV_R = PV_R(i1:i2);
        PV_C = PV_C(i1:i2);

        % Add vector seen to list
        vectors_seen(v) = {{PV_R,PV_C}};
        v = v+1;

        % So now PV_R and PV_C contain all points visited along a gradient
        % We need to replace all these points with the stroke width.
        sw = sqrt((start_r - curr_r)^2 + (start_c - curr_c)^2);
        indices = PV_R + (PV_C - 1)*h;
        stroke_widths(indices) = min(sw, stroke_widths(indices));
    end

    % Remove trailing empty cells
    vectors_seen = vectors_seen(~cellfun('isempty', vectors_seen));

    % Replace outlier values with median along vector
    'Replacing outliers with medians'
    for j=1:length(vectors_seen)
        % Access vectors visited from cell array
        rows = vectors_seen{j}{1};
        cols = vectors_seen{j}{2};

        % Create array of stroke widths at vector points
        widths = stroke_widths(rows + (cols - 1) * h);

        % Find median along vector
        med = median(widths);

        % Replace entries larger than median with median
        stroke_widths(rows + (cols - 1)*h) = min(widths, med);
    end

    % Connected components analysis
    'Creating connected graph'

    % Note: This next part is a bit tricky for speed.
    % /----------\
    % |   |   |   |
    % -------------
    % |   | x | r |
    % -------------
    % |   | d |rd |
    % \----------/
    %
    % For each pixel x, we want to decide whether it has an edge to its neighbors
    % r, d, and rd in our graph.
    %
    % We can do a number of loops, but a much faster way is to shift the stroke
    % width matrix left, up, and left-up to do the calculations with no loops.
    %
    % Once we have these calculations, we can create 3 binary matrices: r_edge,
    % d_edge, rd_edge, where, e.g., r_edge(r, c) says whether there is an edge
    % from (r, c) to (r, c+1) [it's neighboring pixel to the right].

    shifted_widths = cell([1 3]);
    shifted_widths{1} = padarray(stroke_widths(1:end, 2:end), [0 1], 0, 'post'); % shift left
    shifted_widths{2} = padarray(stroke_widths(2:end, 1:end), [1 0], 0, 'post'); % shift up
    shifted_widths{3} = padarray(stroke_widths(2:end, 2:end), [1 1], 0, 'post'); % shift up-left

    is_connected = @(A,B) ((A ./ B <= 3) & (B ./ A <= 3));
    r_edge  = is_connected(stroke_widths, shifted_widths{1});
    d_edge  = is_connected(stroke_widths, shifted_widths{2});
    rd_edge = is_connected(stroke_widths, shifted_widths{3});

    % We have the binary matrices; we need to create a sparse matrix of
    % dimension (h*w, h*w) of edges. We can construct it by storing just the
    % edges in conn_src and conn_dst (s.t. conn_src(i) links to conn_dst(i)).
    % Note that these must store raw indices in the range [1, h*w], so we have
    % to do some math. Specifically, (r, c) = r + h * (c - 1).
    conn_src = [];
    conn_dst = [];
    [r_r, r_c] = find(r_edge);
    conn_src = [conn_src (r_r + h*(r_c-1))'  (r_r + h*(r_c))'   ];
    conn_dst = [conn_dst (r_r + h*(r_c))'    (r_r + h*(r_c-1))' ];

    [r_r, r_c] = find(d_edge);
    conn_src = [conn_src (r_r + h*(r_c-1))'    (r_r+1 + h*(r_c-1))' ];
    conn_dst = [conn_dst (r_r+1 + h*(r_c-1))'  (r_r   + h*(r_c-1))' ];

    [r_r, r_c] = find(rd_edge);
    conn_src = [conn_src (r_r + h*(r_c-1))' (r_r+1 + h*(r_c))'  ];
    conn_dst = [conn_dst (r_r+1 + h*(r_c))' (r_r   + h*(r_c-1))'];

    vals = ones(1, size(conn_src, 2));

    'Calculating connected components'
    graph_mat = sparse(conn_src, conn_dst, vals, h*w, h*w);
    [num_ccs, cc_labels] = graphconncomp(graph_mat);

    component_vals = cell([1, num_ccs]);

    ccomps = reshape(cc_labels, h, w);
    swt_im = stroke_widths;
end
