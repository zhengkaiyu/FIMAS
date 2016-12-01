function id = sub2index( pid, lid, fid, ppl, ppf )
%SUB2INDEX sub to index kai's version
%   pid = pixel index
%   lid = line index
%   fid = frame index
%   ppl = pixel per line
%   ppf = pixel per frame
%   return id = linear index
id=((lid-1)*ppl+pid)+(fid-1)*ppf;
end

