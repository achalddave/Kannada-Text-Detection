function [comp_labels] = conn_comp(data, has_edge_fn)
    % Params:
    %   @data ((h, w) matrix)
    %   @has_edge_fn ((val1, val2) -> bool): Function that takes in two values
    %       from the @data matrix and returns whether or not there should be
    %       an edge between them. Can act as a threshold.
    %       SWT, for example, uses
    %           @(A, B) ((A ./ B <= 3) & (B ./ A <= 3))
    %
    % Returns:
    %   @comp_labels ((h, w) matrix): Contains the component label for each 

    [h, w] = size(data);
    % Note: This is a bit tricky for speed.
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
    % We can do a number of loops, but a much faster way is to shift the data
    % width matrix left, up, and left-up to do the calculations with no loops.
    %
    % Once we have these calculations, we can create 3 binary matrices: r_edge,
    % d_edge, rd_edge, where, e.g., r_edge(r, c) says whether there is an edge
    % from (r, c) to (r, c+1) [it's neighboring pixel to the right].

    shifted = cell([1 3]);
    shifted{1} = padarray(data(1:end, 2:end), [0 1], 0, 'post'); % shift left
    shifted{2} = padarray(data(2:end, 1:end), [1 0], 0, 'post'); % shift up
    shifted{3} = padarray(data(2:end, 2:end), [1 1], 0, 'post'); % shift up-left

    r_edge  = has_edge_fn(data, shifted{1});
    d_edge  = has_edge_fn(data, shifted{2});
    rd_edge = has_edge_fn(data, shifted{3});

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

    % component_vals = cell([1, num_ccs]);
    comp_labels = reshape(cc_labels, h, w);
end
