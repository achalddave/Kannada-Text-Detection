function [ OUT ] = data_read( IM, TXT )
% Returns a cell array of images of individual characters given an input
% image and bounding box data text file

%% Read text file and store each line as a cell entry
fid = fopen(TXT,'r');
i = 1;
tline = fgetl(fid);
OUT{i} = tline;
while ischar(tline)
    i = i+1;
    tline = fgetl(fid);
    if(tline ~= -1)
        OUT{i} = tline;
    end
end
fclose(fid);

%% Scan each line and extract numbers

for i = 1:length(OUT)
    text = OUT{i};
    colons = regexp(text,':');
    commas = regexp(text,',');

    row_coords = [];
    col_coords = [];

    text_indx = 1;
    char_indx = 1;
    while(~isempty(colons(colons>0)))
        col_coords = [col_coords, ...
            str2double(text(text_indx:colons(char_indx)-1))];
        text_indx = colons(char_indx)+1;
        row_coords = [row_coords, ...
            str2double(text(text_indx:commas(char_indx)-1))];
        text_indx = commas(char_indx)+1;
        colons(char_indx) = 0;
        char_indx = char_indx + 1;
    end

    OUT{i} = IM(min(row_coords):max(row_coords), ...
        min(col_coords):max(col_coords));
end
