function [ pid, lid, fid ] = index2sub( id, ppf, ppl )
%INDEX2SUB convert index to sub (kai's version)
%   id = linear index
%   ppf = pixel per frame
%   ppl = pixel per line
%   return pid/lid/fid as pixel_index/line_index/frame_index
id=id-1;
pfid=mod(id,ppf);%pixel index in a frame
pid=mod(pfid,ppl)+1;
lid=floor(pfid/ppl)+1;
fid=floor(id/ppf)+1;
end