%This function linear interpolates for NaN values
function output=interpnan(inVec,time)

output=inVec;
ibad=find(isnan(inVec));
igood=find(isfinite(inVec));
%extrapolation set to fill extrapolated values with 0
intValues= interp1(time(igood),inVec(igood),time(ibad),'linear',0);
output(ibad)=intValues;